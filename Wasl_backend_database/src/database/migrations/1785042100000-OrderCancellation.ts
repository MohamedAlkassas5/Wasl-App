import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * CP6 — cancelling an accepted order, the penalty it charges, and the appeal
 * against that penalty.
 *
 * Additive. One new table, its indexes, and two new values on the existing
 * wallet transaction enum. No column is dropped, no type changed, nothing
 * backfilled.
 *
 * Note on the enum: Postgres allows `ALTER TYPE ... ADD VALUE` inside a
 * transaction from v12 onwards **provided the new value is not used in the same
 * transaction**, which is the case here — this migration only declares the
 * values, the application writes them later. `down()` cannot remove them:
 * Postgres has no `DROP VALUE`. That is harmless, since an unused enum value
 * costs nothing, and it is why the down path drops the table but leaves the
 * type alone.
 */
export class OrderCancellation1785042100000 implements MigrationInterface {
  name = 'OrderCancellation1785042100000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 💸 Two new ledger entry types: the penalty, and an admin's refund of it.
    await queryRunner.query(
      `ALTER TYPE "public"."wallet_transactions_type_enum" ADD VALUE IF NOT EXISTS 'cancellation_penalty'`,
    );
    await queryRunner.query(
      `ALTER TYPE "public"."wallet_transactions_type_enum" ADD VALUE IF NOT EXISTS 'penalty_refund'`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_cancellation_requests" (
        "id" SERIAL NOT NULL,
        "order_id" integer NOT NULL,
        "requested_by" integer NOT NULL,
        "requested_by_role" character varying(12) NOT NULL,
        "reason" text NOT NULL,
        "status" character varying(16) NOT NULL DEFAULT 'pending',
        "decided_by" integer,
        "decided_at" TIMESTAMP,
        "decision_reason" character varying(255),
        "penalty_amount" numeric(10,2),
        "penalty_reference" character varying(120),
        "appeal_status" character varying(16) NOT NULL DEFAULT 'none',
        "appeal_reason" character varying(500),
        "appealed_at" TIMESTAMP,
        "reviewed_by" integer,
        "reviewed_at" TIMESTAMP,
        "review_note" character varying(500),
        "refund_amount" numeric(10,2),
        "refund_reference" character varying(120),
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_cancellation_requests" PRIMARY KEY ("id"),
        CONSTRAINT "FK_order_cancellation_requests_order" FOREIGN KEY ("order_id")
          REFERENCES "orders"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_cancellation_order" ON "order_cancellation_requests" ("order_id", "created_at")`,
    );

    // The admin review queue: appeals waiting on a decision.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_cancellation_appeals" ON "order_cancellation_requests" ("appeal_status", "created_at")`,
    );

    // 🔐 At most one request awaiting an answer per order. Enforced here and not
    // only in the service, so a double tap cannot open two.
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "idx_cancellation_one_open"
         ON "order_cancellation_requests" ("order_id") WHERE "status" = 'pending'`,
    );

    // 🔐 An order can be cancelled once, ever. This is the structural guarantee
    // behind "no duplicate penalty": two concurrent cancellations may both pass
    // every check in code, but only one can land this row.
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "idx_cancellation_one_approved"
         ON "order_cancellation_requests" ("order_id") WHERE "status" = 'approved'`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_cancellation_one_approved"`,
    );
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_cancellation_one_open"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_cancellation_appeals"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_cancellation_order"`);
    await queryRunner.query(
      `DROP TABLE IF EXISTS "order_cancellation_requests"`,
    );
    // The two enum values stay: Postgres cannot drop them, and an unused value
    // is inert.
  }
}
