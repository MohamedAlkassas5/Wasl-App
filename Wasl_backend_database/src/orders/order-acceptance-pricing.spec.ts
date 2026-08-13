import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderStatus } from './entities/order.entity';
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
    driver: Partial<DeliveryPartner> = {},
  ): Promise<OrdersService> => {
    order = orderRow;
    saved = [];

    const manager = {
      getRepository: () => ({
        findOne: () => Promise.resolve(order),
        save: (o: Partial<Order>) => {
          saved.push(o);
          return Promise.resolve(o);
        },
      }),
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
            ...driver,
          });
        }
        return Promise.resolve(null);
      },
    };

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
      ],
    }).compile();

    return module.get(OrdersService);
  };

  it('copies the server’s own quote onto the order, untouched', async () => {
    const service = await build(buildOrder());

    await service.acceptAvailableOrder(7, DRIVER_ID);

    expect(Number(saved[0].finalDeliveryFee)).toBe(40);
    expect(saved[0].status).toBe(OrderStatus.ACCEPTED);
    expect(saved[0].acceptedDriverId).toBe(DRIVER_ID);
  });

  it('does not let a stale fee already on the order survive acceptance', async () => {
    // If anything ever wrote a fee onto the order before assignment, acceptance
    // overwrites it from the quote rather than honouring it.
    const service = await build(
      buildOrder({ finalDeliveryFee: 500, estimatedDeliveryFee: 40 }),
    );

    await service.acceptAvailableOrder(7, DRIVER_ID);

    expect(Number(saved[0].finalDeliveryFee)).toBe(40);
  });

  it('stamps the moment of acceptance', async () => {
    const service = await build(buildOrder());

    await service.acceptAvailableOrder(7, DRIVER_ID);

    expect(saved[0].acceptedAt).toBeInstanceOf(Date);
  });

  it('refuses an order that is no longer waiting for a driver', async () => {
    const service = await build(buildOrder({ status: OrderStatus.ACCEPTED }));

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
      /تم إسناده|لم يعد متاحًا/,
    );
    expect(saved).toHaveLength(0);
  });

  it('refuses a driver whose wallet is under the minimum', async () => {
    const service = await build(buildOrder(), { balance: 1 });

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
      /رصيد المحفظة/,
    );
    expect(saved).toHaveLength(0);
  });

  it('refuses a driver who is offline', async () => {
    const service = await build(buildOrder(), { isOnline: false });

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow(
      /متصل/,
    );
    expect(saved).toHaveLength(0);
  });

  it('refuses a driver whose documents were never approved', async () => {
    const service = await build(buildOrder(), {
      verificationStatus: DeliveryVerificationStatus.PENDING,
    });

    await expect(service.acceptAvailableOrder(7, DRIVER_ID)).rejects.toThrow();
    expect(saved).toHaveLength(0);
  });
});
