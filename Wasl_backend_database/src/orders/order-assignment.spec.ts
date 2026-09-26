import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OrderAssignmentService } from './order-assignment.service';
import { Order, OrderStatus } from './entities/order.entity';
import {
  OrderAssignment,
  AssignmentStatus,
} from './entities/order-assignment.entity';
import {
  DeliveryPartner,
  DeliveryVerificationStatus,
} from '../delivery/entities/delivery-partner.entity';
import { AccountStatus, User } from '../users/entities/user.entity';
import { DeliveryService } from '../delivery/delivery.service';
import { SettingsService } from '../settings/settings.service';
import {
  NotificationsService,
  NotificationKind,
} from '../notifications/notifications.service';

/**
 * Who gets offered an order, for how long, and what happens when nobody says
 * yes.
 *
 * The behaviour these pin down is the whole reason CP6-B exists. Before it,
 * every pending order was visible to every eligible driver at once: nearest
 * drivers had no advantage, nothing recorded who had been asked, and an order
 * nobody wanted sat in `pending_offers` for ever because there was no offer to
 * time out.
 *
 * The numbers here are the approved ones — three drivers per wave, sixty
 * seconds to answer, widening by the search radius up to a 10 km ceiling — and
 * they are asserted rather than assumed, because a silent change to any of them
 * changes what a driver's day feels like.
 */
