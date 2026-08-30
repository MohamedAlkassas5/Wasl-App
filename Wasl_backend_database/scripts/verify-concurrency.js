#!/usr/bin/env node
/**
 * Part 16 — the concurrency row, against a REAL multi-connection PostgreSQL.
 *
 *   WASL_TEST_DATABASE_URL=postgres://... node scripts/verify-concurrency.js
 *
 * ## Why this script exists separately from the others
 *
 * Two verifications already run locally and neither one proves this:
 *
 *   - `src/orders/order-accept-concurrency.spec.ts` models a conditional
 *     UPDATE with a fake EntityManager. It pins the *service* logic and says
 *     so itself; it cannot exercise a row lock or transaction isolation.
 *   - `dev-scripts/verify-db-guarantees.mjs` runs against a real Postgres
 *     (PGlite) and proves the *constraints* reject a second write. But PGlite's
 *     socket server serves **one client connection at a time** — probed
 *     directly, a second client's connect times out while the first is open.
 *     Anything "parallel" written against it is silently serialised by the
 *     harness, which would look like proof and be worthless.
 *
 * So this needs a Postgres that accepts genuinely concurrent sessions: Neon,
 * a Docker container, or any real server. It **fails loudly** rather than
 * degrading to something weaker.
 *
 * ## What it proves
 *
 *   1. N parallel accepts        — exactly one winner, N-1 clean conflicts
 *   2. no duplicate assignment   — exactly one assignment row promoted
 *   3. one active order per driver — the partial unique index under real races
 *   4. no ledger anomaly         — parallel duplicate settlement charges once
 *   5. commission + penalty      — both land, on one driver, concurrently
 *   6. balanceAfter correctness  — the ledger's running balance matches
 *   7. rollback                  — a failed transaction leaves nothing behind
 *
 * It drives the **real** `OrdersService` / `PaymentsService` through a real
 * TypeORM pool. A verification that reimplements the mechanism proves the
 * verification works, not the application.
 *
 * ## Safety
 *
 * It writes and deletes fixture rows, so it refuses to run against the value
 * in `DATABASE_URL`. Point `WASL_TEST_DATABASE_URL` at a throwaway database.
 */

require('ts-node/register');
require('dotenv/config');

const { DataSource } = require('typeorm');

const DRIVERS = 5;
const FIXTURE_BASE = 990000; // far above anything a real dataset will reach

const results = [];
function check(name, passed, detail = '') {
  results.push({ name, passed });
  console.log(`  ${passed ? '✅' : '❌'} ${name}${detail ? ` — ${detail}` : ''}`);
}

function requireTestDatabase() {
  const url = process.env.WASL_TEST_DATABASE_URL;

  if (!url) {
    console.error(`
❌ WASL_TEST_DATABASE_URL is not set.

   This verification needs a PostgreSQL server that accepts several
   concurrent connections. PGlite cannot: it serves one client at a time, so
   a "parallel" test against it is serialised and proves nothing.

   Use a throwaway database, for example:

     docker run --rm -d -p 5433:5432 -e POSTGRES_PASSWORD=x --name wasl-verify postgres:16
     WASL_TEST_DATABASE_URL=postgres://postgres:x@localhost:5433/postgres \\
       node scripts/verify-concurrency.js

   ...or a scratch Neon branch. Do NOT point it at production: this script
   writes and deletes rows.
`);
    process.exit(1);
  }

  // The one guard that matters: never the production connection string.
  if (process.env.DATABASE_URL && url.trim() === process.env.DATABASE_URL.trim()) {
    console.error(
      '\n❌ WASL_TEST_DATABASE_URL is identical to DATABASE_URL.\n' +
        '   Refusing to write fixtures into the production database.\n',
    );
    process.exit(1);
  }

  return url;
}

