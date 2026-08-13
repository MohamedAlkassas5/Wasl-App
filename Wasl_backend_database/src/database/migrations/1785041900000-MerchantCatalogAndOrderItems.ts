import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Makes `Merchant` the one commercial entity, and gives orders real lines.
 *
 * ── Why ────────────────────────────────────────────────────────────────────
 * The catalog hung off a separate `restaurants` table with its own SERIAL and
 * no relationship to `merchants`. The customer app lists shops from
 * `/stores/nearby` — which returns `merchants.id` — and then asked for that
 * id's menu, which was looked up in `restaurants`. Two independent id spaces,
 * so the menu shown was whichever restaurant happened to share the number, or
 * nothing at all. In practice nothing at all: the seed only ever inserted
 * merchants, so `restaurants` is empty and the restaurant journey has been
 * broken at the menu step.
 *
 * A restaurant, a pharmacy and a shop are the same kind of thing — a business
 * with an owner, an approval state, a location and a `storeType`. `Merchant`
 * already models all of that; `Restaurant` modelled none of it. So the catalog
 * moves to `Merchant` and `restaurants` is retired.
 *
 * ── Existing data ──────────────────────────────────────────────────────────
 * Catalog rows are re-pointed by matching `restaurants.name` to
 * `merchants.store_name`. Anything that fails to match is deleted, and that is
 * safe by construction: such a row hung off a restaurant id no customer could
 * ever reach, since every menu request in the app arrives as a merchant id.
 * The count is reported in the server log rather than discarded silently.
 */
