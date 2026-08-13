import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderStatus } from './entities/order.entity';
import { InAppNotification } from './entities/notification.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { OrderAssignmentService } from './order-assignment.service';
import { AuthUser } from '../auth/current-user';
import { User, UserRole } from '../users/entities/user.entity';
import { OrderItem } from './entities/order-item.entity';
import { CatalogService } from '../catalog/catalog.service';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * Ownership rules on orders, with the repositories stubbed. The point of these
 * is that a logged-in stranger cannot read or steer somebody else's order.
 *
 * These used to exercise ownership through the offers API, which was the
 * customer-only surface at the time. Bidding is gone; `cancelOrderByCustomer`
 * is now the customer-only action, and it goes through the same `getOrderFor`
 * check — so the rule under test is unchanged even though the door into it is.
 */
describe('OrdersService (order ownership)', () => {
  const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
  const ASSIGNED_DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
  const STRANGER: AuthUser = { sub: 77, role: UserRole.DELIVERY };
  const ADMIN: AuthUser = { sub: 1, role: UserRole.ADMIN };

  /**
   * Builds the service with a given order row behind the repository.
   *
   * The row is copied, not shared: cancelling mutates the object it is handed,
   * so a fixture passed straight through would carry `cancelled` into whichever
   * test ran next.
   */
  const buildService = async (
    orderRow: Partial<Order>,
  ): Promise<OrdersService> => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            findOne: jest.fn().mockResolvedValue({ ...orderRow }),
            save: jest
              .fn()
              .mockImplementation((o: Order) => Promise.resolve(o)),
          },
        },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: { findOne: jest.fn().mockResolvedValue(null) },
        },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: {
            create: jest.fn().mockImplementation((v: unknown) => v),
            save: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          // Order creation reads the customer's saved area to price a normal
          // order; these ownership tests never get that far.
          provide: getRepositoryToken(User),
          useValue: { findOne: jest.fn().mockResolvedValue(null) },
        },
        {
          // Itemised orders only: these suites never build a cart.
          provide: getRepositoryToken(OrderItem),
          useValue: { insert: jest.fn().mockResolvedValue(undefined) },
        },
        {
          provide: CatalogService,
          useValue: { getSellableProducts: jest.fn().mockResolvedValue([]) },
        },
        { provide: PricingService, useValue: { commissionForFee: () => 4 } },
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

    return module.get(OrdersService);
  };

  const pendingOrder: Partial<Order> = {
    id: 5,
    customerId: CUSTOMER.sub,
    acceptedDriverId: ASSIGNED_DRIVER.sub,
    status: OrderStatus.PENDING_OFFERS,
  };

  const acceptedOrder: Partial<Order> = {
    ...pendingOrder,
    status: OrderStatus.ACCEPTED,
  };

  it('is defined', async () => {
    expect(await buildService(acceptedOrder)).toBeDefined();
  });

  it('lets the order’s own customer cancel it while it is unassigned', async () => {
    const service = await buildService(pendingOrder);
    await expect(service.cancelOrderByCustomer(5, CUSTOMER)).resolves.toEqual(
      expect.objectContaining({ success: true }),
    );
  });

  it('refuses a driver who has nothing to do with the order', async () => {
    const service = await buildService(pendingOrder);
    await expect(service.cancelOrderByCustomer(5, STRANGER)).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('refuses even the order’s own assigned driver', async () => {
    // Cancelling on the customer's behalf is not the driver's to do: once they
    // have accepted, their route is the penalty-charging one in
    // OrderCancellationService.
    const service = await buildService(pendingOrder);
    await expect(
      service.cancelOrderByCustomer(5, ASSIGNED_DRIVER),
    ).rejects.toThrow(ForbiddenException);
  });

  it('lets an admin through', async () => {
    const service = await buildService(pendingOrder);
    await expect(service.cancelOrderByCustomer(5, ADMIN)).resolves.toEqual(
      expect.objectContaining({ success: true }),
    );
  });

  it('refuses a free cancellation once a driver has accepted', async () => {
    // The free path stops at assignment. After that a cancellation charges the
    // driver a penalty, so it belongs to the cancellation domain and not here.
    const service = await buildService(acceptedOrder);
    await expect(service.cancelOrderByCustomer(5, CUSTOMER)).rejects.toThrow(
      BadRequestException,
    );
  });

  it('reads the commission from the pricing engine, not a hardcoded number', async () => {
    const service = await buildService(acceptedOrder);
    expect(service.calculateWaslCommission(20)).toBe(4);
  });
});
