import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { FindOperator } from 'typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderStatus, OrderType } from './entities/order.entity';
import { InAppNotification } from './entities/notification.entity';
import {
  DeliveryPartner,
  DeliveryVerificationStatus,
} from '../delivery/entities/delivery-partner.entity';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { OrderAssignmentService } from './order-assignment.service';
import { AuthUser } from '../auth/current-user';
import { AccountStatus, User, UserRole } from '../users/entities/user.entity';
import { OrderItem } from './entities/order-item.entity';
import { CatalogService } from '../catalog/catalog.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateOrderDto } from './dto/create-order.dto';

/**
 * Order visibility, immediately after creation.
 *
 * Two field reports sit behind this file, and the interesting result is that
 * **neither was a server bug** — both were the Flutter apps failing to re-read
 * state the server was already publishing correctly:
 *
 *  1. the customer's new order did not appear under "الطلبات الحالية" until the
 *     app was restarted;
 *  2. the driver never saw the new order at all, and it expired unanswered
 *     sixty seconds later.
 *
 * The live dev database showed `order_assignments` rows being written with the
 * right radius and distance for every one of those orders, so the assignment
 * engine was doing its job and the apps were simply never asking again.
 *
 * These tests pin the three server-side contracts the repaired clients now
 * depend on, so that a later change cannot quietly move the failure back to
 * this side of the wire:
 *
 *  - a brand-new order is in the customer's list straight away, with no status
 *    filter hiding it while it waits for a captain;
 *  - creating an order opens the first assignment wave;
 *  - `/orders/available` hands a driver an order they hold a *live* offer on,
 *    and stops as soon as that offer lapses.
 */
