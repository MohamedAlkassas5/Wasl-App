import { BadRequestException } from '@nestjs/common';

import {
  assertDriverEligible,
  checkDriverEligibility,
} from './driver-eligibility';
import { DeliveryVerificationStatus } from './entities/delivery-partner.entity';
import { AccountStatus } from '../users/entities/user.entity';

/**
 * Who is allowed to take work.
 *
 * Approval was recorded in two fields that never agreed: `users.status`, which
 * the admin review wrote, and `delivery_partners.verificationStatus`, which
 * nothing in the application ever wrote or read. The result was that a driver
 * whose documents had never been reviewed could go online, accept an order and
 * have commission charged against their wallet. Both fields must now agree.
 */
describe('driver eligibility', () => {
  const user = (overrides = {}) => ({
    status: AccountStatus.ACTIVE,
    deletedAt: null,
    ...overrides,
  });
  const partner = (overrides = {}) => ({
    verificationStatus: DeliveryVerificationStatus.APPROVED,
    ...overrides,
  });

  it('an approved, active driver may work', () => {
    expect(checkDriverEligibility(user(), partner())).toEqual({
      eligible: true,
      reason: null,
    });
  });

  describe('refusals', () => {
    it('blocks a driver still awaiting review', () => {
      const result = checkDriverEligibility(
        user({ status: AccountStatus.PENDING }),
        partner({ verificationStatus: DeliveryVerificationStatus.PENDING }),
      );
      expect(result.eligible).toBe(false);
      expect(result.reason).toContain('قيد المراجعة');
    });

    it('blocks an active account whose documents are still pending', () => {
      // The exact inconsistency that let unreviewed drivers work: the account
      // says active, the verification says pending.
      expect(
        checkDriverEligibility(
          user(),
          partner({ verificationStatus: DeliveryVerificationStatus.PENDING }),
        ).eligible,
      ).toBe(false);
    });

    it('blocks approved documents on a non-active account', () => {
      expect(
        checkDriverEligibility(
          user({ status: AccountStatus.PENDING }),
          partner(),
        ).eligible,
      ).toBe(false);
    });

    it('blocks a suspended driver', () => {
      const result = checkDriverEligibility(
        user({ status: AccountStatus.SUSPENDED }),
        partner(),
      );
      expect(result.eligible).toBe(false);
      expect(result.reason).toContain('موقوف');
    });

    it('blocks a rejected driver', () => {
      const result = checkDriverEligibility(
        user({ status: AccountStatus.REJECTED }),
        partner({ verificationStatus: DeliveryVerificationStatus.REJECTED }),
      );
      expect(result.eligible).toBe(false);
      expect(result.reason).toContain('رفض');
    });

    it('blocks a closed account', () => {
      const result = checkDriverEligibility(
        user({ deletedAt: new Date() }),
        partner(),
      );
      expect(result.eligible).toBe(false);
      expect(result.reason).toContain('حذف');
    });

    it('blocks when there is no driver profile at all', () => {
      expect(checkDriverEligibility(user(), null).eligible).toBe(false);
      expect(checkDriverEligibility(null, partner()).eligible).toBe(false);
    });
  });

  describe('assert form', () => {
    it('stays silent for an eligible driver', () => {
      expect(() => assertDriverEligible(user(), partner())).not.toThrow();
    });

    it('throws with the driver-facing reason', () => {
      expect(() =>
        assertDriverEligible(
          user({ status: AccountStatus.SUSPENDED }),
          partner(),
        ),
      ).toThrow(BadRequestException);
    });
  });
});
