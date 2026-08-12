import { MigrationInterface, QueryRunner } from 'typeorm';

export class Catalog1785041100000 implements MigrationInterface {
  name = 'Catalog1785041100000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS restaurants (
      id SERIAL PRIMARY KEY,
      name varchar(160) NOT NULL,
      description text,
      address text,
      "imageUrl" varchar,
      "isActive" boolean NOT NULL DEFAULT true,
      "openingHours" text
    )`);
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS menu_categories (
      id SERIAL PRIMARY KEY,
      "restaurantId" integer NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
      name varchar(120) NOT NULL,
      "sortOrder" integer NOT NULL DEFAULT 0,
      "isActive" boolean NOT NULL DEFAULT true
    )`);
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS products (
      id SERIAL PRIMARY KEY,
      "restaurantId" integer NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
      "categoryId" integer REFERENCES menu_categories(id) ON DELETE SET NULL,
      name varchar(160) NOT NULL,
      description text,
      price numeric(10,2) NOT NULL,
      "imageUrl" varchar,
      "isAvailable" boolean NOT NULL DEFAULT true
    )`);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_menu_categories_restaurant ON menu_categories ("restaurantId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_products_restaurant_available ON products ("restaurantId", "isAvailable")`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE IF EXISTS products');
    await queryRunner.query('DROP TABLE IF EXISTS menu_categories');
    await queryRunner.query('DROP TABLE IF EXISTS restaurants');
  }
}
