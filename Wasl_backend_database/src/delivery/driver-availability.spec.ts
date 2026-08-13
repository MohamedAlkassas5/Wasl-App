import { BadRequestException } from '@nestjs/common';

import { OrdersService } from '../orders/orders.service';
import { OrderStatus } from '../orders/entities/order.entity';
import { AccountStatus } from '../users/entities/user.entity';
import { DeliveryVerificationStatus } from './entities/delivery-partner.entity';

/**
 * CP6-B: who may take on new work.
 *
 * Two independent conditions, and the distinction matters — "your papers are
 * not approved" and "top up your wallet" are different problems with different
 * fixes, so they are checked separately and reported separately.
 *
 * The minimum balance gates **new** work only. What it must never do is reach
 * back and disturb an order the driver already accepted; that is
 * `accepted-order-survival.spec.ts`.
 */
describe('driver availability (CP6-B)', () => {
  const MIN_WALLET = 5;

  const approvedUser = {
    id: 20,
    status: AccountStatus.ACTIVE,
    deletedAt: null,
  };
  const approvedPartner = {
    userId: 20,
    verificationStatus: DeliveryVerificationStatus.APPROVED,
    balance: 50,
    isOnline: false,
  };

  function build(
    user: Record<string, unknown> | null,
    partner: Record<string, unknown> | null,
  ) {
    const saved: Record<string, unknown>[] = [];
    const deliveryRepository = {
      findOne: jest.fn().mockResolvedValue(partner),
      save: jest.fn((row: Record<string, unknown>) => {
        saved.push({ ...row });
        return Promise.resolve(row);
      }),
    };
    const userRepository = { findOne: jest.fn().mockResolvedValue(user) };
    const pricingService = { minWalletToGoOnline: () => MIN_WALLET };

    const service = new OrdersService(
      { findOne: jest.fn() } as never, // orders
      {} as never, // offers
      deliveryRepository as never,
      {} as never, // notifications
      userRepository as never,
      {} as never, // order items
      {} as never, // catalog
      pricingService as never,
      {} as never, // delivery
      {} as never, // payments
    );

    return { service, saved, deliveryRepository };
  }

  describe('going online', () => {
    it('allows an approved driver with enough balance', async () => {
      const { service, saved } = build(approvedUser, { ...approvedPartner });

      const result = await service.setDriverOnlineStatus(20, true);

      expect(result.isOnline).toBe(true);
      expect(saved[0].isOnline).toBe(true);
    });

    it('refuses an approved driver below the minimum balance', async () => {
      const { service, saved } = build(approvedUser, {
        ...approvedPartner,
        balance: 4.99,
      });

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
      expect(saved).toHaveLength(0);
    });

    it('allows exactly the minimum — the rule is >=, not >', async () => {
      const { service } = build(approvedUser, {
        ...approvedPartner,
        balance: MIN_WALLET,
      });

      await expect(
        service.setDriverOnlineStatus(20, true),
      ).resolves.toMatchObject({ isOnline: true });
    });

    it('refuses a driver whose documents were never reviewed', async () => {
      const { service } = build(
        { ...approvedUser, status: AccountStatus.PENDING },
        {
          ...approvedPartner,
          verificationStatus: DeliveryVerificationStatus.PENDING,
        },
      );

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('refuses when only one of the two approval flags is set', async () => {
      // The pair used to disagree silently; eligibility now needs both.
      const { service } = build(approvedUser, {
        ...approvedPartner,
        verificationStatus: DeliveryVerificationStatus.PENDING,
      });

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('refuses a suspended driver', async () => {
      const { service } = build(
        { ...approvedUser, status: AccountStatus.SUSPENDED },
        { ...approvedPartner },
      );

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('refuses a rejected driver', async () => {
      const { service } = build(approvedUser, {
        ...approvedPartner,
        verificationStatus: DeliveryVerificationStatus.REJECTED,
      });

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('refuses a deleted account', async () => {
      const { service } = build(
        { ...approvedUser, deletedAt: new Date() },
        { ...approvedPartner },
      );

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('going offline', () => {
    it('is always allowed, even for a driver who is no longer eligible', async () => {
      // Withdrawing approval must never trap someone online receiving work.
      const { service, saved } = build(
        { ...approvedUser, status: AccountStatus.SUSPENDED },
        { ...approvedPartner, isOnline: true, balance: 0 },
      );

      const result = await service.setDriverOnlineStatus(20, false);

      expect(result.isOnline).toBe(false);
      expect(saved[0].isOnline).toBe(false);
    });
  });

  describe('the marketplace', () => {
    it('is hidden from an ineligible driver, who still sees their own work', async () => {
      const assigned = [
        { id: 1, status: OrderStatus.ACCEPTED, acceptedDriverId: 20 },
      ];
      const orderRepository = {
        find: jest
          .fn<Promise<unknown[]>, [{ where: Array<{ status: OrderStatus }> }]>()
          .mockResolvedValue(assigned),
      };
      const service = new OrdersService(
        orderRepository as never,
        {} as never,
        {
          findOne: jest.fn().mockResolvedValue({
            userId: 20,
            verificationStatus: DeliveryVerificationStatus.PENDING,
          }),
        } as never,
        {} as never,
        {
          findOne: jest
            .fn()
            .mockResolvedValue({ id: 20, status: AccountStatus.PENDING }),
        } as never,
        {} as never,
        {} as never,
        { minWalletToGoOnline: () => MIN_WALLET } as never,
        {} as never,
        {} as never,
      );

      const orders = await service.getAvailableOrders(20);

      // Only their assigned work — the where-clause is the four active states,
      // never `pending_offers`.
      expect(orders).toEqual(assigned);
      const where = orderRepository.find.mock.calls[0][0].where;
      expect(
        where.every((clause) => clause.status !== OrderStatus.PENDING_OFFERS),
      ).toBe(true);
    });
  });
});
