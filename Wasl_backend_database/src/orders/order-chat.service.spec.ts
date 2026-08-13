import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';

import { OrderChatService } from './order-chat.service';
import {
  OrderMessage,
  OrderMessageKind,
  OrderMessageSender,
} from './entities/order-message.entity';
import { Order, OrderStatus, OrderType } from './entities/order.entity';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
const DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
const OTHER_DRIVER: AuthUser = { sub: 21, role: UserRole.DELIVERY };
const ADMIN: AuthUser = { sub: 1, role: UserRole.ADMIN };

/** A live order with a driver on it, unless overridden. */
function orderFixture(overrides: Partial<Order> = {}): Order {
  return {
    id: 5,
    customerId: 10,
    acceptedDriverId: 20,
    status: OrderStatus.AT_STORE,
    orderType: OrderType.PHARMACY,
    itemsPrice: 100,
    ...overrides,
  } as Order;
}

function build(order: Order | null) {
  const saved: OrderMessage[] = [];

  const queryBuilder = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue({ affected: 1 }),
    getCount: jest.fn().mockResolvedValue(3),
  };

  const orderRepository = { findOne: jest.fn().mockResolvedValue(order) };
  const messageRepository = {
    find: jest.fn().mockResolvedValue([]),
    create: jest.fn((row: Partial<OrderMessage>) => row as OrderMessage),
    save: jest.fn((row: OrderMessage) => {
      saved.push(row);
      return Promise.resolve({ ...row, id: saved.length });
    }),
    createQueryBuilder: jest.fn(() => queryBuilder),
  };
  const proposalRepository = {
    findOne: jest.fn().mockResolvedValue(null),
    find: jest.fn().mockResolvedValue([]),
    create: jest.fn((row: unknown) => row),
    save: jest.fn((row: unknown) =>
      Promise.resolve({ id: 1, ...(row as object) }),
    ),
  };
  const uploadService = {
    persistImage: jest.fn().mockResolvedValue('uploads/chat/chat-1-abc.jpg'),
  };
  const ordersService = {
    createNotification: jest.fn().mockResolvedValue(undefined),
  };

  const service = new OrderChatService(
    orderRepository as never,
    messageRepository as never,
    proposalRepository as never,
    uploadService as never,
    ordersService as never,
  );

  return {
    service,
    saved,
    queryBuilder,
    orderRepository,
    messageRepository,
    uploadService,
    ordersService,
  };
}

