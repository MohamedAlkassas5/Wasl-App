import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Reconciles the two places a driver's approval was recorded.
 *
 * `users.status` is what the admin review actually wrote and what login
 * checked. `delivery_partners.verificationStatus` was declared, defaulted to
 * `pending`, and then never written by any application code — only the local
 * dev seed ever set it. It has been a dead column since it was added.
 *
 * Checkpoint 3 makes driver eligibility depend on both, and makes the admin
 * review write both. That leaves one problem: every driver an admin already
 * approved has `users.status = 'active'` but `verificationStatus = 'pending'`,
 * so switching the gate on without this would lock out every working driver on
 * the platform.
 *
 * A driver only reaches `active` by an admin approving them — registration
 * puts delivery accounts in `pending` — so promoting exactly those rows is
 * restating a decision that was already made, not inventing one.
 *
 * Deliberately narrow: rows that are still `pending` or were `rejected` stay
 * as they are.
 */
export class DriverApprovalBackfill1785041800000 implements MigrationInterface {
  name = 'DriverApprovalBackfill1785041800000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      UPDATE "delivery_partners" dp
         SET "verificationStatus" = 'approved'
        FROM "users" u
       WHERE u."id" = dp."user_id"
         AND u."role" = 'delivery'
         AND u."status" = 'active'
         AND dp."verificationStatus" = 'pending'
    `);

    // Same reconciliation for merchants: StoresService only lists APPROVED
    // merchants, so an admin-approved store was never actually appearing.
    await queryRunner.query(`
      UPDATE "merchants" m
         SET "status" = 'approved'
        FROM "users" u
       WHERE u."id" = m."owner_id"
         AND u."role" = 'merchant'
         AND u."status" = 'active'
         AND m."status" = 'pending'
    `);
  }

  public async down(): Promise<void> {
    // Intentionally not reversible. This restates an approval decision an
    // administrator already made; reverting it would un-approve live drivers
    // and merchants for no reason, and the original `pending` values carried
    // no information — they were simply never written.
  }
}
