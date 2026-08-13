import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderStatus, SettlementStatus } from './entities/order.entity';
import { InAppNotification } from './entities/notification.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { OrderAssignmentService } from './order-assignment.service';
import { User, UserRole } from '../users/entities/user.entity';
import { AuthUser } from '../auth/current-user';
import { WalletTransaction } from '../payments/entities/wallet-transaction.entity';
import { OrderItem } from './entities/order-item.entity';
import { CatalogService } from '../catalog/catalog.service';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * Delivery completion and the money that moves with it.
 *
 * The old completion path recomputed the commission from live settings, debited
 * the wallet outside any transaction, and had no guard against being called
 * twice — so a double tap charged the driver twice. These tests pin the
 * replacement: settle once, from the order's own frozen numbers.
 *
 * The unique constraint that makes this safe under real concurrency lives in
 * the database, so the genuine race is proven separately against Postgres
 * (see the Checkpoint 3 concurrency run); here the in-memory fake models it by
 * refusing a duplicate reference the same way.
 */
describe('OrdersService — completion & settlement', () => {
  const DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
  const OTHER_DRIVER: AuthUser = { sub: 21, role: UserRole.DELIVERY };
  const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };

  let order: Partial<Order>;
  let balance: number;
  let ledger: Partial<WalletTransaction>[];
  let service: OrdersService;

  const buildOrder = (overrides: Partial<Order> = {}): Partial<Order> => ({
    id: 1,
    customerId: CUSTOMER.sub,
    acceptedDriverId: DRIVER.sub,
    status: OrderStatus.DELIVERING,
    finalDeliveryFee: 40,
    settlementStatus: SettlementStatus.PENDING,
    ...overrides,
  });

  /** Mirrors the real transaction: locks, mutates, and enforces the unique. */
  const makeManager = () => ({
    findOne: (entity: unknown) => {
      if (entity === Order) return Promise.resolve(order);
      if (entity === DeliveryPartner) {
        return Promise.resolve({ userId: DRIVER.sub, balance });
      }
      return Promise.resolve(null);
    },
    update: (entity: unknown, _criteria: unknown, patch: Partial<Order>) => {
      if (entity === Order) Object.assign(order, patch);
      if (entity === DeliveryPartner && 'balance' in patch) {
        balance = (patch as { balance: number }).balance;
      }
      return Promise.resolve({ affected: 1 });
    },
    insert: (entity: unknown, row: Partial<WalletTransaction>) => {
      if (entity === WalletTransaction) {
        // The database's UNIQUE(reference) constraint, in miniature.
        if (
          row.reference &&
          ledger.some((l) => l.reference === row.reference)
        ) {
          return Promise.reject(
            Object.assign(new Error('duplicate key'), { code: '23505' }),
          );
        }
        ledger.push(row);
      }
      return Promise.resolve({ identifiers: [] });
    },
  });

  beforeEach(async () => {
    order = buildOrder();
    balance = 100;
    ledger = [];

    const manager = makeManager();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            manager: {
              transaction: (run: (m: unknown) => Promise<unknown>) =>
                run(manager),
            },
            findOne: () => Promise.resolve(order),
            save: (o: Partial<Order>) => Promise.resolve(o),
            find: () => Promise.resolve([]),
          },
        },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: { findOne: () => Promise.resolve({ balance }) },
        },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: { create: (v: unknown) => v, save: jest.fn() },
        },
        {
          provide: getRepositoryToken(User),
          useValue: { findOne: () => Promise.resolve(null) },
        },
        {
          // Itemised orders only: this suite settles, it never builds a cart.
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
            // max(40 × 20%, 5) = 8
            commissionForFee: (fee: number) => Math.max(fee * 0.2, 5),
            minWalletToGoOnline: () => 5,
          },
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
          // Order creation opens the first assignment wave; these suites are
          // about pricing and settlement, so it only has to exist.
          provide: OrderAssignmentService,
          useValue: {
            openNextWave: jest.fn().mockResolvedValue({ offered: [] }),
            liveOffersFor: jest.fn().mockResolvedValue([]),
          },
        },
      ],
    }).compile();

    service = module.get(OrdersService);
  });

  describe('a valid completion', () => {
    it('marks the order completed and settled', async () => {
      await service.completeOrder(1, DRIVER);

      expect(order.status).toBe(OrderStatus.COMPLETED);
      expect(order.settlementStatus).toBe(SettlementStatus.SETTLED);
      expect(order.settledAt).toBeInstanceOf(Date);
      expect(order.completedAt).toBeInstanceOf(Date);
    });

    it('freezes the commission and driver share onto the order', async () => {
      await service.completeOrder(1, DRIVER);

      expect(Number(order.commissionAmount)).toBe(8);
      expect(Number(order.driverShare)).toBe(32);
    });

    it('charges the commission to the wallet exactly once', async () => {
      await service.completeOrder(1, DRIVER);

      expect(ledger).toHaveLength(1);
      expect(ledger[0].amount).toBe(-8);
      expect(balance).toBe(92);
    });

    it('links the ledger entry to the order it settles', async () => {
      await service.completeOrder(1, DRIVER);

      expect(ledger[0].orderId).toBe(1);
      expect(ledger[0].reference).toBe('order-1-commission');
      expect(order.settlementReference).toBe('order-1-commission');
    });

    it('does not require the customer to confirm anything', async () => {
      // No customer action is consulted anywhere in the path.
      await expect(service.completeOrder(1, DRIVER)).resolves.toMatchObject({
        success: true,
      });
    });
  });

  describe('idempotency', () => {
    it('a second completion neither charges again nor errors', async () => {
      await service.completeOrder(1, DRIVER);
      const result = await service.completeOrder(1, DRIVER);

      expect(result.alreadySettled).toBe(true);
      expect(ledger).toHaveLength(1);
      expect(balance).toBe(92);
    });

    it('survives being called several times', async () => {
      await service.completeOrder(1, DRIVER);
      await service.completeOrder(1, DRIVER);
      await service.completeOrder(1, DRIVER);

      expect(ledger).toHaveLength(1);
      expect(balance).toBe(92);
      expect(Number(order.commissionAmount)).toBe(8);
    });
  });

  describe('refusals', () => {
    it('refuses before the driver has started delivering', async () => {
      order = buildOrder({ status: OrderStatus.ACCEPTED });
      await expect(service.completeOrder(1, DRIVER)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(ledger).toHaveLength(0);
    });

    it('refuses while the driver is still at the shop', async () => {
      order = buildOrder({ status: OrderStatus.AT_STORE });
      await expect(service.completeOrder(1, DRIVER)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('refuses a cancelled order', async () => {
      order = buildOrder({ status: OrderStatus.CANCELLED });
      await expect(service.completeOrder(1, DRIVER)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('refuses a driver the order is not assigned to', async () => {
      await expect(
        service.completeOrder(1, OTHER_DRIVER),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(ledger).toHaveLength(0);
    });

    it('refuses the customer', async () => {
      await expect(service.completeOrder(1, CUSTOMER)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('404s on an order that does not exist', async () => {
      order = undefined as unknown as Partial<Order>;
      await expect(service.completeOrder(1, DRIVER)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('the snapshot does not follow live settings', () => {
    it('uses the fee frozen on the order, not a recomputed one', async () => {
      // The order was quoted at 40. Whatever the rate table says now is
      // irrelevant to an order that has already been agreed.
      order = buildOrder({ finalDeliveryFee: 40, estimatedDeliveryFee: 999 });
      await service.completeOrder(1, DRIVER);

      expect(Number(order.commissionAmount)).toBe(8);
      expect(Number(order.driverShare)).toBe(32);
    });

    it('a settled order keeps its numbers when completion is retried', async () => {
      await service.completeOrder(1, DRIVER);
      const settled = {
        commission: Number(order.commissionAmount),
        share: Number(order.driverShare),
      };

      order.finalDeliveryFee = 500; // as if a rate change rewrote it
      await service.completeOrder(1, DRIVER);

      expect(Number(order.commissionAmount)).toBe(settled.commission);
      expect(Number(order.driverShare)).toBe(settled.share);
    });
  });

  it('takes the driver offline when settlement drops them below the minimum', async () => {
    balance = 10; // 10 − 8 = 2, under the 5 EGP minimum
    let wentOffline = false;
    const manager = makeManager();
    const original = manager.update;
    manager.update = (entity: unknown, criteria: unknown, patch: object) => {
      if (entity === DeliveryPartner && 'isOnline' in patch) {
        wentOffline = (patch as { isOnline: boolean }).isOnline === false;
      }
      return original(entity, criteria, patch);
    };

    const module = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            manager: {
              transaction: (run: (m: unknown) => Promise<unknown>) =>
                run(manager),
            },
          },
        },
        { provide: getRepositoryToken(DeliveryPartner), useValue: {} },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: { create: (v: unknown) => v, save: jest.fn() },
        },
        { provide: getRepositoryToken(User), useValue: {} },
        { provide: getRepositoryToken(OrderItem), useValue: {} },
        { provide: CatalogService, useValue: {} },
        {
          provide: PricingService,
          useValue: {
            commissionForFee: (fee: number) => Math.max(fee * 0.2, 5),
            minWalletToGoOnline: () => 5,
          },
        },
        { provide: DeliveryService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        {
          // Order creation opens the first assignment wave; these suites are
          // about pricing and settlement, so it only has to exist.
          provide: OrderAssignmentService,
          useValue: {
            openNextWave: jest.fn().mockResolvedValue({ offered: [] }),
            liveOffersFor: jest.fn().mockResolvedValue([]),
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            notify: jest.fn().mockResolvedValue(undefined),
            notifyMany: jest.fn().mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    await module.get(OrdersService).completeOrder(1, DRIVER);
    expect(wentOffline).toBe(true);
  });
});
