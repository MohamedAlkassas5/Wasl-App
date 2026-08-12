import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderOffer, OrderStatus } from './entities/order.entity';
import { InAppNotification } from './entities/notification.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { AuthUser } from '../auth/current-user';
import { User, UserRole } from '../users/entities/user.entity';

/**
 * Ownership rules on orders, with the repositories stubbed. The point of these
 * is that a logged-in stranger cannot read or steer somebody else's order.
 */
describe('OrdersService (order ownership)', () => {
  const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
  const ASSIGNED_DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
  const STRANGER: AuthUser = { sub: 77, role: UserRole.DELIVERY };
  const ADMIN: AuthUser = { sub: 1, role: UserRole.ADMIN };

  /** Builds the service with a given order row behind the repository. */
  const buildService = async (
    orderRow: Partial<Order>,
    offerRow: Partial<OrderOffer> | null = null,
  ): Promise<OrdersService> => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            findOne: jest.fn().mockResolvedValue(orderRow),
            save: jest
              .fn()
              .mockImplementation((o: Order) => Promise.resolve(o)),
          },
        },
        {
          provide: getRepositoryToken(OrderOffer),
          useValue: {
            find: jest.fn().mockResolvedValue([]),
            findOne: jest.fn().mockResolvedValue(offerRow),
            delete: jest.fn().mockResolvedValue(undefined),
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
        { provide: PricingService, useValue: { commissionForFee: () => 4 } },
        { provide: DeliveryService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
      ],
    }).compile();

    return module.get(OrdersService);
  };

  const acceptedOrder: Partial<Order> = {
    id: 5,
    customerId: CUSTOMER.sub,
    acceptedDriverId: ASSIGNED_DRIVER.sub,
    status: OrderStatus.ACCEPTED,
  };

  it('is defined', async () => {
    expect(await buildService(acceptedOrder)).toBeDefined();
  });

  it('shows the offers on an order to its customer', async () => {
    const service = await buildService(acceptedOrder);
    await expect(service.getOrderOffers(5, CUSTOMER)).resolves.toEqual([]);
  });

  it('hides them from a driver who is not the customer', async () => {
    const service = await buildService(acceptedOrder);
    await expect(service.getOrderOffers(5, STRANGER)).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('hides them even from the order’s own assigned driver', async () => {
    // Offers are the customer's private pricing view, not the driver's.
    const service = await buildService(acceptedOrder);
    await expect(service.getOrderOffers(5, ASSIGNED_DRIVER)).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('lets an admin through', async () => {
    const service = await buildService(acceptedOrder);
    await expect(service.getOrderOffers(5, ADMIN)).resolves.toEqual([]);
  });

  it('refuses an offer that belongs to a different order', async () => {
    // Without this check a customer could accept a cheaper offer that was made
    // on somebody else's order.
    const service = await buildService(
      { ...acceptedOrder, status: OrderStatus.PENDING_OFFERS },
      { id: 99, orderId: 6, driverId: STRANGER.sub, deliveryFee: 5 },
    );

    await expect(service.acceptOffer(5, 99, CUSTOMER)).rejects.toThrow(
      BadRequestException,
    );
  });

  it('reads the commission from the pricing engine, not a hardcoded number', async () => {
    const service = await buildService(acceptedOrder);
    expect(service.calculateWaslCommission(20)).toBe(4);
  });
});
