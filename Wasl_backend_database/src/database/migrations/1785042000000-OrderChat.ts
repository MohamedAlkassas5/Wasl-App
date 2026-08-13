import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * CP5 — order chat and the price changes decided inside it.
 *
 * Purely additive: two new tables and their indexes, plus one index on the
 * `notifications` table that has been missing since the start. No column is
 * dropped, no type changes, nothing is backfilled — an existing database keeps
 * every row it had.
 */
export class OrderChat1785042000000 implements MigrationInterface {
  name = 'OrderChat1785042000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 💬 The conversation. Append-only: no UPDATE path in the API except
    // read_at, and no DELETE at all.
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_messages" (
        "id" SERIAL NOT NULL,
        "order_id" integer NOT NULL,
        "sender_id" integer NOT NULL,
        "sender_role" character varying(20) NOT NULL,
        "kind" character varying(24) NOT NULL DEFAULT 'text',
        "body" text,
        "attachment_url" character varying,
        "proposal_id" integer,
        "read_at" TIMESTAMP,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_messages" PRIMARY KEY ("id"),
        CONSTRAINT "FK_order_messages_order" FOREIGN KEY ("order_id")
          REFERENCES "orders"("id") ON DELETE CASCADE
      )
    `);

    // The poll loop's query: everything on this order after id N.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_order_messages_order" ON "order_messages" ("order_id", "created_at")`,
    );
    // The unread badge: this order, not from me, never read.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_order_messages_unread" ON "order_messages" ("order_id", "sender_id", "read_at")`,
    );

    // 💰 Price changes. A table, not a message kind: the approval is a
    // financial transition that has to outlive the conversation UI and be
    // constrained by the database.
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_price_proposals" (
        "id" SERIAL NOT NULL,
        "order_id" integer NOT NULL,
        "proposed_by" integer NOT NULL,
        "old_items_price" numeric(10,2) NOT NULL,
        "new_items_price" numeric(10,2) NOT NULL,
        "reason" character varying(255),
        "status" character varying(16) NOT NULL DEFAULT 'pending',
        "decided_by" integer,
        "decided_at" TIMESTAMP,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_price_proposals" PRIMARY KEY ("id"),
        CONSTRAINT "FK_order_price_proposals_order" FOREIGN KEY ("order_id")
          REFERENCES "orders"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_price_proposals_order" ON "order_price_proposals" ("order_id", "created_at")`,
    );

    // 🔐 At most one open request per order — enforced here rather than only in
    // the service, so two taps racing each other cannot both open one. Decided
    // rows are excluded, so an order may accumulate any number of them over
    // time as long as only one is awaiting an answer.
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "idx_price_proposals_one_open"
         ON "order_price_proposals" ("order_id") WHERE "status" = 'pending'`,
    );

    // 🔔 Pre-existing gap: the notification centre is polled every few seconds
    // per user and this table had no index at all.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_notifications_user_unread" ON "notifications" ("userId", "isRead")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_notifications_user_unread"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_price_proposals_one_open"`,
    );
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_price_proposals_order"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "order_price_proposals"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_order_messages_unread"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_order_messages_order"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "order_messages"`);
  }
}
