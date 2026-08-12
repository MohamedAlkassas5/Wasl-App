import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Marks an account as closed by its owner.
 *
 * "Delete my account" could not work before this: `orders.customerId` is
 * `ON DELETE NO ACTION`, so removing a customer who had ever ordered failed
 * with a foreign-key violation (23503) and the user was shown a generic error.
 *
 * Hard-deleting the orders instead is not an option — an order carries the
 * assigned driver's completed-delivery record and the commission charged
 * against their wallet. That is a second person's financial history, and the
 * customer closing their own account has no business erasing it.
 *
 * So closure anonymises: personal data is scrubbed, the phone number is
 * released for re-registration, and `deleted_at` records when it happened.
 *
 * A dedicated column rather than a new `AccountStatus` value, deliberately:
 * `suspended` means "an administrator blocked this account" and reusing it
 * would make a self-closed account indistinguishable from a banned one in the
 * admin panel. It is nullable and additive, so no existing row changes.
 */
export class AccountDeletion1785041600000 implements MigrationInterface {
  name = 'AccountDeletion1785041600000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "deleted_at"`,
    );
  }
}
