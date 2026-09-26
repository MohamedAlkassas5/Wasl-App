import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Driver ↔ admin support chat.
 *
 * Purely additive: two new tables and their indexes. Nothing existing is
 * dropped, altered or backfilled, so an existing database keeps every row it
 * had and the order chat is untouched.
 *
 * The two tables are deliberately separate from `order_messages`: support has
 * no order to hang on, and an account conversation must not land inside a
 * record the customer on some delivery can read.
 */
export class DriverSupportChat1785042800000 implements MigrationInterface {
  name = 'DriverSupportChat1785042800000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 🎫 One thread per user — enforced by the unique index below, not by the
    // service, so a race between two first messages cannot create two threads.
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "support_conversations" (
        "id" SERIAL NOT NULL,
        "user_id" integer NOT NULL,
        "status" character varying(16) NOT NULL DEFAULT 'open',
        "last_message_at" TIMESTAMP,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_support_conversations" PRIMARY KEY ("id"),
        CONSTRAINT "FK_support_conversations_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "idx_support_conversations_user" ON "support_conversations" ("user_id")`,
    );
    // The admin inbox: most recently active first.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_support_conversations_recent" ON "support_conversations" ("last_message_at")`,
    );

    // 💬 Append-only. The only UPDATE the API performs is on read_at.
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "support_messages" (
        "id" SERIAL NOT NULL,
        "conversation_id" integer NOT NULL,
        "sender_id" integer NOT NULL,
        "sender_role" character varying(16) NOT NULL,
        "kind" character varying(16) NOT NULL DEFAULT 'text',
        "body" text,
        "attachment_url" character varying,
        "read_at" TIMESTAMP,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_support_messages" PRIMARY KEY ("id"),
        CONSTRAINT "FK_support_messages_conversation" FOREIGN KEY ("conversation_id")
          REFERENCES "support_conversations"("id") ON DELETE CASCADE
      )
    `);

    // The poll loop: everything in this thread after id N.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_support_messages_conversation" ON "support_messages" ("conversation_id", "created_at")`,
    );
    // The unread badge on both sides: this thread, from the other side, unread.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_support_messages_unread" ON "support_messages" ("conversation_id", "sender_role", "read_at")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Messages first — they reference the conversation.
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_support_messages_unread"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_support_messages_conversation"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "support_messages"`);

    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_support_conversations_recent"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_support_conversations_user"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "support_conversations"`);
  }
}
