import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * The three approved V1 areas and their price tables.
 *
 * This is reference data the product cannot run without — with an empty
 * `delivery_zones` table every area selector is blank and every zone quote
 * fails — so it ships as a migration rather than a dev-only seed script. It is
 * idempotent: re-running adopts rows that already exist by name instead of
 * duplicating them, and never overwrites a fee an administrator has since
 * edited through `POST /zones/rates`.
 *
 * ── Normal (destination-only) fees — APPROVED ───────────────────────────────
 *   كوم حمادة 20 · بيبان 40 · بريم 40
 *
 * ── Waslly route matrix — APPROVED ──────────────────────────────────────────
 * Fee is a property of the route, not of distance. Staying inside one area is
 * the cheap leg; a leg touching كوم حمادة is 40; and بيبان ↔ بريم is dearest at
 * 50, since it is the one pair with no town centre on either end:
 *
 *              →  كوم حمادة   بيبان   بريم
 *   كوم حمادة        20        40      40
 *   بيبان            40        20      50
 *   بريم             40        50      20
 *
 * The matrix is symmetric, but it is stored as nine directed rows rather than
 * six undirected ones because `delivery_zone_rates` is keyed on an ordered
 * (pickup, dropoff) pair — and a future tariff may well price a direction
 * differently without needing a schema change.
 *
 * Every one of these is a data row, editable at runtime by an admin via
 * `POST /zones/rates` with no redeploy.
 */
export class SeedApprovedAreas1785041500000 implements MigrationInterface {
  name = 'SeedApprovedAreas1785041500000';

  /**
   * Zone geography is intentionally left NULL. V1 pricing is a pure function of
   * the areas the customer picks, never of coordinates, and inventing a centre
   * point and radius for each village would put fabricated GPS in the database
   * that some later feature would trust. Fill these in from real survey data
   * when something actually needs them.
   */
  private static readonly ZONES = [
    { code: 'kom_hamada', name: 'كوم حمادة', normalFee: 20 },
    { code: 'biban', name: 'بيبان', normalFee: 40 },
    { code: 'breem', name: 'بريم', normalFee: 40 },
  ];

  private static readonly CITY = 'البحيرة';

  /** [pickup code, dropoff code, fee] — see the matrix in the class doc. */
  private static readonly ROUTES: [string, string, number][] = [
    // Same area — 20
    ['kom_hamada', 'kom_hamada', 20],
    ['biban', 'biban', 20],
    ['breem', 'breem', 20],
    // One leg in the town centre — 40
    ['kom_hamada', 'biban', 40],
    ['biban', 'kom_hamada', 40],
    ['kom_hamada', 'breem', 40],
    ['breem', 'kom_hamada', 40],
    // Village to village — 50
    ['biban', 'breem', 50],
    ['breem', 'biban', 50],
  ];

  public async up(queryRunner: QueryRunner): Promise<void> {
    for (const zone of SeedApprovedAreas1785041500000.ZONES) {
      // Adopt a row someone already created by hand before codes existed,
      // so the seed can't produce a second "كوم حمادة".
      await queryRunner.query(
        `UPDATE "delivery_zones" SET "code" = $1
         WHERE "code" IS NULL AND "name" = $2`,
        [zone.code, zone.name],
      );

      await queryRunner.query(
        // The casts are required: without them Postgres has to infer $1 both as
        // a bare select-list value and as the right-hand side of a varchar
        // comparison, and refuses with "inconsistent types deduced".
        `INSERT INTO "delivery_zones" ("code", "name", "city", "normal_delivery_fee", "isActive")
         SELECT $1::varchar, $2::varchar, $3::varchar, $4::numeric, true
         WHERE NOT EXISTS (SELECT 1 FROM "delivery_zones" WHERE "code" = $1::varchar)`,
        [
          zone.code,
          zone.name,
          SeedApprovedAreas1785041500000.CITY,
          zone.normalFee,
        ],
      );

      // Only fills a gap — an edited fee is left alone.
      await queryRunner.query(
        `UPDATE "delivery_zones" SET "normal_delivery_fee" = $2
         WHERE "code" = $1 AND "normal_delivery_fee" IS NULL`,
        [zone.code, zone.normalFee],
      );
    }

    for (const [
      pickup,
      dropoff,
      fee,
    ] of SeedApprovedAreas1785041500000.ROUTES) {
      await queryRunner.query(
        `INSERT INTO "delivery_zone_rates"
           ("pickup_zone_id", "dropoff_zone_id", "deliveryFee", "isActive")
         SELECT p."id", d."id", $3::numeric, true
         FROM "delivery_zones" p, "delivery_zones" d
         WHERE p."code" = $1::varchar AND d."code" = $2::varchar
         ON CONFLICT ON CONSTRAINT "UQ_delivery_zone_rate_pair" DO NOTHING`,
        [pickup, dropoff, fee],
      );
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    const codes = SeedApprovedAreas1785041500000.ZONES.map((z) => z.code);
    // Rates go first: the FK from delivery_zone_rates cascades, but being
    // explicit keeps the intent readable.
    await queryRunner.query(
      `DELETE FROM "delivery_zone_rates"
       WHERE "pickup_zone_id" IN (SELECT "id" FROM "delivery_zones" WHERE "code" = ANY($1))
          OR "dropoff_zone_id" IN (SELECT "id" FROM "delivery_zones" WHERE "code" = ANY($1))`,
      [codes],
    );
    await queryRunner.query(
      `DELETE FROM "delivery_zones" WHERE "code" = ANY($1)`,
      [codes],
    );
  }
}
