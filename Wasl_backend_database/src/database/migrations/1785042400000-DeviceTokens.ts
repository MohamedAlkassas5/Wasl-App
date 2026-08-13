import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * CP6-C — push notification destinations.
 *
 * One table. `token` is UNIQUE rather than the (user, token) pair: a token
 * identifies a *device*, and a device has one signed-in user at a time. FCM
 * hands back the same token when a second driver signs in on a phone their
 * colleague used yesterday, so registering it has to move ownership. Keyed on
 * the pair, the old row would survive and that colleague would keep receiving
 * offers meant for someone else.
 *
 * Additive and fully reversible: nothing else is touched, and no existing
 * notification behaviour depends on it — a user with no registered device
 * simply gets the in-app row and no push, which is exactly the state every
 * account is in before the app ships with FCM wired.
 */
export class DeviceTokens1785042400000 implements MigrationInterface {
  name = 'DeviceTokens1785042400000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "device_tokens" (
        "id" SERIAL NOT NULL,
        "user_id" integer NOT NULL,
        "token" character varying(512) NOT NULL,
        "platform" character varying(16) NOT NULL DEFAULT 'android',
        "last_seen_at" TIMESTAMP NOT NULL DEFAULT now(),
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_device_tokens" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_device_tokens_token" UNIQUE ("token"),
        CONSTRAINT "FK_device_tokens_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    // Sending to one user is the common read; this is the index behind it.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_device_tokens_user"
         ON "device_tokens" ("user_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_device_tokens_user"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "device_tokens"`);
  }
}
