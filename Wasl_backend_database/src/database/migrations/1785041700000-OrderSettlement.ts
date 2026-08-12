import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * The order's financial snapshot and the guard that makes settlement happen
 * exactly once.
 *
 * Before this, completing an order recomputed the commission from whatever the
 * settings said at that moment and debited the wallet directly — with no record
 * on the order and no protection against the same completion arriving twice. A
 * double tap charged the driver twice.
 *
 * Two things change that:
 *
 *  1. The order carries its own settled numbers, so an admin editing the
 *     commission percentage tomorrow cannot alter what a driver earned today.
 *  2. `wallet_transactions.reference` is UNIQUE, which makes "charge this
 *     order's commission" a statement the database itself can only accept once.
 *     Two concurrent completions that both pass the in-code checks still
 *     collide there, and the loser's transaction rolls back whole.
 *
 * Hand-written. `migration:generate` was consulted only to confirm the exact
 * constraint name TypeORM derives for the unique (`UQ_wallet_transactions_
 * reference`), which is reproduced verbatim so no future generate renames it.
 * As with the earlier migrations, the pre-existing index/FK drift is left
 * untouched rather than silently "fixed" here.
 */
export class OrderSettlement1785041700000 implements MigrationInterface {
  name = 'OrderSettlement1785041700000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // --- the ledger entry can now name what it settles, and only once ---
    await queryRunner.query(
      `ALTER TABLE "wallet_transactions" ADD COLUMN IF NOT EXISTS "reference" character varying(120)`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_transactions" ADD COLUMN IF NOT EXISTS "order_id" integer`,
    );
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'UQ_wallet_transactions_reference'
        ) THEN
          ALTER TABLE "wallet_transactions"
            ADD CONSTRAINT "UQ_wallet_transactions_reference" UNIQUE ("reference");
        END IF;
      END $$;
    `);

    // --- the order's frozen financial record ---
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "commission_amount" numeric(10,2)`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "driver_share" numeric(10,2)`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "settlement_status" character varying(20) NOT NULL DEFAULT 'pending'`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "settled_at" TIMESTAMP`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "settlement_reference" character varying(120)`,
    );

    // --- when each lifecycle stage actually happened ---
    for (const column of [
      'accepted_at',
      'delivering_at',
      'completed_at',
      'cancelled_at',
    ]) {
      await queryRunner.query(
        `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "${column}" TIMESTAMP`,
      );
    }

    // Orders that completed before settlement existed are marked settled so the
    // new completion path can never charge commission for them a second time.
    // Their commission was already taken by the old code; leaving them
    // 'pending' would invite exactly the double charge this migration prevents.
    await queryRunner.query(`
      UPDATE "orders"
         SET "settlement_status" = 'settled',
             "settled_at" = COALESCE("settled_at", "createdAt"),
             "completed_at" = COALESCE("completed_at", "createdAt")
       WHERE "status" = 'completed' AND "settlement_status" <> 'settled'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const column of [
      'cancelled_at',
      'completed_at',
      'delivering_at',
      'accepted_at',
      'settlement_reference',
      'settled_at',
      'settlement_status',
      'driver_share',
      'commission_amount',
    ]) {
      await queryRunner.query(
        `ALTER TABLE "orders" DROP COLUMN IF EXISTS "${column}"`,
      );
    }
    await queryRunner.query(
      `ALTER TABLE "wallet_transactions" DROP CONSTRAINT IF EXISTS "UQ_wallet_transactions_reference"`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_transactions" DROP COLUMN IF EXISTS "order_id"`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_transactions" DROP COLUMN IF EXISTS "reference"`,
    );
  }
}
