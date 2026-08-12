import { BadRequestException } from '@nestjs/common';
import {
  DeliveryPartner,
  DeliveryVerificationStatus,
} from './entities/delivery-partner.entity';
import { AccountStatus, User } from '../users/entities/user.entity';

/**
 * Whether a driver may take on new work.
 *
 * Approval used to be recorded in two places that never agreed:
 * `users.status`, which the admin review wrote and login checked, and
 * `delivery_partners.verificationStatus`, which was declared, defaulted to
 * `pending`, and then written by nothing but the dev seed. Because nothing
 * read the second one either, a driver whose documents had never been reviewed
 * could go online, accept orders and have commission charged against their
 * wallet.
 *
 * Both now have to agree, and the admin review writes both. Keeping this in
 * one function is the point: acceptance, going online and every driver-only
 * transition ask the same question and get the same answer.
 *
 * The minimum-balance rule lives elsewhere on purpose. Being *eligible* is
 * about identity and approval; having enough balance is a separate,
 * momentary condition, and conflating them would make "your papers aren't
 * approved" and "top up your wallet" the same error.
 */
export interface EligibilityResult {
  eligible: boolean;
  /** Why not, phrased for the driver. Null when eligible. */
  reason: string | null;
}

export function checkDriverEligibility(
  user: Pick<User, 'status' | 'deletedAt'> | null,
  partner: Pick<DeliveryPartner, 'verificationStatus'> | null,
): EligibilityResult {
  if (!user || !partner) {
    return { eligible: false, reason: 'حساب الكابتن غير موجود' };
  }

  if (user.deletedAt) {
    return { eligible: false, reason: 'تم حذف هذا الحساب' };
  }

  if (user.status === AccountStatus.SUSPENDED) {
    return {
      eligible: false,
      reason: 'حسابك موقوف حالياً، يرجى مراجعة الإدارة',
    };
  }

  if (
    partner.verificationStatus === DeliveryVerificationStatus.REJECTED ||
    user.status === AccountStatus.REJECTED
  ) {
    return {
      eligible: false,
      reason: 'تم رفض طلب انضمامك، يرجى مراجعة الإدارة',
    };
  }

  if (
    user.status !== AccountStatus.ACTIVE ||
    partner.verificationStatus !== DeliveryVerificationStatus.APPROVED
  ) {
    return {
      eligible: false,
      reason: 'حسابك قيد المراجعة، لا يمكنك استقبال الطلبات قبل الاعتماد',
    };
  }

  return { eligible: true, reason: null };
}

/** Throwing form, for the paths that simply need the driver to be allowed. */
export function assertDriverEligible(
  user: Pick<User, 'status' | 'deletedAt'> | null,
  partner: Pick<DeliveryPartner, 'verificationStatus'> | null,
): void {
  const { eligible, reason } = checkDriverEligibility(user, partner);
  if (!eligible) {
    throw new BadRequestException(
      reason ?? 'الكابتن غير مؤهل لاستقبال الطلبات',
    );
  }
}
