import { BadRequestException } from '@nestjs/common';
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
import { NotificationsService } from '../notifications/notifications.service';
import { CatalogService } from '../catalog/catalog.service';
import { User, UserRole } from '../users/entities/user.entity';
import { OrderItem } from './entities/order-item.entity';
import { CreateOrderDto } from './dto/create-order.dto';
import { AuthUser } from '../auth/current-user';

/**
 * A closed shop stops new orders and nothing else.
 *
 * The two halves of that sentence are equally important. Closing must actually
 * block a cart from becoming an order — checking the products alone did not,
 * because an item stays `isAvailable` when a kitchen shuts for the night. And
 * closing must not reach backwards: an order already placed has been paid
 * attention to by a driver, possibly already cooked, and is none of this
 * switch's business.
 */
describe('OrdersService — merchant availability (CP6-D)', () => {
  const CUSTOMER_ID = 10;
  const DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };

  let savedOrder: Partial<Order>;
  let orderRow: Partial<Order>;
  let canTakeOrders: boolean;
  let assertCalls: number;
  let service: OrdersService;

  const build = async (options: { open?: boolean } = {}) => {
    savedOrder = {};
    canTakeOrders = options.open ?? true;
    assertCalls = 0;
    orderRow = {
      id: 7,
      customerId: CUSTOMER_ID,
      acceptedDriverId: DRIVER.sub,
      merchantId: 3,
      status: OrderStatus.ACCEPTED,
    };

    const updates: Partial<Order>[] = [];

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            create: (d: Partial<Order>) => d,
            save: (d: Partial<Order>) => {
              savedOrder = d;
              updates.push(d);
              return Promise.resolve({ id: 1, ...d });
            },
            findOne: () => Promise.resolve(orderRow),
          },
        },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: { findOne: () => Promise.resolve(null) },
        },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: { create: (v: unknown) => v, save: jest.fn() },
        },
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: () =>
              Promise.resolve({ id: CUSTOMER_ID, customerZoneId: 1 }),
          },
        },
        {
          provide: getRepositoryToken(OrderItem),
          useValue: { insert: jest.fn().mockResolvedValue(undefined) },
        },
        {
          provide: CatalogService,
          useValue: {
            assertMerchantCanTakeOrders: () => {
              assertCalls += 1;
              if (!canTakeOrders) {
                return Promise.reject(
                  new BadRequestException('المتجر مقفول دلوقتي'),
                );
              }
              return Promise.resolve({ id: 3 });
            },
            getSellableProducts: () =>
              Promise.resolve([
                {
                  product: { id: 1, name: 'برجر', price: 50, merchantId: 3 },
                  sizes: [],
                  addons: [],
                },
              ]),
          },
        },
        {
          provide: PricingService,
          useValue: {
            quoteForDestinationZone: () => Promise.resolve({ deliveryFee: 20 }),
            quoteForZones: () => Promise.resolve({ deliveryFee: 20 }),
            quoteForDistance: () => ({ deliveryFee: 20 }),
            minWalletToGoOnline: () => 5,
            commissionForFee: () => 5,
          },
        },
        { provide: DeliveryService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        {
          provide: OrderAssignmentService,
          useValue: {
            openNextWave: jest.fn().mockResolvedValue({ offered: [] }),
            liveOffersFor: jest.fn().mockResolvedValue([]),
          },
        },
        {
          provide: NotificationsService,
          useValue: { notify: jest.fn(), notifyMany: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(OrdersService);
    return { updates };
  };

  const cartOrder = () =>
    ({
      customerName: 'أحمد',
      customerPhone: '01000000000',
      categoryType: 'مطاعم',
      itemsDescription: '',
      deliveryAddressText: 'عنوان',
      latitude: 30.7649,
      longitude: 30.7003,
      merchantId: 3,
      items: [{ productId: 1, quantity: 1 }],
    }) as unknown as CreateOrderDto;

  describe('placing an order', () => {
    it('goes through when the store is open', async () => {
      await build({ open: true });

      await service.createOrder(CUSTOMER_ID, cartOrder());

      expect(savedOrder.merchantId).toBe(3);
      expect(assertCalls).toBe(1);
    });

    it('is refused when the store is closed', async () => {
      await build({ open: false });

      await expect(
        service.createOrder(CUSTOMER_ID, cartOrder()),
      ).rejects.toThrow(BadRequestException);
    });

    it('writes no order at all when the store is closed', async () => {
      await build({ open: false });

      await service.createOrder(CUSTOMER_ID, cartOrder()).catch(() => null);

      expect(savedOrder).toEqual({});
    });

    it('checks the store before pricing anything', async () => {
      // Refusing after the catalog lookup would still be correct, but doing it
      // first keeps a closed shop from doing any pricing work at all.
      await build({ open: false });

      await service.createOrder(CUSTOMER_ID, cartOrder()).catch(() => null);

      expect(assertCalls).toBe(1);
      expect(savedOrder.estimatedDeliveryFee).toBeUndefined();
    });
  });

  describe('orders that already exist', () => {
    it('lets the assigned driver advance an order from a store that has since closed', async () => {
      // The shop closing at 11pm must not strand a delivery already in the
      // driver's hands.
      const { updates } = await build({ open: false });

      await service.updateStatus(7, OrderStatus.AT_STORE, {}, DRIVER);

      expect(updates[0].status).toBe(OrderStatus.AT_STORE);
    });

    it('does not consult merchant availability when advancing an order', async () => {
      const { updates } = await build({ open: false });

      await service.updateStatus(7, OrderStatus.DELIVERING, {}, DRIVER);

      // If a future change added an availability check here, every in-flight
      // order would break the moment its shop closed for the night.
      expect(assertCalls).toBe(0);
      expect(updates[0].status).toBe(OrderStatus.DELIVERING);
    });

    it('lets a Waslly order through with no merchant at all', async () => {
      // Courier runs buy nothing, so there is no shop to be open or closed.
      await build({ open: false });

      await service.createOrder(CUSTOMER_ID, {
        customerName: 'أحمد',
        customerPhone: '01000000000',
        categoryType: 'وصلي',
        itemsDescription: 'ظرف',
        deliveryAddressText: 'عنوان',
        latitude: 30.7649,
        longitude: 30.7003,
      });

      expect(assertCalls).toBe(0);
      expect(savedOrder.merchantId).toBeNull();
    });
  });
});
