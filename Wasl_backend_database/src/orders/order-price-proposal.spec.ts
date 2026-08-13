import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';

import { OrderChatService } from './order-chat.service';
import { Order, OrderStatus, OrderType } from './entities/order.entity';
import {
  OrderPriceProposal,
  PriceProposalStatus,
} from './entities/order-price-proposal.entity';
import { OrderMessageKind } from './entities/order-message.entity';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
const DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };

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

/**
 * @param existing the proposal the transaction will find, if any
 */
function build(
  order: Order | null,
  existing: OrderPriceProposal | null = null,
) {
  const orderUpdates: Record<string, unknown>[] = [];
  const proposalUpdates: Record<string, unknown>[] = [];
  const messages: Record<string, unknown>[] = [];

  const manager = {
    findOne: jest.fn().mockResolvedValue(existing),
    update: jest.fn((entity: unknown, _where: unknown, patch: object) => {
      if (entity === Order) orderUpdates.push(patch as Record<string, unknown>);
      else proposalUpdates.push(patch as Record<string, unknown>);
      return Promise.resolve({ affected: 1 });
    }),
  };

  const orderRepository = { findOne: jest.fn().mockResolvedValue(order) };
  const messageRepository = {
    find: jest.fn().mockResolvedValue([]),
    create: jest.fn((row: unknown) => row),
    save: jest.fn((row: Record<string, unknown>) => {
      messages.push(row);
      return Promise.resolve({ id: messages.length, ...row });
    }),
    createQueryBuilder: jest.fn(),
  };
  const proposalRepository = {
    findOne: jest.fn().mockResolvedValue(null),
    find: jest.fn().mockResolvedValue([]),
    create: jest.fn((row: unknown) => row),
    save: jest.fn((row: object) => Promise.resolve({ id: 77, ...row })),
    manager: {
      transaction: jest.fn((cb: (m: typeof manager) => Promise<unknown>) =>
        cb(manager),
      ),
    },
  };
  const uploadService = { persistImage: jest.fn() };
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
    manager,
    orderUpdates,
    proposalUpdates,
    messages,
    proposalRepository,
    ordersService,
  };
}

/**
 * The rule these pin: a driver may *ask* to change the purchase price, and only
 * the customer's explicit approval moves it. Before this, the driver wrote the
 * number straight onto the order and the customer found out at the door.
 */
