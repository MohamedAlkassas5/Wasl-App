import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * CP-E / S10 — a trail for administrator actions.
 *
 * One append-only table. Deliberately **no foreign key** on `admin_id`: the
 * trail has to outlive the actor's account. A FK with any ON DELETE behaviour
 * would either block removing an administrator or erase what they did, and
 * both are worse than an integer that no longer resolves.
 *
 * `payload` is jsonb so entries stay queryable without a column per DTO shape.
 * What goes in it is redacted first — see AdminAuditLogService.
 *
 * Purely additive and fully reversible. Nothing reads this table to make a
 * decision, so an empty one changes no behaviour: every existing route works
 * exactly as before whether or not a row was written.
 */
export class AdminAuditLog1785042700000 implements MigrationInterface {
  name = 'AdminAuditLog1785042700000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "admin_audit_log" (
        "id" SERIAL NOT NULL,
        "admin_id" integer NOT NULL,
        "action" character varying(64) NOT NULL,
        "target_type" character varying(32) NOT NULL,
        "target_id" character varying(128) NOT NULL,
        "payload" jsonb,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_admin_audit_log" PRIMARY KEY ("id")
      )
    `);

    // "What did this administrator do" — the accountability read.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_admin_audit_log_admin"
         ON "admin_audit_log" ("admin_id")`,
    );
    // "Who touched this account / store / setting" — the investigation read.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_admin_audit_log_target"
         ON "admin_audit_log" ("target_type", "target_id")`,
    );
    // The listing is newest-first and paginated; this is the index behind it.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_admin_audit_log_created"
         ON "admin_audit_log" ("created_at")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_admin_audit_log_created"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_admin_audit_log_target"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_admin_audit_log_admin"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "admin_audit_log"`);
  }
}
