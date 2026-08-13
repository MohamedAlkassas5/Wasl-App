import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * CP6-B — targeted driver assignment.
 *
 * Four things, all additive:
 *
 *  1. `order_assignments` — which drivers were offered which order, in which
 *     wave, at what radius, and how they answered.
 *  2. `orders.assignment_wave` — how many waves have gone out on an order.
 *  3. `expired` on the order status enum, for an order no captain took.
 *  4. A partial unique index on `orders (accepted_driver_id)` restricted to the
 *     four active statuses. That is the one-active-order-per-driver rule, made
 *     structural.
 *
 * The fourth is the important one. The service checks capacity under a row lock,
 * but two acceptances on *different* orders lock different rows and so cannot
 * see each other — only the database can refuse that pair, and this index is
 * how. Same discipline as `wallet_transactions.reference`: the guarantee lives
 * in Postgres, and the code merely turns the resulting error into a sentence.
 *
 * Note on the enum: `ALTER TYPE ... ADD VALUE` is allowed inside a transaction
 * from Postgres 12 on, provided the new value is not *used* in the same
 * transaction. It is not — the index predicate below names only the four
 * pre-existing active statuses. `down()` cannot remove an enum value (Postgres
 * has no `DROP VALUE`), which is harmless: an unused label costs nothing.
 *
 * If any driver somehow already holds two active orders, creating the unique
 * index fails and this migration rolls back rather than silently picking a
 * winner. That is deliberate — data that violates the rule is a thing to look
 * at, not to paper over.
 */
export class OrderAssignments1785042300000 implements MigrationInterface {
  name = 'OrderAssignments1785042300000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."orders_status_enum" ADD VALUE IF NOT EXISTS 'expired'`,
    );

    // How many waves have gone out on an order. On the order rather than
    // counted from `order_assignments`, because a wave that reaches nobody
    // writes no rows there — see the note on `Order.assignmentWave`.
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "assignment_wave" integer NOT NULL DEFAULT 0`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_assignments" (
        "id" SERIAL NOT NULL,
        "order_id" integer NOT NULL,
        "driver_id" integer NOT NULL,
        "wave_number" integer NOT NULL DEFAULT 1,
        "radius_km" double precision,
        "distance_km" double precision,
        "status" character varying(16) NOT NULL DEFAULT 'offered',
        "offered_at" TIMESTAMP NOT NULL DEFAULT now(),
        "expires_at" TIMESTAMP NOT NULL,
        "responded_at" TIMESTAMP,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_assignments" PRIMARY KEY ("id"),
        CONSTRAINT "FK_order_assignments_order" FOREIGN KEY ("order_id")
          REFERENCES "orders"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_order_assignments_driver" FOREIGN KEY ("driver_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    // 🔐 A driver is asked about a given order at most once, however many waves
    // run. Without this a widening radius would re-offer the same order to
    // someone who already declined it.
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "idx_assignments_order_driver"
         ON "order_assignments" ("order_id", "driver_id")`,
    );

    // The driver's own inbox, and the candidate filter.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_assignments_driver_status"
         ON "order_assignments" ("driver_id", "status")`,
    );

    // The sweep: live offers past their deadline.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_assignments_status_expiry"
         ON "order_assignments" ("status", "expires_at")`,
    );

    // 🚚 One active order per driver, enforced by the database.
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "idx_orders_one_active_per_driver"
         ON "orders" ("acceptedDriverId")
         WHERE "status" IN ('accepted', 'at_store', 'items_bought', 'delivering')`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_orders_one_active_per_driver"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_assignments_status_expiry"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_assignments_driver_status"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_assignments_order_driver"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "order_assignments"`);
    await queryRunner.query(
      `ALTER TABLE "orders" DROP COLUMN IF EXISTS "assignment_wave"`,
    );
    // 'expired' stays on the enum: Postgres cannot drop a value, and an unused
    // one is inert.
  }
}