describe('order price proposals', () => {
  describe('creating one', () => {
    it('is refused for the customer — only the driver proposes', async () => {
      const { service } = build(orderFixture());
      await expect(
        service.createProposal(5, CUSTOMER, { newItemsPrice: 150 }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('records the old price alongside the new one', async () => {
      const { service, proposalRepository } = build(orderFixture());

      await service.createProposal(5, DRIVER, {
        newItemsPrice: 150,
        reason: 'الدواء أغلى',
      });

      expect(proposalRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          orderId: 5,
          proposedBy: DRIVER.sub,
          oldItemsPrice: 100,
          newItemsPrice: 150,
          status: PriceProposalStatus.PENDING,
        }),
      );
    });

    it('posts it into the conversation as a typed message, not prose', async () => {
      const { service, messages } = build(orderFixture());

      await service.createProposal(5, DRIVER, { newItemsPrice: 150 });

      expect(messages[0]).toMatchObject({
        kind: OrderMessageKind.PRICE_PROPOSAL,
        proposalId: 77,
      });
    });

    it('notifies the customer that a decision is waiting', async () => {
      const { service, ordersService } = build(orderFixture());

      await service.createProposal(5, DRIVER, { newItemsPrice: 150 });

      expect(ordersService.createNotification).toHaveBeenCalledWith(
        10,
        expect.stringContaining('تعديل سعر'),
        expect.stringContaining('FL-5'),
      );
    });

    it('refuses a second open request while one is still pending', async () => {
      const { service, proposalRepository } = build(orderFixture());
      proposalRepository.findOne.mockResolvedValue({
        id: 1,
        status: PriceProposalStatus.PENDING,
      });

      await expect(
        service.createProposal(5, DRIVER, { newItemsPrice: 150 }),
      ).rejects.toThrow(ConflictException);
    });

    it('turns a lost race on the unique index into the same conflict', async () => {
      const { service, proposalRepository } = build(orderFixture());
      proposalRepository.save.mockRejectedValue(new Error('duplicate key'));

      await expect(
        service.createProposal(5, DRIVER, { newItemsPrice: 150 }),
      ).rejects.toThrow(ConflictException);
    });

    it('refuses a price identical to the current one', async () => {
      const { service } = build(orderFixture());
      await expect(
        service.createProposal(5, DRIVER, { newItemsPrice: 100 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('refuses on a Waslly run — nothing is bought on one', async () => {
      const { service } = build(orderFixture({ orderType: OrderType.WASLLY }));
      await expect(
        service.createProposal(5, DRIVER, { newItemsPrice: 150 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('refuses once the driver has left the shop', async () => {
      const { service } = build(
        orderFixture({ status: OrderStatus.DELIVERING }),
      );
      await expect(
        service.createProposal(5, DRIVER, { newItemsPrice: 150 }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('deciding one', () => {
    // A factory, not a shared object: deciding one mutates it, and a fixture
    // carried between tests would arrive already answered.
    const pending = () =>
      ({
        id: 77,
        orderId: 5,
        status: PriceProposalStatus.PENDING,
        oldItemsPrice: 100,
        newItemsPrice: 150,
      }) as OrderPriceProposal;

    it('writes the new price onto the order when the customer approves', async () => {
      const { service, orderUpdates, proposalUpdates } = build(
        orderFixture(),
        pending(),
      );

      await service.decideProposal(5, 77, CUSTOMER, true);

      expect(orderUpdates).toEqual([{ itemsPrice: 150 }]);
      expect(proposalUpdates[0]).toMatchObject({
        status: PriceProposalStatus.APPROVED,
        decidedBy: CUSTOMER.sub,
      });
    });

    it('leaves the order completely untouched when the customer rejects', async () => {
      const { service, orderUpdates, proposalUpdates } = build(
        orderFixture(),
        pending(),
      );

      await service.decideProposal(5, 77, CUSTOMER, false);

      // No price change, no cancellation, no money moved. What follows is the
      // driver's own decision to cancel, and then an admin's review.
      expect(orderUpdates).toEqual([]);
      expect(proposalUpdates[0]).toMatchObject({
        status: PriceProposalStatus.REJECTED,
      });
    });

    it('refuses to let the driver approve their own request', async () => {
      const { service, orderUpdates } = build(orderFixture(), pending());

      await expect(service.decideProposal(5, 77, DRIVER, true)).rejects.toThrow(
        ForbiddenException,
      );
      expect(orderUpdates).toEqual([]);
    });

    it('is idempotent: approving twice does not write the price twice', async () => {
      const approved = {
        ...pending(),
        status: PriceProposalStatus.APPROVED,
      } as OrderPriceProposal;
      const { service, orderUpdates, messages } = build(
        orderFixture(),
        approved,
      );

      const result = await service.decideProposal(5, 77, CUSTOMER, true);

      expect(result.success).toBe(true);
      expect(orderUpdates).toEqual([]);
      expect(messages).toEqual([]);
    });

    it('refuses to flip a decision that was already made', async () => {
      const approved = {
        ...pending(),
        status: PriceProposalStatus.APPROVED,
      } as OrderPriceProposal;
      const { service } = build(orderFixture(), approved);

      await expect(
        service.decideProposal(5, 77, CUSTOMER, false),
      ).rejects.toThrow(ConflictException);
    });

    it('refuses a proposal id belonging to a different order', async () => {
      const foreign = { ...pending(), orderId: 999 };
      const { service } = build(orderFixture(), foreign);

      await expect(
        service.decideProposal(5, 77, CUSTOMER, true),
      ).rejects.toThrow(NotFoundException);
    });

    it('tells the driver either way', async () => {
      const { service, ordersService } = build(orderFixture(), pending());

      await service.decideProposal(5, 77, CUSTOMER, false);

      expect(ordersService.createNotification).toHaveBeenCalledWith(
        20,
        expect.stringContaining('رفض'),
        expect.stringContaining('FL-5'),
      );
    });

    it('records the decision in the conversation', async () => {
      const { service, messages } = build(orderFixture(), pending());

      await service.decideProposal(5, 77, CUSTOMER, true);

      expect(messages[0]).toMatchObject({
        kind: OrderMessageKind.PRICE_DECISION,
        proposalId: 77,
      });
    });
  });
});
