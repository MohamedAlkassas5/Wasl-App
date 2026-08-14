import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Q-A3 — refresh tokens, so the access token can stop being a month long.
 *
 * One table. It stores a SHA-256 of each token and never the token itself, so
 * a dump of this is not a set of working credentials.
 *
 * `family_id` groups every token descended from one sign-in, which is what
 * makes reuse detection possible: presenting a token that was already spent
 * revokes the family rather than the single row, because whoever replayed it
 * may already hold the token that replaced it.
 *
 * Additive and reversible. Nothing existing depends on it — accounts signed in
 * before this simply hold an access token that expires normally and then sign
 * in again, which is the same thing that happens to any expired session.
 */
export class RefreshTokens1785042600000 implements MigrationInterface {
  name = 'RefreshTokens1785042600000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "refresh_tokens" (
        "id" SERIAL NOT NULL,
        "user_id" integer NOT NULL,
        "token_hash" character varying(64) NOT NULL,
        "family_id" character varying(36) NOT NULL,
        "used_at" TIMESTAMP,
        "revoked_at" TIMESTAMP,
        "expires_at" TIMESTAMP NOT NULL,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_refresh_tokens" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_refresh_tokens_hash" UNIQUE ("token_hash"),
        CONSTRAINT "FK_refresh_tokens_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    // Revoking every session a user has, on account closure.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_refresh_tokens_user"
         ON "refresh_tokens" ("user_id")`,
    );

    // Revoking a whole family the moment a spent token is replayed.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_refresh_tokens_family"
         ON "refresh_tokens" ("family_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_refresh_tokens_family"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_refresh_tokens_user"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "refresh_tokens"`);
  }
}
