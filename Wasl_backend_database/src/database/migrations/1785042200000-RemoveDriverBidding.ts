import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * CP6-A — retire driver bidding.
 *
 * `order_offers` held one driver's bid on one order: a delivery fee of their
 * own choosing plus an ETA. Accepting a bid copied that fee straight onto
 * `orders.finalDeliveryFee` with no check against the zone rate table, which
 * made the driver the last word on price and the central pricing table
 * advisory. V1 quotes the fee from the zone table at creation and freezes it on
 * acceptance, so there is no longer a second price to store.
 *
 * Destructive: this drops a table with rows in it. Bids are not financial
 * records — no bid ever moved money, and the fee a bid produced is already
 * frozen on the order it was accepted for — so nothing auditable is lost.
 * Orders, wallet ledger entries and every settled amount are untouched.
 *
 * `down()` recreates the table exactly as `InitialSchema` declared it,
 * constraint names included, so a rollback lands on a schema the older code
 * still recognises. The rows themselves are gone for good; that is the part
 * that cannot be undone, which is why this migration is separate from anything
 * else and easy to revert on its own.
 */
export class RemoveDriverBidding1785042200000 implements MigrationInterface {
  name = 'RemoveDriverBidding1785042200000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Constraints first: dropping the table would take them with it, but being
    // explicit keeps the rollback symmetrical and readable.
    await queryRunner.query(
      `ALTER TABLE IF EXISTS "order_offers" DROP CONSTRAINT IF EXISTS "FK_4d19b64af866b76b977a4e02757"`,
    );
    await queryRunner.query(
      `ALTER TABLE IF EXISTS "order_offers" DROP CONSTRAINT IF EXISTS "FK_442420865429b5f394b72188d4f"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "order_offers"`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "order_offers" ("id" SERIAL NOT NULL, "orderId" integer NOT NULL, "driverId" integer NOT NULL, "deliveryFee" numeric(10,2) NOT NULL, "estimatedTime" integer NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "itemsPrice" numeric(10,2) DEFAULT '0', CONSTRAINT "PK_1bffc1972713d7342168ba014a3" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `ALTER TABLE "order_offers" ADD CONSTRAINT "FK_442420865429b5f394b72188d4f" FOREIGN KEY ("orderId") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    );
    await queryRunner.query(
      `ALTER TABLE "order_offers" ADD CONSTRAINT "FK_4d19b64af866b76b977a4e02757" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`,
    );
  }
}
