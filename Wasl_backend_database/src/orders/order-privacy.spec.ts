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
import { AuthUser } from '../auth/current-user';

/**
 * CP6-E. What an order tells you about the people on it.
 *
 * `relations: { acceptedDriver: true }` loads the driver's whole `User` row,
 * and the tracking and history endpoints spread that straight into their
 * responses. Verified against a real database before the fix: the customer
 * received the driver's **bcrypt password hash**, plus their email, Firebase
 * uid, admin notes and account status.
 *
 * The customer needs to know who is coming and how to ring them. Everything
 * else about that person belongs to that person.
 */
describe('OrdersService — what the customer learns about the driver (CP6-E)', () => {
  const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };

  /** Every column `User` actually has, as the ORM would hand it back. */
  const fullDriverRow = {
    id: 20,
    name: 'كابتن محمد',
    phone: '01000000020',
    passwordHash: '$2b$10$notTheCustomersBusiness',
    role: UserRole.DELIVERY,
    status: 'active',
    admin_notes: 'ملاحظة إدارية داخلية',
    email: 'driver@example.com',
    firebaseUid: 'firebase-uid-xyz',
    customerZoneId: null,
    deletedAt: null,
    created_at: new Date(),
  } as unknown as User;

  const LEAKY_FIELDS = [
    'passwordHash',
    'email',
    'firebaseUid',
    'admin_notes',
    'deletedAt',
    'role',
    'status',
  ];

  const orderRow = {
    id: 7,
    customerId: CUSTOMER.sub,
    acceptedDriverId: 20,
    status: OrderStatus.DELIVERING,
    finalDeliveryFee: 40,
    acceptedDriver: fullDriverRow,
    items: [],
  } as unknown as Order;

  let service: OrdersService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: {
            findOne: () => Promise.resolve(orderRow),
            find: () => Promise.resolve([orderRow]),
            save: (o: Partial<Order>) => Promise.resolve(o),
          },
        },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: {
            findOne: () =>
              Promise.resolve({
                userId: 20,
                currentLatitude: 30.7,
                currentLongitude: 30.7,
                lastLocationUpdate: new Date(),
                rating: 4.9,
                balance: 250,
              }),
          },
        },
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: { create: (v: unknown) => v, save: jest.fn() },
        },
        { provide: getRepositoryToken(User), useValue: { findOne: jest.fn() } },
        { provide: getRepositoryToken(OrderItem), useValue: {} },
        { provide: CatalogService, useValue: {} },
        { provide: PricingService, useValue: { commissionForFee: () => 5 } },
        { provide: DeliveryService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        {
          provide: OrderAssignmentService,
          useValue: { liveOffersFor: jest.fn().mockResolvedValue([]) },
        },
        {
          provide: NotificationsService,
          useValue: { notify: jest.fn(), notifyMany: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(OrdersService);
  });

  describe('order tracking', () => {
    it('gives the customer the driver’s name and phone', async () => {
      const result = await service.getOrderDetailsForCustomer(7, CUSTOMER);

      expect(result.acceptedDriver).toMatchObject({
        id: 20,
        name: 'كابتن محمد',
        phone: '01000000020',
      });
    });

    it('never sends the driver’s password hash', async () => {
      const result = await service.getOrderDetailsForCustomer(7, CUSTOMER);

      expect(result.acceptedDriver).not.toHaveProperty('passwordHash');
    });

    it.each(LEAKY_FIELDS)('never sends the driver’s %s', async (field) => {
      const result = await service.getOrderDetailsForCustomer(7, CUSTOMER);

      expect(result.acceptedDriver).not.toHaveProperty(field);
    });

    it('still carries the live location the tracking map needs', async () => {
      const result = await service.getOrderDetailsForCustomer(7, CUSTOMER);

      expect(result.acceptedDriver).toMatchObject({
        latitude: 30.7,
        longitude: 30.7,
        rating: 4.9,
      });
    });

    it('does not smuggle the wallet balance in with the location', async () => {
      // The partner row carries `balance`; only the four tracking fields are
      // meant to come across.
      const result = await service.getOrderDetailsForCustomer(7, CUSTOMER);

      expect(result.acceptedDriver).not.toHaveProperty('balance');
    });
  });

  describe('order history', () => {
    it.each(LEAKY_FIELDS)(
      'never sends the driver’s %s in the list either',
      async (field) => {
        const [order] = await service.getCustomerOrders(CUSTOMER.sub);

        expect(order.acceptedDriver).not.toHaveProperty(field);
      },
    );

    it('still names the driver in the list', async () => {
      const [order] = await service.getCustomerOrders(CUSTOMER.sub);

      expect(order.acceptedDriver).toMatchObject({ name: 'كابتن محمد' });
    });
  });

  describe('client-supplied storage paths', () => {
    /**
     * `FilesService.canRead` decides who may read an upload by finding the row
     * that references its path — so naming somebody else's file on your own
     * order *created* permission to read it.
     */
    it('drops a prescription path the caller tried to claim', async () => {
      let saved: Partial<Order> = {};
      const module = await Test.createTestingModule({
        providers: [
          OrdersService,
          {
            provide: getRepositoryToken(Order),
            useValue: {
              create: (d: Partial<Order>) => d,
              save: (d: Partial<Order>) => {
                saved = d;
                return Promise.resolve({ id: 1, ...d });
              },
              findOne: () => Promise.resolve(null),
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
              findOne: () => Promise.resolve({ id: 10, customerZoneId: 1 }),
            },
          },
          { provide: getRepositoryToken(OrderItem), useValue: {} },
          { provide: CatalogService, useValue: {} },
          {
            provide: PricingService,
            useValue: {
              quoteForDestinationZone: () =>
                Promise.resolve({ deliveryFee: 20 }),
              quoteForDistance: () => ({ deliveryFee: 20 }),
            },
          },
          { provide: DeliveryService, useValue: {} },
          { provide: PaymentsService, useValue: {} },
          {
            provide: OrderAssignmentService,
            useValue: {
              openNextWave: jest.fn().mockResolvedValue({ offered: [] }),
            },
          },
          {
            provide: NotificationsService,
            useValue: { notify: jest.fn(), notifyMany: jest.fn() },
          },
        ],
      }).compile();

      const svc = module.get(OrdersService);

      await svc.createOrder(10, {
        customerName: 'أحمد',
        customerPhone: '01000000000',
        categoryType: 'صيدلية',
        itemsDescription: 'دواء',
        deliveryAddressText: 'عنوان',
        latitude: 30.7649,
        longitude: 30.7003,
        // Somebody else's payment proof.
        prescriptionImageUrl: 'uploads/payments/proof-of-another-driver.jpg',
        voiceNoteUrl: 'uploads/chat/someone-elses-voice.m4a',
      });

      // Stored as null rather than the path the caller asked for — the point
      // is that no row now references a file they are not entitled to.
      expect(saved.prescriptionImageUrl).toBeFalsy();
      expect(saved.prescriptionImageUrl).not.toBe(
        'uploads/payments/proof-of-another-driver.jpg',
      );
      expect(saved.voiceNoteUrl).toBeFalsy();
    });
  });
});