describe('OrderChatService', () => {
  describe('who may read the conversation', () => {
    it('serves the customer and the assigned driver', async () => {
      const { service } = build(orderFixture());
      await expect(
        service.listMessages(5, CUSTOMER, {}),
      ).resolves.toMatchObject({ success: true, orderId: 5 });
      await expect(service.listMessages(5, DRIVER, {})).resolves.toMatchObject({
        success: true,
      });
    });

    it('refuses a driver who is not on this order', async () => {
      const { service } = build(orderFixture());
      await expect(service.listMessages(5, OTHER_DRIVER, {})).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('lets an admin read it — cancellations are arbitrated from this history', async () => {
      const { service } = build(orderFixture());
      await expect(service.listMessages(5, ADMIN, {})).resolves.toMatchObject({
        success: true,
      });
    });

    it('404s an order that does not exist', async () => {
      const { service } = build(null);
      await expect(service.listMessages(5, CUSTOMER, {})).rejects.toThrow(
        NotFoundException,
      );
    });

    it('reports a completed order as closed', async () => {
      const { service } = build(
        orderFixture({ status: OrderStatus.COMPLETED }),
      );
      await expect(
        service.listMessages(5, CUSTOMER, {}),
      ).resolves.toMatchObject({ closed: true });
    });
  });

  describe('sending messages', () => {
    it('stamps the sender role from the token, not from the request', async () => {
      const { service, saved } = build(orderFixture());

      await service.sendText(5, CUSTOMER, { body: 'فين الطلب؟' });
      await service.sendText(5, DRIVER, { body: 'في الطريق' });

      expect(saved[0]).toMatchObject({
        senderId: CUSTOMER.sub,
        senderRole: OrderMessageSender.CUSTOMER,
        kind: OrderMessageKind.TEXT,
      });
      expect(saved[1]).toMatchObject({
        senderId: DRIVER.sub,
        senderRole: OrderMessageSender.DRIVER,
      });
    });

    it('notifies the other party, never the sender', async () => {
      const { service, ordersService } = build(orderFixture());

      await service.sendText(5, CUSTOMER, { body: 'مرحباً' });
      expect(ordersService.createNotification).toHaveBeenCalledWith(
        20,
        expect.stringContaining('رسالة جديدة'),
        expect.stringContaining('FL-5'),
      );
    });

    it('refuses a non-participant', async () => {
      const { service } = build(orderFixture());
      await expect(
        service.sendText(5, OTHER_DRIVER, { body: 'hi' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('lets an admin read but not post', async () => {
      const { service } = build(orderFixture());
      await expect(service.sendText(5, ADMIN, { body: 'hi' })).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('freezes the conversation once the order is completed', async () => {
      const { service } = build(
        orderFixture({ status: OrderStatus.COMPLETED }),
      );
      await expect(
        service.sendText(5, CUSTOMER, { body: 'late' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('freezes the conversation once the order is cancelled', async () => {
      const { service } = build(
        orderFixture({ status: OrderStatus.CANCELLED }),
      );
      await expect(
        service.sendText(5, DRIVER, { body: 'late' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('refuses before a driver has been assigned — there is nobody to talk to', async () => {
      const { service } = build(
        orderFixture({
          acceptedDriverId: undefined,
          status: OrderStatus.PENDING_OFFERS,
        }),
      );
      await expect(
        service.sendText(5, CUSTOMER, { body: 'hello?' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('image messages', () => {
    it('stores the attachment through the storage backend and records its key', async () => {
      const { service, saved, uploadService } = build(orderFixture());
      const file = { buffer: Buffer.from('x') } as Express.Multer.File;

      await service.sendImage(5, DRIVER, file, 'الفاتورة');

      expect(uploadService.persistImage).toHaveBeenCalledWith(
        file,
        'chat',
        'chat',
      );
      expect(saved[0]).toMatchObject({
        kind: OrderMessageKind.IMAGE,
        attachmentUrl: 'uploads/chat/chat-1-abc.jpg',
        body: 'الفاتورة',
      });
    });

    it('rejects a request with no file attached', async () => {
      const { service, uploadService } = build(orderFixture());
      uploadService.persistImage.mockResolvedValue(undefined);

      await expect(service.sendImage(5, DRIVER, undefined)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('checks participation before it stores anything', async () => {
      const { service, uploadService } = build(orderFixture());
      const file = { buffer: Buffer.from('x') } as Express.Multer.File;

      await expect(service.sendImage(5, OTHER_DRIVER, file)).rejects.toThrow(
        ForbiddenException,
      );
      expect(uploadService.persistImage).not.toHaveBeenCalled();
    });
  });

  describe('read state', () => {
    it('counts only what the other party sent', async () => {
      const { service, queryBuilder } = build(orderFixture());

      await expect(service.unreadCount(5, CUSTOMER)).resolves.toMatchObject({
        unread: 3,
      });
      expect(queryBuilder.andWhere).toHaveBeenCalledWith(
        'message.sender_id != :userId',
        { userId: CUSTOMER.sub },
      );
    });

    it('marks the other party’s messages read, never its own', async () => {
      const { service, queryBuilder } = build(orderFixture());

      await service.markRead(5, DRIVER);

      expect(queryBuilder.andWhere).toHaveBeenCalledWith(
        'sender_id != :userId',
        { userId: DRIVER.sub },
      );
      expect(queryBuilder.execute).toHaveBeenCalled();
    });

    it('refuses to count for a non-participant', async () => {
      const { service } = build(orderFixture());
      await expect(service.unreadCount(5, OTHER_DRIVER)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });
});
