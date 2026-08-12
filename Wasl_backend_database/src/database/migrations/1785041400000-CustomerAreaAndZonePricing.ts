import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Checkpoint 1 schema: approved customer areas and area-based pricing.
 *
 * Hand-written on purpose. `migration:generate` was used once as an oracle to
 * read back the constraint name TypeORM derives for the new User→DeliveryZone
 * relation (`FK_bf01bc1fe8bf70c459232c3297a`), and that name is reproduced
 * verbatim below so entity metadata and schema agree and no future generate
 * tries to rename it.
 *
 * What the generated output ALSO wanted to do — and what is deliberately NOT
 * done here — was drop five existing indexes (`idx_orders_zone_pair`,
 * `IDX_delivery_zone_rates_active`, `IDX_delivery_zones_city_active`,
 * `idx_menu_categories_restaurant`, `idx_products_restaurant_available`) and
 * rename five inline `*_fkey` constraints, purely because the earlier
 * migrations declared them in SQL rather than through decorators. Those objects
 * are useful and pre-existing, so they stay. That pre-existing drift is a known
 * issue tracked separately; this migration neither worsens nor silently
 * "fixes" it.
 */
export class CustomerAreaAndZonePricing1785041400000 implements MigrationInterface {
  name = 'CustomerAreaAndZonePricing1785041400000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // --- delivery_zones: stable code + normal (destination-only) fee ---
    await queryRunner.query(
      `ALTER TABLE "delivery_zones" ADD COLUMN IF NOT EXISTS "code" character varying(40)`,
    );
    await queryRunner.query(
      `ALTER TABLE "delivery_zones" ADD COLUMN IF NOT EXISTS "normal_delivery_fee" numeric(10,2)`,
    );
    // Guarded so a re-run on a partially-migrated database is a no-op.
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'UQ_delivery_zones_code'
        ) THEN
          ALTER TABLE "delivery_zones"
            ADD CONSTRAINT "UQ_delivery_zones_code" UNIQUE ("code");
        END IF;
      END $$;
    `);

    // --- users: the customer's approved home area ---
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "customer_zone_id" integer`,
    );
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'FK_bf01bc1fe8bf70c459232c3297a'
        ) THEN
          ALTER TABLE "users"
            ADD CONSTRAINT "FK_bf01bc1fe8bf70c459232c3297a"
            FOREIGN KEY ("customer_zone_id") REFERENCES "delivery_zones"("id")
            ON DELETE SET NULL ON UPDATE NO ACTION;
        END IF;
      END $$;
    `);

    // --- orders: which pricing rule produced the stored fee ---
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "pricing_source" character varying(32)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" DROP COLUMN IF EXISTS "pricing_source"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "FK_bf01bc1fe8bf70c459232c3297a"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "customer_zone_id"`,
    );
    await queryRunner.query(
      `ALTER TABLE "delivery_zones" DROP CONSTRAINT IF EXISTS "UQ_delivery_zones_code"`,
    );
    await queryRunner.query(
      `ALTER TABLE "delivery_zones" DROP COLUMN IF EXISTS "normal_delivery_fee"`,
    );
    await queryRunner.query(
      `ALTER TABLE "delivery_zones" DROP COLUMN IF EXISTS "code"`,
    );
  }
}