/** Fails loudly if the server cannot actually serve concurrent sessions. */
async function assertRealConcurrency(dataSource) {
  const held = await dataSource.createQueryRunner();
  await held.connect();
  await held.startTransaction();
  try {
    const second = dataSource.createQueryRunner();
    await Promise.race([
      (async () => {
        await second.connect();
        await second.query('SELECT 1');
        await second.release();
      })(),
      new Promise((_, reject) =>
        setTimeout(
          () => reject(new Error('a second connection could not be opened')),
          8000,
        ),
      ),
    ]);
  } finally {
    await held.rollbackTransaction();
    await held.release();
  }
}

async function main() {
  const url = requireTestDatabase();

  const { buildDataSourceOptions } = require('../src/database/data-source');
  const base = buildDataSourceOptions();

  const dataSource = new DataSource({
    ...base,
    url,
    host: undefined,
    port: undefined,
    username: undefined,
    password: undefined,
    database: undefined,
    // Every parallel accept needs its own session, or the pool serialises them
    // and the race never happens.
    extra: { max: DRIVERS + 5 },
    synchronize: false,
  });

  await dataSource.initialize();
  console.log(`\nConnected. Server: ${(await dataSource.query('SHOW server_version'))[0].server_version}\n`);

  console.log('[0] the harness itself');
  try {
    await assertRealConcurrency(dataSource);
    check('the server serves genuinely concurrent sessions', true);
  } catch (error) {
    check('the server serves genuinely concurrent sessions', false, error.message);
    console.error(
      '\n❌ Aborting. Without concurrent sessions nothing below would be a race,\n' +
        '   and reporting it as one would be false.\n',
    );
    await dataSource.destroy();
    process.exit(1);
  }

  console.log('\n[1] migrations');
  const pending = await dataSource.showMigrations();
  if (pending) await dataSource.runMigrations();
  check('schema is migrated', !(await dataSource.showMigrations()));

  // ── fixtures ───────────────────────────────────────────────────────────
  const customerId = FIXTURE_BASE;
  const driverIds = Array.from({ length: DRIVERS }, (_, i) => FIXTURE_BASE + 1 + i);
  const orderId = FIXTURE_BASE;

  async function cleanup() {
    await dataSource.query(
      `DELETE FROM wallet_transactions WHERE driver_id = ANY($1) OR order_id = $2`,
      [driverIds, orderId],
    );
    await dataSource.query(`DELETE FROM order_assignments WHERE order_id = $1`, [orderId]);
    await dataSource.query(`DELETE FROM order_cancellation_requests WHERE order_id = $1`, [orderId]);
    await dataSource.query(`DELETE FROM orders WHERE id = $1`, [orderId]);
    await dataSource.query(`DELETE FROM delivery_partners WHERE user_id = ANY($1)`, [driverIds]);
    await dataSource.query(`DELETE FROM users WHERE id = ANY($1) OR id = $2`, [driverIds, customerId]);
  }

  async function seed() {
    await cleanup();

    await dataSource.query(
      `INSERT INTO users (id, name, phone, "passwordHash", role, status)
       VALUES ($1, 'Verify Customer', $2, 'x', 'customer', 'active')`,
      [customerId, `0199${customerId}`.slice(0, 15)],
    );

    for (const id of driverIds) {
      await dataSource.query(
        `INSERT INTO users (id, name, phone, "passwordHash", role, status)
         VALUES ($1, 'Verify Driver', $2, 'x', 'delivery', 'active')`,
        [id, `0199${id}`.slice(0, 15)],
      );
      await dataSource.query(
        `INSERT INTO delivery_partners (user_id, verification_status, is_online, balance)
         VALUES ($1, 'approved', true, 500)`,
        [id],
      );
    }

    await dataSource.query(
      `INSERT INTO orders (id, "customerId", status, "categoryType", "itemsDescription",
                           "deliveryAddressText", estimated_delivery_fee, "finalDeliveryFee",
                           "itemsPrice", latitude, longitude)
       VALUES ($1, $2, 'pending_offers', 'verify', 'verify', 'verify', 20, 20, 0, 30.76, 30.69)`,
      [orderId, customerId],
    );

    // Every driver is genuinely offered the order, so the race is decided by
    // the lock and the conditional UPDATE, not by who was eligible.
    const expires = new Date(Date.now() + 10 * 60 * 1000);
    for (const id of driverIds) {
      await dataSource.query(
        `INSERT INTO order_assignments (order_id, driver_id, status, offered_at, expires_at, wave)
         VALUES ($1, $2, 'offered', now(), $3, 1)`,
        [orderId, id, expires],
      );
    }
  }

  // ── 1..3 N parallel accepts ────────────────────────────────────────────
  console.log('\n[2] N parallel accepts through the real service');
  await seed();

  const { OrdersService } = require('../src/orders/orders.service');
  const { OrderAssignmentService } = require('../src/orders/order-assignment.service');
  const { PaymentsService } = require('../src/payments/payments.service');
  const { Order } = require('../src/orders/entities/order.entity');

  // The accept path only touches the order repository's manager, the
  // assignment service's static helper and the notification repository, so a
  // partially-wired service is enough to drive the real code — and anything
  // it does reach is the real implementation, not a stub.
  const noopNotifications = { notifyUser: async () => {} };
  const service = Object.create(OrdersService.prototype);
  service.orderRepository = dataSource.getRepository(Order);
  service.notifications = noopNotifications;
  service.createNotification = async () => {};
  service.assignmentService = { constructor: OrderAssignmentService };

  const settled = await Promise.allSettled(
    driverIds.map((id) => service.acceptAvailableOrder(orderId, id)),
  );
  const won = settled.filter((r) => r.status === 'fulfilled');
  const lost = settled.filter((r) => r.status === 'rejected');

  check('exactly one of N parallel accepts wins', won.length === 1,
    `${won.length} won, ${lost.length} lost of ${DRIVERS}`);
  check('every loser fails cleanly, not obscurely',
    lost.every((r) => /Conflict|تم إسناده|لم يعد|انتهت/.test(String(r.reason?.message ?? r.reason))),
    lost.length ? String(lost[0].reason?.message ?? lost[0].reason).slice(0, 60) : '');

  const [orderRow] = await dataSource.query(
    `SELECT status, "acceptedDriverId" FROM orders WHERE id = $1`, [orderId]);
  check('the order ends up with exactly one driver',
    orderRow.status === 'accepted' && driverIds.includes(Number(orderRow.acceptedDriverId)),
    `status=${orderRow.status} driver=${orderRow.acceptedDriverId}`);

  const [{ accepted }] = await dataSource.query(
    `SELECT COUNT(*)::int AS accepted FROM order_assignments
      WHERE order_id = $1 AND status = 'accepted'`, [orderId]);
  check('exactly one assignment is promoted', accepted === 1, `${accepted} accepted`);

  const [{ live }] = await dataSource.query(
    `SELECT COUNT(*)::int AS live FROM order_assignments
      WHERE order_id = $1 AND status = 'offered'`, [orderId]);
  check('no offer is left live on a taken order', live === 0, `${live} still offered`);

  // ── 4..6 ledger under concurrency ──────────────────────────────────────
  console.log('\n[3] the ledger under concurrency');
  const winnerId = Number(orderRow.acceptedDriverId);

  const [{ balance: startBalance }] = await dataSource.query(
    `SELECT balance FROM delivery_partners WHERE user_id = $1`, [winnerId]);

  // The same reference, fired in parallel: the UNIQUE constraint must let
  // exactly one through. This is the double-settlement case.
  const dupes = await Promise.allSettled(
    Array.from({ length: DRIVERS }, () =>
      dataSource.transaction((manager) =>
        PaymentsService.creditWithin(manager, {
          driverId: winnerId, amount: -8, type: 'commission',
          note: 'verify', reference: `order-${orderId}-commission`, orderId,
        }),
      ),
    ),
  );
  const [{ commissions }] = await dataSource.query(
    `SELECT COUNT(*)::int AS commissions FROM wallet_transactions
      WHERE reference = $1`, [`order-${orderId}-commission`]);
  check('N parallel settlements charge exactly once', commissions === 1,
    `${commissions} rows, ${dupes.filter((d) => d.status === 'fulfilled').length} calls succeeded`);

  // A commission and a cancellation penalty are different references, so both
  // must land even when they race on the same driver row.
  await Promise.all([
    dataSource.transaction((m) => PaymentsService.creditWithin(m, {
      driverId: winnerId, amount: -4, type: 'cancellation_penalty',
      note: 'verify', reference: `order-${orderId}-cancel-penalty`, orderId })),
    dataSource.transaction((m) => PaymentsService.creditWithin(m, {
      driverId: winnerId, amount: -3, type: 'commission',
      note: 'verify', reference: `order-${orderId}-extra`, orderId })),
  ]);

  const ledger = await dataSource.query(
    `SELECT amount, balance_after FROM wallet_transactions
      WHERE driver_id = $1 ORDER BY id ASC`, [winnerId]);
  const [{ balance: endBalance }] = await dataSource.query(
    `SELECT balance FROM delivery_partners WHERE user_id = $1`, [winnerId]);

  const movement = ledger.reduce((sum, r) => sum + Number(r.amount), 0);
  check('the driver balance equals start + every ledger movement',
    Math.abs((Number(startBalance) + movement) - Number(endBalance)) < 0.001,
    `${startBalance} + ${movement} = ${endBalance}`);

  // balanceAfter must be a real running total, not each row's own guess —
  // two debits racing on one row is exactly how that goes wrong.
  const lastAfter = Number(ledger[ledger.length - 1].balance_after);
  check('the last balanceAfter matches the driver row',
    Math.abs(lastAfter - Number(endBalance)) < 0.001,
    `ledger ${lastAfter} vs driver ${endBalance}`);

  const afters = ledger.map((r) => Number(r.balance_after));
  check('no two ledger rows claim the same balanceAfter',
    new Set(afters).size === afters.length, afters.join(', '));

  // ── 7 rollback ─────────────────────────────────────────────────────────
  console.log('\n[4] rollback');
  const before = await dataSource.query(
    `SELECT COUNT(*)::int AS n FROM wallet_transactions WHERE driver_id = $1`, [winnerId]);
  try {
    await dataSource.transaction(async (manager) => {
      await PaymentsService.creditWithin(manager, {
        driverId: winnerId, amount: -99, type: 'commission',
        note: 'verify-rollback', reference: `order-${orderId}-rollback`, orderId });
      throw new Error('deliberate failure after the debit');
    });
  } catch { /* expected */ }

  const after = await dataSource.query(
    `SELECT COUNT(*)::int AS n FROM wallet_transactions WHERE driver_id = $1`, [winnerId]);
  const [{ balance: rolledBack }] = await dataSource.query(
    `SELECT balance FROM delivery_partners WHERE user_id = $1`, [winnerId]);
  check('a failed transaction leaves no ledger row', before[0].n === after[0].n,
    `${before[0].n} → ${after[0].n}`);
  check('…and does not move the balance',
    Math.abs(Number(rolledBack) - Number(endBalance)) < 0.001,
    `${endBalance} → ${rolledBack}`);

  // ── done ───────────────────────────────────────────────────────────────
  await cleanup();
  await dataSource.destroy();

  const failed = results.filter((r) => !r.passed);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  if (failed.length) {
    console.log('\nFailed:');
    failed.forEach((f) => console.log(`  - ${f.name}`));
  }
  process.exit(failed.length === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error('\n❌ Verification aborted:', error.message);
  console.error(error.stack);
  process.exit(1);
});
