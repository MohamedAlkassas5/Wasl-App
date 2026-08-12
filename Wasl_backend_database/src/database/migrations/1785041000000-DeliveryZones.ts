import { MigrationInterface, QueryRunner } from 'typeorm';

/** Fixed pickup/drop-off zone prices managed by administrators. */
export class DeliveryZones1785041000000 implements MigrationInterface {
  name = 'DeliveryZones1785041000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "delivery_zones" (
        "id" SERIAL PRIMARY KEY,
        "name" varchar(120) NOT NULL,
        "city" varchar(120) NOT NULL,
        "isActive" boolean NOT NULL DEFAULT true,
        "latitude" double precision,
        "longitude" double precision,
        "radiusKm" double precision,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "delivery_zone_rates" (
        "id" SERIAL PRIMARY KEY,
        "pickup_zone_id" integer NOT NULL REFERENCES "delivery_zones"("id") ON DELETE CASCADE,
        "dropoff_zone_id" integer NOT NULL REFERENCES "delivery_zones"("id") ON DELETE CASCADE,
        "deliveryFee" numeric(10,2) NOT NULL,
        "estimatedMinutes" integer NOT NULL DEFAULT 30,
        "isActive" boolean NOT NULL DEFAULT true,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_delivery_zone_rate_pair" UNIQUE ("pickup_zone_id", "dropoff_zone_id")
      )
    `);
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_delivery_zones_city_active" ON "delivery_zones" ("city", "isActive")',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_delivery_zone_rates_active" ON "delivery_zone_rates" ("isActive")',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE IF EXISTS "delivery_zone_rates"');
    await queryRunner.query('DROP TABLE IF EXISTS "delivery_zones"');
  }
}
