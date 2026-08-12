import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderPayments1785041300000 implements MigrationInterface {
  name = 'OrderPayments1785041300000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      "ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method varchar(20) NOT NULL DEFAULT 'cod'",
    );
    await queryRunner.query(
      "ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status varchar(20) NOT NULL DEFAULT 'cod_due'",
    );
    await queryRunner.query(
      'ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_reference varchar',
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE orders DROP COLUMN IF EXISTS payment_reference',
    );
    await queryRunner.query(
      'ALTER TABLE orders DROP COLUMN IF EXISTS payment_status',
    );
    await queryRunner.query(
      'ALTER TABLE orders DROP COLUMN IF EXISTS payment_method',
    );
  }
}
