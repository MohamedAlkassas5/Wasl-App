import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderZones1785041200000 implements MigrationInterface {
  name = 'OrderZones1785041200000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_zone_id integer',
    );
    await queryRunner.query(
      'ALTER TABLE orders ADD COLUMN IF NOT EXISTS dropoff_zone_id integer',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS idx_orders_zone_pair ON orders (pickup_zone_id, dropoff_zone_id)',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP INDEX IF EXISTS idx_orders_zone_pair');
    await queryRunner.query(
      'ALTER TABLE orders DROP COLUMN IF EXISTS pickup_zone_id',
    );
    await queryRunner.query(
      'ALTER TABLE orders DROP COLUMN IF EXISTS dropoff_zone_id',
    );
  }
}
