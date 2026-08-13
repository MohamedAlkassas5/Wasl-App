import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * CP6-D — whether a store is open for business right now.
 *
 * One column. `merchants.status` already says whether the platform admits the
 * store at all; it does not say whether the kitchen is on. Overloading it would
 * have made closing for the night indistinguishable from being suspended for
 * misconduct, and re-opening would have needed an admin approval review.
 *
 * Defaults to true so every existing merchant stays exactly as it is: approved
 * stores keep trading, and nothing about an order already placed changes.
 * Additive and fully reversible.
 */
export class MerchantAvailability1785042500000 implements MigrationInterface {
  name = 'MerchantAvailability1785042500000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "merchants"
         ADD COLUMN IF NOT EXISTS "is_accepting_orders" boolean NOT NULL DEFAULT true`,
    );

    // The customer-facing list filters on approval and reads this alongside it.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_merchants_open"
         ON "merchants" ("status", "is_accepting_orders")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_merchants_open"`);
    await queryRunner.query(
      `ALTER TABLE "merchants" DROP COLUMN IF EXISTS "is_accepting_orders"`,
    );
  }
}
