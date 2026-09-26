import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';

import { FilesService } from './files.service';
import { SupportService } from '../support/support.service';
import { STORAGE_PROVIDER } from '../storage/storage-provider';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { Order, OrderStatus, OrderType } from '../orders/entities/order.entity';
import { OrderMessage } from '../orders/entities/order-message.entity';
import { OrderAssignment } from '../orders/entities/order-assignment.entity';
import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
const ASSIGNED_DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
const BROWSING_DRIVER: AuthUser = { sub: 21, role: UserRole.DELIVERY };

const CHAT_FILE = 'uploads/chat/chat-1-abc.jpg';
const PHARMACY_PHOTO = 'uploads/orders/order-2-def.jpg';
const PRESCRIPTION = 'uploads/orders/order-3-ghi.jpg';
const STORE_PHOTO = 'uploads/orders/order-4-jkl.jpg';

const PHARMACY_ORDER_ID = 2;
const STORE_ORDER_ID = 4;

/** Which orders the browsing driver has actually been offered. */
const offeredOrderIds = new Set<number>();

/**
 * Reading an attachment is a second authorization decision, not a consequence
 * of having been told the URL. These cover the two file classes CP5 touches:
 * chat attachments, and the pharmacy photos that turned out to be readable by
 * every online driver.
 */
describe('FilesService — chat attachments and prescriptions', () => {
  let service: FilesService;

  /** Orders keyed by whichever image column the lookup is filtering on. */
  const orders: Record<string, Partial<Order>> = {
    [PHARMACY_PHOTO]: {
      id: 2,
      customerId: 10,
      acceptedDriverId: undefined,
      status: OrderStatus.PENDING_OFFERS,
      orderType: OrderType.PHARMACY,
    },
    [STORE_PHOTO]: {
      id: 4,
      customerId: 10,
      acceptedDriverId: undefined,
      status: OrderStatus.PENDING_OFFERS,
      orderType: OrderType.STORE,
    },
    [PRESCRIPTION]: {
      id: 3,
      customerId: 10,
      acceptedDriverId: 20,
      status: OrderStatus.AT_STORE,
      orderType: OrderType.PHARMACY,
    },
  };

  const chatOrder: Partial<Order> = {
    id: 1,
    customerId: 10,
    acceptedDriverId: 20,
  };

  beforeAll(async () => {
    const orderRepo = {
      findOne: ({ where }: { where: Record<string, unknown> }) => {
        if (where.itemsImageUrl) {
          const found = orders[where.itemsImageUrl as string];
          return Promise.resolve(found && found.id !== 3 ? found : null);
        }
        if (where.prescriptionImageUrl) {
          return Promise.resolve(
            where.prescriptionImageUrl === PRESCRIPTION
              ? orders[PRESCRIPTION]
              : null,
          );
        }
        if (where.id === 1) return Promise.resolve(chatOrder);
        return Promise.resolve(null);
      },
    };

    const messageRepo = {
      findOne: ({ where }: { where: { attachmentUrl: string } }) =>
        Promise.resolve(
          where.attachmentUrl === CHAT_FILE
            ? { id: 1, orderId: 1, attachmentUrl: CHAT_FILE }
            : null,
        ),
    };
    const emptyRepo = { findOne: () => Promise.resolve(null) };

    const moduleRef = await Test.createTestingModule({
      providers: [
        FilesService,
        { provide: STORAGE_PROVIDER, useValue: {} },
        { provide: getRepositoryToken(DeliveryPartner), useValue: emptyRepo },
        { provide: getRepositoryToken(Merchant), useValue: emptyRepo },
        { provide: getRepositoryToken(Order), useValue: orderRepo },
        {
          provide: getRepositoryToken(WalletTopUpRequest),
          useValue: emptyRepo,
        },
        { provide: getRepositoryToken(OrderMessage), useValue: messageRepo },
        {
          provide: getRepositoryToken(OrderAssignment),
          useValue: {
            findOne: ({ where }: { where: { orderId: number } }) =>
              Promise.resolve(
                offeredOrderIds.has(where.orderId) ? { id: 1 } : null,
              ),
          },
        },
        // Support attachments are a different feature with its own spec; here
        // the rule simply never matches, so these cases are unaffected by it.
        {
          provide: SupportService,
          useValue: { canReadAttachment: () => Promise.resolve(false) },
        },
      ],
    }).compile();

    service = moduleRef.get(FilesService);
  });

  // The module is built once, so the offer set has to be reset per test rather
  // than leaking whichever order the previous one granted.
  beforeEach(() => offeredOrderIds.clear());

  describe('chat attachments', () => {
    it('serves them to the customer on that order', async () => {
      await expect(service.canRead(CUSTOMER, CHAT_FILE)).resolves.toBe(true);
    });

    it('serves them to the assigned driver', async () => {
      await expect(service.canRead(ASSIGNED_DRIVER, CHAT_FILE)).resolves.toBe(
        true,
      );
    });

    it('refuses a driver who is not on that order', async () => {
      await expect(service.canRead(BROWSING_DRIVER, CHAT_FILE)).resolves.toBe(
        false,
      );
    });

    it('refuses an attachment no message references', async () => {
      await expect(
        service.canRead(CUSTOMER, 'uploads/chat/chat-nobody.jpg'),
      ).resolves.toBe(false);
    });
  });

  describe('pharmacy photos', () => {
    it('does not hand a pending pharmacy photo to every online driver', async () => {
      // This is the leak: the pharmacy screen sends the prescription through
      // itemsImage, and "any driver may see a pending order's photo" made every
      // customer's prescription readable by anyone with a driver account.
      await expect(
        service.canRead(BROWSING_DRIVER, PHARMACY_PHOTO),
      ).resolves.toBe(false);
    });

    it('shows a pending non-pharmacy photo to a driver who was offered it', async () => {
      // CP6-E narrowed this. It used to be "any driver at all", which was right
      // while every pending order was visible to everyone; CP6-B replaced that
      // with targeted offers, so being asked is now what earns the look.
      offeredOrderIds.add(STORE_ORDER_ID);

      await expect(service.canRead(BROWSING_DRIVER, STORE_PHOTO)).resolves.toBe(
        true,
      );
    });

    it('refuses a driver who was never offered that order', async () => {
      // Regression guard for the CP6-E narrowing: with the open marketplace
      // gone, an unasked driver is a stranger to this order.
      offeredOrderIds.clear();

      await expect(service.canRead(BROWSING_DRIVER, STORE_PHOTO)).resolves.toBe(
        false,
      );
    });

    it('still refuses a pharmacy photo even to a driver who was offered it', async () => {
      // Choosing whether to take a pharmacy run needs the medicine list, which
      // is text on the order — never the scan.
      offeredOrderIds.add(PHARMACY_ORDER_ID);

      await expect(
        service.canRead(BROWSING_DRIVER, PHARMACY_PHOTO),
      ).resolves.toBe(false);
    });

    it('still shows the pharmacy photo to its own customer', async () => {
      await expect(service.canRead(CUSTOMER, PHARMACY_PHOTO)).resolves.toBe(
        true,
      );
    });

    it('serves a prescription in its own column to the two parties only', async () => {
      await expect(service.canRead(CUSTOMER, PRESCRIPTION)).resolves.toBe(true);
      await expect(
        service.canRead(ASSIGNED_DRIVER, PRESCRIPTION),
      ).resolves.toBe(true);
      await expect(
        service.canRead(BROWSING_DRIVER, PRESCRIPTION),
      ).resolves.toBe(false);
    });
  });
});
