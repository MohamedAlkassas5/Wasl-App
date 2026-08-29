import { BadRequestException } from '@nestjs/common';

import { PaymentsService } from './payments.service';
import { WalletTxType } from './entities/wallet-transaction.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { OrdersService } from '../orders/orders.service';
import { AccountStatus } from '../users/entities/user.entity';
import { DeliveryVerificationStatus } from '../delivery/entities/delivery-partner.entity';

/**
 * CP-E / S5 — may a driver's wallet go negative? (Q-B2, answered: option A.)
 *
 * Yes, and the debt is carried rather than forgiven. This was previously
 * *unspecified* — the code had no floor and nothing said whether that was
 * intended — which is what these tests exist to end. Both halves are pinned
 * here because either one alone is the wrong policy:
 *
 *   1. The debit goes through even when it crosses zero. It is charged for
 *      work already done; refusing it gives away a delivery, and clamping at
 *      zero forgives the difference while pretending the books balance.
 *
 *   2. A driver below the minimum cannot go online — and a negative balance
 *      always is. That is what turns "negative" into "owes us" instead of
 *      "works for free", and it is the reason (1) is safe.
 *
 * Remove either and the policy is no longer option A.
 */
describe('negative wallet balance (CP-E / S5)', () => {
  // ── half one: the debit is allowed to cross zero ──────────────────────
  describe('the debit', () => {
    const buildManager = (startingBalance: number) => {
      const updates: Record<string, unknown>[] = [];
      const inserts: Record<string, unknown>[] = [];

      const manager = {
        findOne: jest.fn().mockResolvedValue({
          userId: 7,
          balance: startingBalance,
        } as Partial<DeliveryPartner>),
        update: jest.fn((_e: unknown, _w: unknown, patch: Record<string, unknown>) => {
          updates.push(patch);
          return Promise.resolve({});
        }),
        insert: jest.fn((_e: unknown, row: Record<string, unknown>) => {
          inserts.push(row);
          return Promise.resolve({});
        }),
      };

      return { manager, updates, inserts };
    };

    it('lets a commission debit take the balance below zero', async () => {
      const { manager, updates } = buildManager(3);

      const newBalance = await PaymentsService.creditWithin(manager as never, {
        driverId: 7,
        amount: -7,
        type: WalletTxType.COMMISSION,
        note: 'عمولة توصيل',
        reference: 'order-1-commission',
      });

      expect(newBalance).toBe(-4);
      expect(updates[0]).toEqual({ balance: -4 });
    });

    it('lets a cancellation penalty do the same', async () => {
      const { manager, updates } = buildManager(1);

      const newBalance = await PaymentsService.creditWithin(manager as never, {
        driverId: 7,
        amount: -4,
        type: WalletTxType.COMMISSION,
        note: 'غرامة إلغاء',
        reference: 'order-2-cancel-penalty',
      });

      expect(newBalance).toBe(-3);
      expect(updates[0]).toEqual({ balance: -3 });
    });

    it('records the negative balance on the ledger entry', async () => {
      // The ledger is the record of what is owed; a debit that moved the
      // balance to -4 while writing balanceAfter: 0 would be a lie in the
      // one place the platform trusts.
      const { manager, inserts } = buildManager(3);

      await PaymentsService.creditWithin(manager as never, {
        driverId: 7,
        amount: -7,
        type: WalletTxType.COMMISSION,
        note: 'عمولة توصيل',
      });

      expect(inserts[0]).toMatchObject({ amount: -7, balanceAfter: -4 });
    });

    it('a top-up pays the debt down rather than resetting it', async () => {
      const { manager, updates } = buildManager(-4);

      const newBalance = await PaymentsService.creditWithin(manager as never, {
        driverId: 7,
        amount: 10,
        type: WalletTxType.TOPUP,
        note: 'شحن رصيد',
      });

      // 6, not 10 — the debt was real and is settled by the top-up.
      expect(newBalance).toBe(6);
      expect(updates[0]).toEqual({ balance: 6 });
    });

    it('still rounds to two decimals when negative', async () => {
      const { manager } = buildManager(0.1);

      const newBalance = await PaymentsService.creditWithin(manager as never, {
        driverId: 7,
        amount: -0.3,
        type: WalletTxType.COMMISSION,
        note: 'عمولة',
      });

      expect(newBalance).toBe(-0.2);
    });
  });

  // ── half two: a negative balance cannot take new work ─────────────────
  describe('the consequence', () => {
    const MIN_WALLET = 5;

    const activeUser = { id: 20, status: AccountStatus.ACTIVE, deletedAt: null };

    const build = (balance: number) => {
      const saved: Record<string, unknown>[] = [];
      const deliveryRepository = {
        findOne: jest.fn().mockResolvedValue({
          userId: 20,
          verificationStatus: DeliveryVerificationStatus.APPROVED,
          balance,
          isOnline: false,
        }),
        save: jest.fn((row: Record<string, unknown>) => {
          saved.push({ ...row });
          return Promise.resolve(row);
        }),
      };

      const service = new OrdersService(
        { findOne: jest.fn() } as never,
        deliveryRepository as never,
        {} as never,
        { findOne: jest.fn().mockResolvedValue(activeUser) } as never,
        {} as never,
        {} as never,
        { minWalletToGoOnline: () => MIN_WALLET } as never,
        {} as never,
        {} as never,
        { liveOffersFor: jest.fn().mockResolvedValue([]) } as never,
        { notify: jest.fn(), notifyMany: jest.fn() } as never,
      );

      return { service, saved };
    };

    it('refuses to bring a driver in debt online', async () => {
      const { service, saved } = build(-4);

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
      expect(saved).toHaveLength(0);
    });

    it('still refuses at exactly -0.01 — any debt is below the minimum', async () => {
      const { service } = build(-0.01);

      await expect(service.setDriverOnlineStatus(20, true)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('lets a driver in debt go OFFLINE', async () => {
      // Going offline must never be gated on balance. A driver who owes money
      // and cannot stop receiving work is the worst version of this policy.
      const { service, saved } = build(-4);

      await expect(
        service.setDriverOnlineStatus(20, false),
      ).resolves.toMatchObject({ isOnline: false });
      expect(saved[0].isOnline).toBe(false);
    });

    it('lets them back online once a top-up clears the debt', async () => {
      const { service } = build(MIN_WALLET);

      await expect(
        service.setDriverOnlineStatus(20, true),
      ).resolves.toMatchObject({ isOnline: true });
    });
  });
});
