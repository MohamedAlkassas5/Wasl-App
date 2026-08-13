import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderStatus } from './entities/order.entity';
import { OrderAssignment } from './entities/order-assignment.entity';
import { OrderAssignmentService } from './order-assignment.service';
import { InAppNotification } from './entities/notification.entity';
import {
  DeliveryPartner,
  DeliveryVerificationStatus,
} from '../delivery/entities/delivery-partner.entity';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { AccountStatus, User } from '../users/entities/user.entity';
import { OrderItem } from './entities/order-item.entity';
import { CatalogService } from '../catalog/catalog.service';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * What a driver can and cannot change by accepting an order.
 *
 * This is the rule that replaced driver bidding. Under the old flow a driver
 * named their own delivery fee and `acceptOffer` copied it onto
 * `finalDeliveryFee` with nothing checking it against the zone table, so the
 * driver — not the server — had the last word on price.
 *
 * Now acceptance decides exactly one thing: who gets the order. The fee is
 * whatever the server already quoted at creation, frozen as it is. There is no
 * request body on this route to smuggle a number through, and these tests exist
 * so that stays true.
 */
describe('OrdersService — acceptance freezes the server price', () => {
  const DRIVER_ID = 20;

  let order: Partial<Order>;
  let saved: Partial<Order>[];
  /** Whether this driver currently holds a live offer on the order. */
  let hasLiveOffer: boolean;

  const buildOrder = (overrides: Partial<Order> = {}): Partial<Order> => ({
    id: 7,
    customerId: 10,
    status: OrderStatus.PENDING_OFFERS,
    // What the zone table said this delivery costs.
    estimatedDeliveryFee: 40,
    // Nothing has been settled on yet.
    finalDeliveryFee: 0,
    ...overrides,
  });

  const build = async (
    orderRow: Partial<Order>,
    options: {
      driver?: Partial<DeliveryPartner>;
      /** How many orders this driver is already working. */
      activeOrders?: number;
      offerIsLive?: boolean;
    } = {},
  ): Promise<OrdersService> => {
    order = orderRow;
    saved = [];
    hasLiveOffer = options.offerIsLive ?? true;

    const orderRepo = {
      findOne: () => Promise.resolve(order),
      save: (o: Partial<Order>) => {
        saved.push(o);
        return Promise.resolve(o);
      },
      count: () => Promise.resolve(options.activeOrders ?? 0),
    };

    const manager = {
      getRepository: () => orderRepo,
      findOne: (entity: unknown) => {
        if (entity === User) {
          return Promise.resolve({
            id: DRIVER_ID,
            status: AccountStatus.ACTIVE,
          });
        }
        if (entity === DeliveryPartner) {
          return Promise.resolve({
            userId: DRIVER_ID,
            verificationStatus: DeliveryVerificationStatus.APPROVED,
            isOnline: true,
            balance: 100,
            ...options.driver,
          });
        }
        return Promise.resolve(null);
      },
      update: (entity: unknown, _criteria: unknown, patch: Partial<Order>) => {
        if (entity === OrderAssignment) {
          // Promoting the winner only affects a row that is still `offered`.
          return Promise.resolve({ affected: hasLiveOffer ? 1 : 0 });
        }
        if (entity === Order) {
          if (order.status !== OrderStatus.PENDING_OFFERS) {
            return Promise.resolve({ affected: 0 });
          }
          Object.assign(order, patch);
          saved.push({ ...patch });
          return Promise.resolve({ affected: 1 });
        }
        return Promise.resolve({ affected: 0 });
      },
      // Withdrawing this driver's offers on other orders.
      createQueryBuilder: () => ({
        update: () => ({
          set: () => ({
            where: () => ({
              andWhere: () => ({
                andWhere: () => ({ execute: () => Promise.resolve({}) }),
              }),
            }),
          }),
        }),
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            ...orderRepo,
            manager: {
              transaction: (run: (m: unknown) => Promise<unknown>) =>
                run(manager),
            },
          },
        },
        { provide: getRepositoryToken(DeliveryPartner), useValue: {} },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: {
            create: (v: unknown) => v,
            save: jest.fn().mockResolvedValue(undefined),
          },
        },
        { provide: getRepositoryToken(User), useValue: {} },
        { provide: getRepositoryToken(OrderItem), useValue: {} },
        { provide: CatalogService, useValue: {} },
        {
          provide: PricingService,
          useValue: { minWalletToGoOnline: () => 5 },
        },
        { provide: DeliveryService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        {
          // Notifications are a side effect of these flows, not their subject.
          provide: NotificationsService,
          useValue: {
            notify: jest.fn().mockResolvedValue(undefined),
            notifyMany: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: OrderAssignmentService,
          useValue: { liveOffersFor: jest.fn().mockResolvedValue([]) },
        },
      ],
    }).compile();

    return module.get(OrdersService);
  };

  /** The patch that actually claimed the order. */
  const claim = () => saved.find((s) => s.status === OrderStatus.ACCEPTED);

  it('copies the server’s own quote onto the order, untouched', async () => {
    const service = await build(buildOrder());

    await service.acceptAvailableOrder(7, DRIVER_ID);

    expect(Number(claim()!.finalDeliveryFee)).toBe(40);
    expect(claim()!.acceptedDriverId).toBe(DRIVER_ID);
  });

  it('does not let a stale fee already on the order survive acceptance', async () => {
    // If anything ever wrote a fee onto the order before assignment, acceptance
    // overwrites it from the quote rather than honouring it.
    const service = await build(
      buildOrder({ finalDeliveryFee: 500, estimatedDeliveryFee: 40 }),
    );

    await service.acceptAvailableOrder(7, DRIVER_ID);

    expect(Number(claim()!.finalDeliveryFee)).toBe(40);
  });

  it('stamps the moment of acceptance', async () => {
    const service = await build(buildOrder());

    await service.acceptAvailableOrder(7, DRIVER_ID);

    expect(claim()!.acceptedAt).toBeInstanceOf(Date);
  });

  it('refuses an order that is no longer waiting for a driver', async () => {
    const service = await build(buildOrder({ status: OrderStatus.ACCEPTED }));

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
      /تم إسناده|لم يعد متاحًا/,
    );
    expect(claim()).toBeUndefined();
  });

  it('refuses a driver whose wallet is under the minimum', async () => {
    const service = await build(buildOrder(), { driver: { balance: 1 } });

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
      /رصيد المحفظة/,
    );
    expect(claim()).toBeUndefined();
  });

  it('refuses a driver who is offline', async () => {
    const service = await build(buildOrder(), {
      driver: { isOnline: false },
    });

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
      /متصل/,
    );
    expect(claim()).toBeUndefined();
  });

  it('refuses a driver whose documents were never approved', async () => {
    const service = await build(buildOrder(), {
      driver: { verificationStatus: DeliveryVerificationStatus.PENDING },
    });

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow();
    expect(claim()).toBeUndefined();
  });

  describe('one active order per driver', () => {
    it('refuses a driver who is already working an order', async () => {
      const service = await build(buildOrder(), { activeOrders: 1 });

      await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
        /طلب قيد التنفيذ بالفعل/,
      );
      expect(claim()).toBeUndefined();
    });

    it('lets a driver with nothing in hand accept', async () => {
      const service = await build(buildOrder(), { activeOrders: 0 });

      await expect(
        service.acceptAvailableOrder(7, DRIVER_ID),
      ).resolves.toBeDefined();
    });
  });

  describe('the offer has to be theirs', () => {
    it('refuses a driver whose offer has already lapsed', async () => {
      // The sweep expired it a moment before the request landed: promoting the
      // winner affects no row, so acceptance is refused rather than silently
      // handing them an order they were no longer being offered.
      const service = await build(buildOrder(), { offerIsLive: false });

      await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
        /انتهت مهلة هذا العرض/,
      );
      expect(claim()).toBeUndefined();
    });

    it('refuses a driver who was never offered this order at all', async () => {
      // Same mechanism: with no `offered` row for them there is nothing to
      // promote. This is what stops the targeted waves being decorative.
      const service = await build(buildOrder(), { offerIsLive: false });

      await expect(service.acceptAvailableOrder(7, 999)).rejects.toBeDefined();
      expect(claim()).toBeUndefined();
    });
  });
});