describe('order visibility right after creation', () => {
  const CUSTOMER_ID = 10;
  const DRIVER_ID = 20;
  const NEW_ORDER_ID = 501;

  const DRIVER: AuthUser = { sub: DRIVER_ID, role: UserRole.DELIVERY };

  /** Approved, funded and online — the wave has no reason to skip them. */
  const eligiblePartner: Partial<DeliveryPartner> = {
    userId: DRIVER_ID,
    verificationStatus: DeliveryVerificationStatus.APPROVED,
    balance: 100,
    isOnline: true,
    // No GPS fix: `loadAvailableOrders` then returns the rows unsorted rather
    // than annotating them with a distance, which is not what these are about.
    currentLatitude: undefined,
    currentLongitude: undefined,
  };

  const driverUser: Partial<User> = {
    id: DRIVER_ID,
    role: UserRole.DELIVERY,
    status: AccountStatus.ACTIVE,
  };

  interface Harness {
    service: OrdersService;
    orderRepo: {
      find: jest.Mock;
      findOne: jest.Mock;
      create: jest.Mock;
      save: jest.Mock;
    };
    openNextWave: jest.Mock;
    liveOffersFor: jest.Mock;
  }

  const build = async (
    options: {
      rows?: Partial<Order>[];
      offers?: { orderId: number; expiresAt: Date }[];
    } = {},
  ): Promise<Harness> => {
    const rows = options.rows ?? [];

    const orderRepo = {
      find: jest.fn().mockResolvedValue(rows),
      findOne: jest.fn().mockResolvedValue(null),
      create: jest
        .fn()
        .mockImplementation((row: Partial<Order>) => ({ ...row })),
      save: jest
        .fn()
        .mockImplementation((row: Partial<Order>) =>
          Promise.resolve({ ...row, id: NEW_ORDER_ID }),
        ),
    };

    const openNextWave = jest
      .fn()
      .mockResolvedValue({ offered: [DRIVER_ID], waveNumber: 1 });
    const liveOffersFor = jest.fn().mockResolvedValue(options.offers ?? []);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: getRepositoryToken(Order), useValue: orderRepo },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: {
            findOne: jest.fn().mockResolvedValue(eligiblePartner),
          },
        },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: {
            create: jest.fn().mockImplementation((v: unknown) => v),
            save: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: getRepositoryToken(User),
          useValue: { findOne: jest.fn().mockResolvedValue(driverUser) },
        },
        {
          provide: getRepositoryToken(OrderItem),
          useValue: { insert: jest.fn().mockResolvedValue(undefined) },
        },
        {
          provide: CatalogService,
          useValue: { getSellableProducts: jest.fn().mockResolvedValue([]) },
        },
        {
          provide: PricingService,
          useValue: {
            // No areas on the fixture order, so pricing takes the legacy
            // distance path. What it returns is irrelevant here; that it
            // returns *something* is what lets creation reach the wave.
            quoteForDistance: () => ({ deliveryFee: 20 }),
            commissionForFee: () => 5,
            minWalletToGoOnline: () => 5,
          },
        },
        { provide: DeliveryService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        {
          provide: NotificationsService,
          useValue: {
            notify: jest.fn().mockResolvedValue(undefined),
            notifyMany: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: OrderAssignmentService,
          useValue: { openNextWave, liveOffersFor },
        },
      ],
    }).compile();

    return {
      service: module.get(OrdersService),
      orderRepo,
      openNextWave,
      liveOffersFor,
    };
  };

  /** The minimum a courier order needs to be accepted and priced. */
  const newOrderDto = (): CreateOrderDto =>
    ({
      customerName: 'عميل وصل',
      customerPhone: '201220346717',
      categoryType: 'سوبر ماركت',
      orderType: OrderType.GENERAL,
      itemsDescription: 'اختبار ظهور الطلب',
      deliveryAddressText: 'كوم حمادة',
      latitude: 30.7649,
      longitude: 30.7003,
    }) as CreateOrderDto;

  /**
   * The `where` clauses `loadAvailableOrders` built, flattened. TypeORM takes
   * an array of alternatives there (offered orders OR the driver's own work),
   * and these tests care about which order ids ended up in the first one.
   */
  const whereClauses = (find: jest.Mock): Record<string, unknown>[] => {
    const call = find.mock.calls[0]?.[0] as
      | { where?: Record<string, unknown> | Record<string, unknown>[] }
      | undefined;
    const where = call?.where;
    if (!where) return [];
    return Array.isArray(where) ? where : [where];
  };

  const offeredIdsIn = (find: jest.Mock): number[] => {
    for (const clause of whereClauses(find)) {
      const id = clause.id;
      if (id instanceof FindOperator) {
        return id.value as number[];
      }
    }
    return [];
  };

  // ─── The customer's side ─────────────────────────────────────────────────

  describe('the customer', () => {
    it('has the order in their list the moment it exists', async () => {
      // Exactly what the app re-reads after checkout. The order is seconds old
      // and still waiting for a captain — which must not keep it out of the
      // list, or "الطلبات الحالية" would be empty at the one moment the
      // customer is most certain they just placed something.
      const justCreated: Partial<Order> = {
        id: NEW_ORDER_ID,
        customerId: CUSTOMER_ID,
        status: OrderStatus.PENDING_OFFERS,
        acceptedDriverId: undefined,
      };
      const { service, orderRepo } = await build({ rows: [justCreated] });

      const orders = await service.getCustomerOrders(CUSTOMER_ID);

      expect(orders).toHaveLength(1);
      expect(orders[0]).toMatchObject({
        id: NEW_ORDER_ID,
        status: OrderStatus.PENDING_OFFERS,
      });
      // Scoped to this customer and filtered by nothing else — no status
      // condition that a brand-new order could fall outside of.
      expect(orderRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({ where: { customerId: CUSTOMER_ID } }),
      );
    });
  });

  // ─── The driver's side ───────────────────────────────────────────────────

  describe('creating an order', () => {
    it('opens the first assignment wave on the order it just saved', async () => {
      const { service, openNextWave } = await build();

      await service.createOrder(CUSTOMER_ID, newOrderDto());

      expect(openNextWave).toHaveBeenCalledWith(NEW_ORDER_ID);
    });

    it('still returns the order when the wave throws', async () => {
      // A matching pass having a bad moment must not roll back an order that
      // was created and priced — the sweep re-waves anything left waiting.
      const { service, openNextWave } = await build();
      openNextWave.mockRejectedValue(new Error('matching unavailable'));

      await expect(
        service.createOrder(CUSTOMER_ID, newOrderDto()),
      ).resolves.toMatchObject({ id: NEW_ORDER_ID });
    });
  });

  describe('the driver’s available list', () => {
    it('includes an order they hold a live offer on', async () => {
      const { service, orderRepo } = await build({
        rows: [
          {
            id: NEW_ORDER_ID,
            customerId: CUSTOMER_ID,
            status: OrderStatus.PENDING_OFFERS,
          },
        ],
        offers: [
          {
            orderId: NEW_ORDER_ID,
            expiresAt: new Date(Date.now() + 60_000),
          },
        ],
      });

      const available = await service.getAvailableOrders(DRIVER_ID, DRIVER);

      expect(offeredIdsIn(orderRepo.find)).toContain(NEW_ORDER_ID);
      expect(available.map((order) => order.id)).toContain(NEW_ORDER_ID);
    });

    it('drops the offer the moment its sixty seconds are up', async () => {
      // The window is short by design. What must not happen is a lapsed offer
      // staying answerable — the driver would be shown work the server then
      // refuses.
      const { service, orderRepo } = await build({
        offers: [
          {
            orderId: NEW_ORDER_ID,
            expiresAt: new Date(Date.now() - 1_000),
          },
        ],
      });

      await service.getAvailableOrders(DRIVER_ID, DRIVER);

      expect(offeredIdsIn(orderRepo.find)).not.toContain(NEW_ORDER_ID);
    });

    it('asks for the driver’s own active work as well as their offers', async () => {
      // The driver home screen reads its current trip out of this same
      // response, so the "own work" half of the query has to stay.
      const { service, orderRepo } = await build({
        offers: [
          {
            orderId: NEW_ORDER_ID,
            expiresAt: new Date(Date.now() + 60_000),
          },
        ],
      });

      await service.getAvailableOrders(DRIVER_ID, DRIVER);

      const activeStatuses = whereClauses(orderRepo.find)
        .filter((clause) => clause.acceptedDriverId === DRIVER_ID)
        .map((clause) => clause.status);

      expect(activeStatuses).toEqual(
        expect.arrayContaining([
          OrderStatus.ACCEPTED,
          OrderStatus.AT_STORE,
          OrderStatus.ITEMS_BOUGHT,
          OrderStatus.DELIVERING,
        ]),
      );
    });
  });
});