export class MerchantCatalogAndOrderItems1785041900000 implements MigrationInterface {
  name = 'MerchantCatalogAndOrderItems1785041900000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── 1. catalog: restaurantId → merchant_id ─────────────────────────────
    for (const table of ['menu_categories', 'products']) {
      await queryRunner.query(
        `ALTER TABLE "${table}" ADD COLUMN IF NOT EXISTS "merchant_id" integer`,
      );

      // Best-effort adoption of any pre-existing rows, by business name.
      await queryRunner.query(`
        UPDATE "${table}" t
           SET "merchant_id" = m."id"
          FROM "restaurants" r
          JOIN "merchants" m ON m."store_name" = r."name"
         WHERE t."restaurantId" = r."id" AND t."merchant_id" IS NULL
      `);

      const orphaned = (await queryRunner.query(
        `SELECT COUNT(*)::int AS n FROM "${table}" WHERE "merchant_id" IS NULL`,
      )) as { n: number }[];
      const count = Number(orphaned[0]?.n ?? 0);
      if (count > 0) {
        console.warn(
          `[MerchantCatalog] removing ${count} ${table} row(s) that pointed at a restaurant with no matching merchant — they were unreachable from the app.`,
        );
        await queryRunner.query(
          `DELETE FROM "${table}" WHERE "merchant_id" IS NULL`,
        );
      }

      await queryRunner.query(
        `ALTER TABLE "${table}" ALTER COLUMN "merchant_id" SET NOT NULL`,
      );
      await queryRunner.query(
        `ALTER TABLE "${table}" DROP COLUMN IF EXISTS "restaurantId"`,
      );
    }

    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'FK_15a56107d5d741b7e03fd2784db') THEN
          ALTER TABLE "menu_categories"
            ADD CONSTRAINT "FK_15a56107d5d741b7e03fd2784db"
            FOREIGN KEY ("merchant_id") REFERENCES "merchants"("id") ON DELETE CASCADE;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'FK_7d80d63e220c4511ab4b6595846') THEN
          ALTER TABLE "products"
            ADD CONSTRAINT "FK_7d80d63e220c4511ab4b6595846"
            FOREIGN KEY ("merchant_id") REFERENCES "merchants"("id") ON DELETE CASCADE;
        END IF;
      END $$;
    `);

    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_menu_categories_merchant" ON "menu_categories" ("merchant_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_products_merchant_available" ON "products" ("merchant_id", "isAvailable")`,
    );
    // The old indexes named a column that no longer exists.
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_menu_categories_restaurant"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_products_restaurant_available"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "restaurants"`);

    await queryRunner.query(
      `ALTER TABLE "products" ADD COLUMN IF NOT EXISTS "is_popular" boolean NOT NULL DEFAULT false`,
    );

    // ─── 2. sizes and add-ons the app already expected ──────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "product_sizes" (
        "id" SERIAL PRIMARY KEY,
        "product_id" integer NOT NULL,
        "name" varchar(80) NOT NULL,
        "price" numeric(10,2) NOT NULL,
        "sortOrder" integer NOT NULL DEFAULT 0,
        "isAvailable" boolean NOT NULL DEFAULT true,
        CONSTRAINT "FK_b6d94a689dd115cdf01589b9615"
          FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "product_addons" (
        "id" SERIAL PRIMARY KEY,
        "product_id" integer NOT NULL,
        "name" varchar(80) NOT NULL,
        "price" numeric(10,2) NOT NULL,
        "sortOrder" integer NOT NULL DEFAULT 0,
        "isAvailable" boolean NOT NULL DEFAULT true,
        CONSTRAINT "FK_04a41d4ab613615c88ea24c9bc1"
          FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_product_sizes_product" ON "product_sizes" ("product_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_product_addons_product" ON "product_addons" ("product_id")`,
    );

    // ─── 3. order lines, frozen at purchase ─────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_items" (
        "id" SERIAL PRIMARY KEY,
        "order_id" integer NOT NULL,
        "product_id" integer,
        "name" varchar(160) NOT NULL,
        "size_name" varchar(80),
        "unit_price" numeric(10,2) NOT NULL,
        "quantity" integer NOT NULL,
        "line_total" numeric(10,2) NOT NULL,
        "addons" jsonb,
        "note" text,
        CONSTRAINT "FK_145532db85752b29c57d2b7b1f1"
          FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_9263386c35b6b242540f9493b00"
          FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_order_items_order" ON "order_items" ("order_id")`,
    );

    // ─── 4. typed order contracts ───────────────────────────────────────────
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "order_type" varchar(20) NOT NULL DEFAULT 'general'`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "merchant_id" integer`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "pharmacy_name" varchar(160)`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "prescription_image_url" varchar`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "recipient_phone" varchar(20)`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "recipient_name" varchar(100)`,
    );

    // Existing orders keep working: a Waslly run is the one with both areas
    // and nothing bought; everything else predates typing and stays 'general'.
    await queryRunner.query(`
      UPDATE "orders"
         SET "order_type" = 'waslly'
       WHERE "pickup_zone_id" IS NOT NULL
         AND "dropoff_zone_id" IS NOT NULL
         AND "order_type" = 'general'
    `);

    // ─── 5. cash on delivery is the only method that exists ─────────────────
    // `paymob`/`fawry` were enum values with no integration behind them.
    await queryRunner.query(
      `UPDATE "orders" SET "payment_method" = 'cod' WHERE "payment_method" <> 'cod'`,
    );

    // ─── 6. indexes the order lists have always needed ──────────────────────
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_orders_status" ON "orders" ("status")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_orders_customer" ON "orders" ("customerId", "createdAt")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "idx_orders_driver_status" ON "orders" ("acceptedDriverId", "status")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const index of [
      'idx_orders_driver_status',
      'idx_orders_customer',
      'idx_orders_status',
      'idx_order_items_order',
      'idx_product_addons_product',
      'idx_product_sizes_product',
      'idx_products_merchant_available',
      'idx_menu_categories_merchant',
    ]) {
      await queryRunner.query(`DROP INDEX IF EXISTS "${index}"`);
    }
    for (const column of [
      'recipient_name',
      'recipient_phone',
      'prescription_image_url',
      'pharmacy_name',
      'merchant_id',
      'order_type',
    ]) {
      await queryRunner.query(
        `ALTER TABLE "orders" DROP COLUMN IF EXISTS "${column}"`,
      );
    }
    await queryRunner.query(`DROP TABLE IF EXISTS "order_items"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "product_addons"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "product_sizes"`);
    await queryRunner.query(
      `ALTER TABLE "products" DROP COLUMN IF EXISTS "is_popular"`,
    );

    // `restaurants` is recreated empty. The rows that were on it could not be
    // reconstructed: they were deleted as unreachable on the way up.
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "restaurants" (
        "id" SERIAL PRIMARY KEY,
        "name" varchar(160) NOT NULL,
        "description" text,
        "address" text,
        "imageUrl" varchar,
        "isActive" boolean NOT NULL DEFAULT true,
        "openingHours" text
      )
    `);
    for (const table of ['menu_categories', 'products']) {
      await queryRunner.query(
        `ALTER TABLE "${table}" DROP CONSTRAINT IF EXISTS "${
          table === 'menu_categories'
            ? 'FK_15a56107d5d741b7e03fd2784db'
            : 'FK_7d80d63e220c4511ab4b6595846'
        }"`,
      );
      await queryRunner.query(
        `ALTER TABLE "${table}" ADD COLUMN IF NOT EXISTS "restaurantId" integer`,
      );
      await queryRunner.query(
        `ALTER TABLE "${table}" DROP COLUMN IF EXISTS "merchant_id"`,
      );
    }
  }
}