describe('OrderAssignmentService', () => {
  const ORDER_ID = 7;
  const START_RADIUS = 5;

  /** Every driver the location search would return, nearest first. */
  let nearby: { driverId: number; distanceKm: number }[];
  /** Rows in `order_assignments`, keyed loosely as the fake repo needs. */
  let assignments: Partial<OrderAssignment>[];
  /** Per-driver overrides for the partner row. */
  let partnerOverrides: Map<number, Partial<DeliveryPartner>>;
  /** Drivers who currently hold an active order. */
  let busyDrivers: Set<number>;
  let order: Partial<Order>;
  let orderUpdates: Partial<Order>[];
  let service: OrderAssignmentService;
  let nextId: number;
  /** Every notification the engine asked for, in order. */
  let notified: {
    to: number[];
    title: string;
    body: string;
    kind?: NotificationKind;
    orderId?: number;
  }[];

  const partnerFor = (driverId: number): Partial<DeliveryPartner> => ({
    userId: driverId,
    verificationStatus: DeliveryVerificationStatus.APPROVED,
    isOnline: true,
    balance: 100,
    availabilityRadiusKm: 50,
    ...(partnerOverrides.get(driverId) ?? {}),
  });

  const matches = (
    row: Record<string, unknown> | Partial<OrderAssignment> | Partial<Order>,
    where: Record<string, unknown>,
  ): boolean =>
    Object.entries(where).every(([key, value]) => {
      const actual = (row as Record<string, unknown>)[key];
      // Enough of TypeORM's `In(...)` / `LessThanOrEqual(...)` to drive these
      // tests; the real operators are exercised against Postgres separately.
      if (value && typeof value === 'object' && '_type' in value) {
        const op = value as { _type: string; _value: unknown };
        if (op._type === 'in') return (op._value as unknown[]).includes(actual);
        if (op._type === 'lessThanOrEqual') {
          return new Date(actual as Date) <= new Date(op._value as Date);
        }
      }
      return actual === value;
    });

  beforeEach(async () => {
    nearby = [];
    assignments = [];
    partnerOverrides = new Map();
    busyDrivers = new Set();
    orderUpdates = [];
    notified = [];
    nextId = 1;
    order = {
      id: ORDER_ID,
      status: OrderStatus.PENDING_OFFERS,
      latitude: 30.7,
      longitude: 30.7,
    };

    const assignmentRepo = {
      find: ({ where }: { where: Record<string, unknown> }) =>
        Promise.resolve(assignments.filter((a) => matches(a, where))),
      findOne: ({ where }: { where: Record<string, unknown> }) =>
        Promise.resolve(assignments.find((a) => matches(a, where)) ?? null),
      count: ({ where }: { where: Record<string, unknown> }) =>
        Promise.resolve(assignments.filter((a) => matches(a, where)).length),
      insert: (row: Partial<OrderAssignment>) => {
        // The unique (order_id, driver_id) index, in miniature.
        if (
          assignments.some(
            (a) => a.orderId === row.orderId && a.driverId === row.driverId,
          )
        ) {
          return Promise.reject(
            Object.assign(new Error('duplicate key'), { code: '23505' }),
          );
        }
        assignments.push({ id: nextId++, ...row });
        return Promise.resolve({ identifiers: [] });
      },
      update: (
        where: Record<string, unknown>,
        patch: Partial<OrderAssignment>,
      ) => {
        const hits = assignments.filter((a) => matches(a, where));
        hits.forEach((a) => Object.assign(a, patch));
        return Promise.resolve({ affected: hits.length });
      },
    };

    const orderRepo = {
      findOne: () => Promise.resolve(order),
      // The sweep now also looks for orders that are waiting with nobody
      // being asked, so the fake has to answer a `find` as well.
      find: ({ where }: { where: Record<string, unknown> }) =>
        Promise.resolve(matches(order, where) ? [order] : []),
      update: (where: Record<string, unknown>, patch: Partial<Order>) => {
        if (!matches(order, where)) return Promise.resolve({ affected: 0 });
        Object.assign(order, patch);
        orderUpdates.push(patch);
        return Promise.resolve({ affected: 1 });
      },
      count: ({ where }: { where: { acceptedDriverId: number } }) =>
        Promise.resolve(busyDrivers.has(where.acceptedDriverId) ? 1 : 0),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderAssignmentService,
        {
          provide: getRepositoryToken(OrderAssignment),
          useValue: assignmentRepo,
        },
        { provide: getRepositoryToken(Order), useValue: orderRepo },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: {
            find: ({ where }: { where: { userId: { _value: number[] } } }) =>
              Promise.resolve(where.userId._value.map(partnerFor)),
          },
        },
        {
          provide: getRepositoryToken(User),
          useValue: {
            find: ({ where }: { where: { id: { _value: number[] } } }) =>
              Promise.resolve(
                where.id._value.map((id) => ({
                  id,
                  status: AccountStatus.ACTIVE,
                })),
              ),
          },
        },
        {
          provide: DeliveryService,
          useValue: {
            findNearbyOnlineDrivers: (
              _lat: number,
              _lng: number,
              radiusKm: number,
            ) =>
              Promise.resolve(nearby.filter((d) => d.distanceKm <= radiusKm)),
          },
        },
        {
          provide: SettingsService,
          useValue: {
            getNumber: (key: string, fallback: number) =>
              key === 'driver_search_radius_km' ? START_RADIUS : fallback,
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            notify: (
              to: number,
              title: string,
              body: string,
              o: { kind?: NotificationKind; orderId?: number } = {},
            ) => {
              notified.push({ to: [to], title, body, ...o });
              return Promise.resolve(undefined);
            },
            notifyMany: (
              to: number[],
              title: string,
              body: string,
              o: { kind?: NotificationKind; orderId?: number } = {},
            ) => {
              notified.push({ to, title, body, ...o });
              return Promise.resolve(undefined);
            },
          },
        },
      ],
    }).compile();

    service = module.get(OrderAssignmentService);
  });

  const live = () =>
    assignments.filter((a) => a.status === AssignmentStatus.OFFERED);

  describe('a wave', () => {
    it('offers to at most three drivers, nearest first', async () => {
      nearby = [
        { driverId: 1, distanceKm: 0.5 },
        { driverId: 2, distanceKm: 1 },
        { driverId: 3, distanceKm: 2 },
        { driverId: 4, distanceKm: 3 },
        { driverId: 5, distanceKm: 4 },
      ];

      const wave = await service.openNextWave(ORDER_ID);

      expect(wave.offered).toEqual([1, 2, 3]);
      expect(wave.waveNumber).toBe(1);
      expect(wave.radiusKm).toBe(START_RADIUS);
    });

    it('gives each offer sixty seconds', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];

      const before = Date.now();
      await service.openNextWave(ORDER_ID);

      const window =
        new Date(live()[0].expiresAt!).getTime() -
        new Date(live()[0].offeredAt!).getTime();
      expect(window).toBe(60_000);
      expect(new Date(live()[0].expiresAt!).getTime()).toBeGreaterThan(before);
    });

    it('records the wave, radius and distance for the audit trail', async () => {
      nearby = [{ driverId: 1, distanceKm: 1.25 }];

      await service.openNextWave(ORDER_ID);

      expect(assignments[0]).toMatchObject({
        orderId: ORDER_ID,
        driverId: 1,
        waveNumber: 1,
        radiusKm: START_RADIUS,
        distanceKm: 1.25,
        status: AssignmentStatus.OFFERED,
      });
    });

    it('does nothing for an order that is no longer waiting', async () => {
      order.status = OrderStatus.ACCEPTED;
      nearby = [{ driverId: 1, distanceKm: 1 }];

      const wave = await service.openNextWave(ORDER_ID);

      expect(wave.offered).toEqual([]);
      expect(assignments).toHaveLength(0);
    });
  });

  describe('who is excluded', () => {
    it('skips a driver who already holds an active order', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 2 },
      ];
      busyDrivers.add(1);

      const wave = await service.openNextWave(ORDER_ID);

      expect(wave.offered).toEqual([2]);
    });

    it('skips a driver whose documents are not approved', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 2 },
      ];
      partnerOverrides.set(1, {
        verificationStatus: DeliveryVerificationStatus.PENDING,
      });

      const wave = await service.openNextWave(ORDER_ID);

      expect(wave.offered).toEqual([2]);
    });

    it('skips a driver under the wallet minimum', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 2 },
      ];
      partnerOverrides.set(1, { balance: 1 });

      const wave = await service.openNextWave(ORDER_ID);

      expect(wave.offered).toEqual([2]);
    });

    it('respects a driver’s own service radius even when the wave is wider', async () => {
      // Driver 1 only works a 2 km patch; the order is 4 km away.
      nearby = [
        { driverId: 1, distanceKm: 4 },
        { driverId: 2, distanceKm: 4.5 },
      ];
      partnerOverrides.set(1, { availabilityRadiusKm: 2 });

      const wave = await service.openNextWave(ORDER_ID);

      expect(wave.offered).toEqual([2]);
    });

    it('never offers the same order to the same driver twice', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];

      await service.openNextWave(ORDER_ID);
      // Wave 1's offer lapsed, but driver 1 has had their turn.
      assignments[0].status = AssignmentStatus.EXPIRED;
      const second = await service.openNextWave(ORDER_ID);

      expect(second.offered).toEqual([]);
      expect(assignments).toHaveLength(1);
    });
  });

  describe('widening', () => {
    it('reaches further on each wave', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 8 },
      ];

      const first = await service.openNextWave(ORDER_ID);
      expect(first.radiusKm).toBe(5);
      expect(first.offered).toEqual([1]);

      assignments[0].status = AssignmentStatus.EXPIRED;
      const second = await service.openNextWave(ORDER_ID);

      // 10 km now, so the driver 8 km out comes into range.
      expect(second.radiusKm).toBe(10);
      expect(second.offered).toEqual([2]);
      expect(second.waveNumber).toBe(2);
    });

    it('stops widening at ten kilometres', async () => {
      nearby = [{ driverId: 99, distanceKm: 40 }];

      const first = await service.openNextWave(ORDER_ID);
      const second = await service.openNextWave(ORDER_ID);
      const third = await service.openNextWave(ORDER_ID);

      expect(first.radiusKm).toBe(5);
      expect(second.radiusKm).toBe(10);
      expect(third.radiusKm).toBe(10);
      expect(third.exhausted).toBe(true);
      // Nobody within the ceiling, so nobody was ever offered it.
      expect(assignments).toHaveLength(0);
    });
  });

  describe('the sweep', () => {
    const lapse = () => {
      assignments.forEach((a) => {
        a.expiresAt = new Date(Date.now() - 1000);
      });
    };

    it('expires offers past their deadline', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);
      lapse();

      const result = await service.runSweep();

      expect(result.expiredOffers).toBe(1);
      expect(assignments[0].status).toBe(AssignmentStatus.EXPIRED);
    });

    it('opens the next, wider wave when one lapses', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 8 },
      ];
      await service.openNextWave(ORDER_ID);
      lapse();

      const result = await service.runSweep();

      expect(result.rewaved).toEqual([ORDER_ID]);
      expect(live().map((a) => a.driverId)).toEqual([2]);
    });

    it('expires the order once the radius is exhausted and nobody is left', async () => {
      // Wave 1 goes to the only driver in range. When it lapses the sweep
      // widens to the 10 km ceiling, finds nobody it has not already asked,
      // and gives up in the same pass rather than spinning at the ceiling.
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);
      lapse();

      const result = await service.runSweep();

      expect(result.expiredOrders).toEqual([ORDER_ID]);
      expect(result.rewaved).toEqual([]);
      expect(order.status).toBe(OrderStatus.EXPIRED);
    });

    it('leaves an order alone if somebody accepted in the meantime', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 2 },
      ];
      await service.openNextWave(ORDER_ID);

      // Driver 1's offer lapses, but driver 2 is still deciding.
      assignments[0].expiresAt = new Date(Date.now() - 1000);
      const result = await service.runSweep();

      expect(result.rewaved).toEqual([]);
      expect(result.expiredOrders).toEqual([]);
      expect(order.status).toBe(OrderStatus.PENDING_OFFERS);
    });

    it('does nothing when no offer has lapsed', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);

      const result = await service.runSweep();

      expect(result).toEqual({
        expiredOffers: 0,
        rewaved: [],
        expiredOrders: [],
      });
    });
  });

  /**
   * An order whose first wave reached nobody.
   *
   * This is a field bug, not a hypothetical: a customer placed an order while
   * the only nearby captain's GPS fix had gone stale, so wave 1 found zero
   * candidates and wrote zero assignment rows. The sweep looked only at
   * *lapsed offers*, and an order with no offers has nothing that can lapse —
   * so it was never widened, never expired, and never shown to the captain
   * even after he came back. It simply sat in `pending_offers` for ever.
   */
  describe('an order nobody was asked about', () => {
    /** Wave 1 ran, found nobody, and wrote no rows. */
    const waveThatReachedNobody = async (createdMinutesAgo: number) => {
      nearby = [];
      await service.openNextWave(ORDER_ID);
      expect(assignments).toHaveLength(0);
      order.createdAt = new Date(Date.now() - createdMinutesAgo * 60_000);
    };

    it('is picked up by the sweep once its wave is due', async () => {
      await waveThatReachedNobody(5);
      // A captain is reachable again by the time the sweep runs.
      nearby = [{ driverId: 1, distanceKm: 1 }];

      const result = await service.runSweep();

      expect(result.rewaved).toEqual([ORDER_ID]);
      expect(assignments.map((a) => a.driverId)).toEqual([1]);
      expect(order.status).toBe(OrderStatus.PENDING_OFFERS);
    });

    it('…and the captain is told, exactly as on any other wave', async () => {
      await waveThatReachedNobody(5);
      nearby = [{ driverId: 1, distanceKm: 1 }];

      await service.runSweep();

      expect(notified).toContainEqual(
        expect.objectContaining({
          to: [1],
          kind: NotificationKind.ORDER_OFFER,
          orderId: ORDER_ID,
        }),
      );
    });

    it('is left alone until its wave is actually due', async () => {
      // Created seconds ago: wave 1 is still inside its own minute, and
      // widening now would burn through every radius in a few sweeps.
      await waveThatReachedNobody(0);
      nearby = [{ driverId: 1, distanceKm: 1 }];

      const result = await service.runSweep();

      expect(result.rewaved).toEqual([]);
      expect(assignments).toHaveLength(0);
    });

    it('widens, and expires the order once the radius is exhausted', async () => {
      // Old enough that every wave is due, and still nobody anywhere.
      await waveThatReachedNobody(60);
      nearby = [];

      let expired: number[] = [];
      for (let sweep = 0; sweep < 6 && expired.length === 0; sweep++) {
        expired = (await service.runSweep()).expiredOrders;
      }

      expect(expired).toEqual([ORDER_ID]);
      expect(order.status).toBe(OrderStatus.EXPIRED);
    });

    it('is not touched while a live offer is still outstanding', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);
      order.createdAt = new Date(Date.now() - 60 * 60_000);

      const result = await service.runSweep();

      // Somebody is being asked; widening now would double-offer the order.
      expect(result.rewaved).toEqual([]);
      expect(assignments).toHaveLength(1);
    });

    it('leaves an order that is no longer waiting alone', async () => {
      await waveThatReachedNobody(60);
      order.status = OrderStatus.ACCEPTED;
      nearby = [{ driverId: 1, distanceKm: 1 }];

      const result = await service.runSweep();

      expect(result.rewaved).toEqual([]);
      expect(assignments).toHaveLength(0);
    });
  });

  describe('declining', () => {
    it('takes the driver out of the running without penalty', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);

      await expect(service.decline(ORDER_ID, 1)).resolves.toMatchObject({
        success: true,
      });

      expect(assignments[0].status).toBe(AssignmentStatus.DECLINED);
      expect(assignments[0].respondedAt).toBeInstanceOf(Date);
      // The order itself is untouched — declining is not cancelling. (The wave
      // counter moved when the offer went out, which is not a state change.)
      expect(order.status).toBe(OrderStatus.PENDING_OFFERS);
      expect(orderUpdates.some((patch) => 'status' in patch)).toBe(false);
    });

    it('refuses a decline with no live offer behind it', async () => {
      await expect(service.decline(ORDER_ID, 1)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('is not repeatable', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);
      await service.decline(ORDER_ID, 1);

      await expect(service.decline(ORDER_ID, 1)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('does not re-offer the order to a driver who declined it', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 8 },
      ];
      await service.openNextWave(ORDER_ID);
      await service.decline(ORDER_ID, 1);

      const second = await service.openNextWave(ORDER_ID);

      expect(second.offered).toEqual([2]);
    });
  });

  describe('capacity', () => {
    it('reports a driver with an active order as not free', async () => {
      busyDrivers.add(1);
      await expect(service.isDriverFree(1)).resolves.toBe(false);
    });

    it('reports an idle driver as free', async () => {
      await expect(service.isDriverFree(1)).resolves.toBe(true);
    });
  });

  /**
   * CP6-C. A sixty-second window is only real if the driver is told about it —
   * without a push they would have to be staring at the app to ever win one.
   */
  describe('notifications', () => {
    const kinds = () => notified.map((n) => n.kind);

    it('tells exactly the drivers who were offered the order', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 2 },
        { driverId: 3, distanceKm: 3 },
        { driverId: 4, distanceKm: 4 },
      ];

      await service.openNextWave(ORDER_ID);

      expect(notified).toHaveLength(1);
      expect(notified[0].to).toEqual([1, 2, 3]);
      expect(notified[0].kind).toBe(NotificationKind.ORDER_OFFER);
      expect(notified[0].orderId).toBe(ORDER_ID);
    });

    it('notifies on later waves too, not just the first', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 8 },
      ];
      await service.openNextWave(ORDER_ID);
      notified = [];

      assignments[0].status = AssignmentStatus.EXPIRED;
      await service.openNextWave(ORDER_ID);

      expect(notified).toHaveLength(1);
      expect(notified[0].to).toEqual([2]);
    });

    it('says nothing when a wave reaches nobody', async () => {
      nearby = [];

      await service.openNextWave(ORDER_ID);

      expect(notified).toHaveLength(0);
    });

    it('tells a driver when their offer ran out', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);
      notified = [];
      assignments.forEach((a) => {
        a.expiresAt = new Date(Date.now() - 1000);
      });

      await service.runSweep();

      const expiredNote = notified.find(
        (n) => n.kind === NotificationKind.OFFER_EXPIRED,
      );
      expect(expiredNote).toBeDefined();
      expect(expiredNote!.to).toEqual([1]);
    });

    it('tells the customer when the order expires with no captain found', async () => {
      order.customerId = 555;
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);
      assignments.forEach((a) => {
        a.expiresAt = new Date(Date.now() - 1000);
      });
      notified = [];

      await service.runSweep();

      const customerNote = notified.find(
        (n) => n.kind === NotificationKind.ORDER_EXPIRED,
      );
      expect(customerNote).toBeDefined();
      expect(customerNote!.to).toEqual([555]);
      expect(customerNote!.orderId).toBe(ORDER_ID);
    });

    it('does not tell the customer anything while the search is still going', async () => {
      nearby = [
        { driverId: 1, distanceKm: 1 },
        { driverId: 2, distanceKm: 8 },
      ];
      await service.openNextWave(ORDER_ID);
      assignments[0].expiresAt = new Date(Date.now() - 1000);
      notified = [];

      await service.runSweep();

      expect(kinds()).not.toContain(NotificationKind.ORDER_EXPIRED);
    });

    it('carries no personal detail into the payload', async () => {
      // These strings end up in a push payload on Google's servers and in the
      // notification shade of a phone anyone can pick up. The fee is fine; an
      // address or a phone number is not.
      order.deliveryAddressText = '12 شارع سري جدا';
      order.customerPhone = '01000000000';
      nearby = [{ driverId: 1, distanceKm: 1 }];

      await service.openNextWave(ORDER_ID);

      const text = `${notified[0].title} ${notified[0].body}`;
      expect(text).not.toContain('12 شارع سري جدا');
      expect(text).not.toContain('01000000000');
    });

    it('never lets a failed notification break or duplicate an assignment', async () => {
      // The offers are already written by the time this fires. A notifier that
      // throws must not unwind them, and must not abort the caller either —
      // in the sweep that would abandon every other order in the same pass.
      (
        service as unknown as { notifications: { notifyMany: unknown } }
      ).notifications.notifyMany = () => Promise.reject(new Error('FCM down'));
      nearby = [{ driverId: 1, distanceKm: 1 }];

      const wave = await service.openNextWave(ORDER_ID);

      expect(wave.offered).toEqual([1]);
      // Exactly one assignment, still offered — no duplicate, no rollback.
      expect(assignments).toHaveLength(1);
      expect(assignments[0].status).toBe(AssignmentStatus.OFFERED);
      expect(order.status).toBe(OrderStatus.PENDING_OFFERS);
    });

    it('keeps sweeping other orders when one notification fails', async () => {
      nearby = [{ driverId: 1, distanceKm: 1 }];
      await service.openNextWave(ORDER_ID);
      assignments.forEach((a) => {
        a.expiresAt = new Date(Date.now() - 1000);
      });
      (
        service as unknown as { notifications: { notifyMany: unknown } }
      ).notifications.notifyMany = () => Promise.reject(new Error('FCM down'));

      const result = await service.runSweep();

      // The lapse was still recorded and the order still reached its verdict.
      expect(result.expiredOffers).toBe(1);
      expect(result.expiredOrders).toEqual([ORDER_ID]);
      expect(order.status).toBe(OrderStatus.EXPIRED);
    });
  });
});
