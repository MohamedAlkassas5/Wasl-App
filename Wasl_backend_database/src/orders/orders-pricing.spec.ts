import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderOffer, PricingSource } from './entities/order.entity';
import { InAppNotification } from './entities/notification.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { User } from '../users/entities/user.entity';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderItem } from './entities/order-item.entity';
import { CatalogService } from '../catalog/catalog.service';

/**
 * Who decides what a delivery costs.
 *
 * The answer has to be "the server, from the areas involved" — never the
 * client, and never a distance the client could shape. These tests pin that,
 * and pin which rule was used, because the recorded source is what makes a
 * settled order explainable later.
 */
describe('OrdersService (pricing authority)', () => {
  const CUSTOMER_ID = 10;

  /**
   * The approved tables, mirrored here so these tests fail if order creation
   * ever stops agreeing with them. Normal: Kom Hamada 20 · Biban 40 · Breem 40.
   * Routes: same area 20 · a leg through Kom Hamada 40 · Biban ↔ Breem 50.
   */
  const NORMAL_FEES: Record<number, number> = { 1: 20, 2: 40, 3: 40 };
  const ROUTE_FEES: Record<string, number> = {
    '1->1': 20,
    '2->2': 20,
    '3->3': 20,
    '1->2': 40,
    '2->1': 40,
    '1->3': 40,
    '3->1': 40,
    '2->3': 50,
    '3->2': 50,
  };

  let savedOrder: Partial<Order>;

  const build = async (customerZoneId?: number): Promise<OrdersService> => {
    savedOrder = {};

    const pricingService = {
      quoteForDestinationZone: (zoneId: number) => {
        const fee = NORMAL_FEES[zoneId];
        if (fee === undefined) {
          return Promise.reject(new BadRequestException('منطقة غير مدعومة'));
        }
        return Promise.resolve({ deliveryFee: fee });
      },
      quoteForZones: (pickup: number, dropoff: number) => {
        const fee = ROUTE_FEES[`${pickup}->${dropoff}`];
        if (fee === undefined) {
          return Promise.reject(new BadRequestException('مسار غير مدعوم'));
        }
        return Promise.resolve({ deliveryFee: fee });
      },
      // The legacy tier: a deliberately distinctive number so a test can tell
      // "fell back to distance" apart from any real area price.
      quoteForDistance: () => ({ deliveryFee: 999 }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            create: (data: Partial<Order>) => data,
            save: (data: Partial<Order>) => {
              savedOrder = data;
              return Promise.resolve({ id: 1, ...data });
            },
            findOne: jest.fn().mockResolvedValue(null),
          },
        },
        {
          provide: getRepositoryToken(OrderOffer),
          useValue: { find: jest.fn(), findOne: jest.fn(), delete: jest.fn() },
        },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: { findOne: jest.fn().mockResolvedValue(null) },
        },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: {
            create: (v: unknown) => v,
            save: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: () => Promise.resolve({ id: CUSTOMER_ID, customerZoneId }),
          },
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
        { provide: PricingService, useValue: pricingService },
        {
          provide: DeliveryService,
          useValue: {
            findNearbyWithExpansion: jest
              .fn()
              .mockResolvedValue({ drivers: [], radiusKm: 5 }),
          },
        },
        { provide: PaymentsService, useValue: {} },
      ],
    }).compile();

    return module.get(OrdersService);
  };

  /** A destination in Kom Hamada; the areas under test are passed per-case. */
  const orderDto = (overrides: Partial<CreateOrderDto> = {}) =>
    ({
      customerName: 'أحمد',
      customerPhone: '01000000000',
      categoryType: 'مطاعم',
      itemsDescription: 'طلب',
      deliveryAddressText: 'عنوان',
      latitude: 30.7649,
      longitude: 30.7003,
      ...overrides,
    }) as CreateOrderDto;

  describe('normal orders', () => {
    it("uses the customer's saved area when the app sends none", async () => {
      const service = await build(2); // Biban
      await service.createOrder(CUSTOMER_ID, orderDto());

      expect(Number(savedOrder.estimatedDeliveryFee)).toBe(40);
      expect(savedOrder.pricingSource).toBe(PricingSource.NORMAL_ZONE);
      expect(savedOrder.dropoffZoneId).toBe(2);
    });

    it('lets the app deliver to a different approved area explicitly', async () => {
      const service = await build(2);
      await service.createOrder(
        CUSTOMER_ID,
        orderDto({ dropoffZoneId: 1 }), // Kom Hamada
      );

      expect(Number(savedOrder.estimatedDeliveryFee)).toBe(20);
      expect(savedOrder.dropoffZoneId).toBe(1);
    });

    it('refuses an unsupported destination instead of falling back to a distance price', async () => {
      const service = await build(2);
      await expect(
        service.createOrder(CUSTOMER_ID, orderDto({ dropoffZoneId: 99 })),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('Waslly orders', () => {
    it('prices by the chosen route, not by distance', async () => {
      const service = await build(1);
      await service.createOrder(
        CUSTOMER_ID,
        orderDto({ pickupZoneId: 1, dropoffZoneId: 2 }),
      );

      expect(Number(savedOrder.estimatedDeliveryFee)).toBe(40);
      expect(savedOrder.pricingSource).toBe(PricingSource.WASLLY_ROUTE);
      expect(savedOrder.pickupZoneId).toBe(1);
      expect(savedOrder.dropoffZoneId).toBe(2);
    });

    it('charges the village-to-village premium', async () => {
      const service = await build(1);
      await service.createOrder(
        CUSTOMER_ID,
        orderDto({ pickupZoneId: 2, dropoffZoneId: 3 }), // بيبان → بريم
      );

      expect(Number(savedOrder.estimatedDeliveryFee)).toBe(50);
      expect(savedOrder.pricingSource).toBe(PricingSource.WASLLY_ROUTE);
    });

    it('refuses a route with no approved rate', async () => {
      const service = await build(1);
      await expect(
        service.createOrder(
          CUSTOMER_ID,
          orderDto({ pickupZoneId: 1, dropoffZoneId: 99 }),
        ),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('the client never sets the price', () => {
    it('ignores a delivery fee smuggled into the request body', async () => {
      const service = await build(2); // Biban ⇒ 40
      await service.createOrder(
        CUSTOMER_ID,
        orderDto({
          estimatedDeliveryFee: 1,
          finalDeliveryFee: 1,
          deliveryFee: 1,
        } as unknown as Partial<CreateOrderDto>),
      );

      expect(Number(savedOrder.estimatedDeliveryFee)).toBe(40);
    });

    it('records the trip distance without letting it price the order', async () => {
      const service = await build(1); // Kom Hamada ⇒ 20
      await service.createOrder(
        CUSTOMER_ID,
        orderDto({ pickupLatitude: 31.2, pickupLongitude: 29.9 }),
      );

      // Alexandria-ish pickup is far enough that the legacy tier would have
      // charged more than the flat area fee.
      expect(Number(savedOrder.estimatedDeliveryFee)).toBe(20);
      expect(savedOrder.distanceKm).toBeGreaterThan(0);
      expect(savedOrder.pricingSource).toBe(PricingSource.NORMAL_ZONE);
    });
  });

  it('falls back to the legacy distance rule only when no area is known at all', async () => {
    const service = await build(undefined);
    await service.createOrder(CUSTOMER_ID, orderDto());

    expect(Number(savedOrder.estimatedDeliveryFee)).toBe(999);
    expect(savedOrder.pricingSource).toBe(PricingSource.LEGACY_DISTANCE);
  });
});
