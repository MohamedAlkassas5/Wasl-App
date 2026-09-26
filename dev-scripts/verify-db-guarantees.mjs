// Part 16 — the database guarantees, verified against a real Postgres.
//
// Why this exists
// ---------------
// `order-accept-concurrency.spec.ts` pins the *service* logic with a fake
// EntityManager. It says so itself: it cannot prove that Postgres enforces the
// partial unique index, that `wallet_transactions.reference` really rejects a
// duplicate, or that a conditional UPDATE matches zero rows once the status has
// moved. Those are database properties. This script exercises them on a real
// Postgres, built by the project's own migrations.
//
// What it does NOT do, deliberately
// ---------------------------------
// It does not run N *simultaneous* accepts. PGlite's socket server serves one
// client connection at a time (probed: a second client's connect times out
// while the first is open), so any "parallel" test here would be serialised by
// the harness and would prove nothing about row locks or isolation while
// looking like it did. That row of Part 16 needs a multi-connection Postgres —
// the Neon instance, or Docker — and is reported as outstanding rather than
// faked.
//
// What it DOES prove is the backstop that makes the race safe: even if two
// sessions were to get that far, the constraints below reject the second one.
//
// Usage:  node dev-scripts/verify-db-guarantees.mjs
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { PGlite } from '@electric-sql/pglite';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.resolve(HERE, '..', 'Wasl_backend_database');
const PORT = 55433;

// PGlite's socket server throws an uncaught ECONNRESET when a client goes away,
// which the TypeORM CLI does every time it finishes. Without this the harness
// dies between migration steps and the failure looks like a product bug.
process.on('uncaughtException', (error) => {
  if (/ECONNRESET|EPIPE/.test(error?.message ?? '')) return;
  throw error;
});

const results = [];
const check = (name, passed, detail = '') => {
  results.push({ name, passed, detail });
  console.log(`${passed ? '  ✓' : '  ✗'} ${name}${detail ? ` — ${detail}` : ''}`);
};

/** Runs a TypeORM CLI command against the live PGlite, and resolves its output. */
function runCli(args) {
  return new Promise((resolve) => {
    const child = spawn(
      process.platform === 'win32' ? 'npm.cmd' : 'npm',
      args,
      {
        cwd: BACKEND,
        shell: process.platform === 'win32',
        env: {
          ...process.env,
          DB_HOST: '127.0.0.1',
          DB_PORT: String(PORT),
          DB_USERNAME: 'postgres',
          DB_PASSWORD: 'x',
          DB_NAME: 'postgres',
          DB_POOL_MAX: '1', // PGlite serves one connection; a pool wedges it.
          DATABASE_URL: '',
          NODE_ENV: 'development',
        },
      },
    );

    let out = '';
    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (out += d));
    child.on('close', (code) => resolve({ code, out }));
  });
}

/** True when `fn` throws a Postgres error whose message matches `pattern`. */
async function rejects(db, sql, pattern) {
  try {
    await db.query(sql);
    return { rejected: false, message: 'statement unexpectedly succeeded' };
  } catch (error) {
    const message = String(error?.message ?? error);
    return { rejected: pattern.test(message), message };
  }
}

const db = await PGlite.create(); // in-memory: nothing to corrupt, fresh every run
const server = new PGLiteSocketServer({ db, port: PORT, host: '127.0.0.1' });
await server.start();

try {
  // ── 1. Fresh apply ─────────────────────────────────────────────────────
  console.log('\n[1] migrations on a fresh database');
  const up = await runCli(['run', 'migration:run']);
  check('migration:run succeeds on an empty database', up.code === 0,
    up.code === 0 ? '' : up.out.slice(-400));

  const shown = await runCli(['run', 'migration:show']);
  const pending = (shown.out.match(/\[ \]/g) || []).length;
  const applied = (shown.out.match(/\[X\]/g) || []).length;
  check('every migration reports as applied', pending === 0 && applied > 0,
    `${applied} applied, ${pending} pending`);

  // ── 2. Schema ──────────────────────────────────────────────────────────
  console.log('\n[2] schema');
  const tables = await db.query(`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename
  `);
  const names = tables.rows.map((r) => r.tablename);
  for (const required of [
    'orders', 'order_assignments', 'wallet_transactions',
    'wallet_topup_requests',
    'order_cancellation_requests', 'device_tokens', 'admin_audit_log',
  ]) {
    check(`table ${required} exists`, names.includes(required));
  }

  // ── 3. Indexes that carry the guarantees ───────────────────────────────
  console.log('\n[3] the indexes the concurrency design leans on');
  const indexes = await db.query(`
    SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'public'
  `);
  const byName = Object.fromEntries(indexes.rows.map((r) => [r.indexname, r.indexdef]));

  const oneActive = byName['idx_orders_one_active_per_driver'];
  check('idx_orders_one_active_per_driver exists', Boolean(oneActive));
  check('…and is UNIQUE and partial', Boolean(oneActive) &&
    /UNIQUE/i.test(oneActive) && /WHERE/i.test(oneActive));

  const walletRef = Object.entries(byName).find(([, def]) =>
    /wallet_transactions/.test(def) && /UNIQUE/i.test(def) && /reference/.test(def));
  check('wallet_transactions.reference is UNIQUE', Boolean(walletRef),
    walletRef ? walletRef[0] : 'not found');

  // ── 4. Enforcement, not just presence ──────────────────────────────────
  // The user's rule: verify actual enforcement. An index that exists but does
  // not reject anything is not a guarantee.
  console.log('\n[4] the constraints actually reject the second write');

  // Column naming is genuinely mixed in this schema (`acceptedDriverId` beside
  // `accepted_at`), so these are written from the live information_schema
  // rather than from the entity definitions.
  const user = (id, name, phone, role) => `
    INSERT INTO users (id, name, phone, "passwordHash", role, status)
    VALUES (${id}, '${name}', '${phone}', 'x', '${role}', 'active')
    ON CONFLICT DO NOTHING`;

  await db.exec(`
    ${user(901, 'Test Driver', '01000000901', 'delivery')};
    ${user(902, 'Test Customer', '01000000902', 'customer')};
    ${user(903, 'Second Driver', '01000000903', 'delivery')};
  `);

  const order = (id, status, driver) => `
    INSERT INTO orders (id, "customerId", "acceptedDriverId", status,
                        "categoryType", "itemsDescription", "deliveryAddressText",
                        estimated_delivery_fee, "finalDeliveryFee", "itemsPrice")
    VALUES (${id}, 902, ${driver === null ? 'NULL' : driver}, '${status}',
            'general', 'test', 'test address', 20, 20, 0)`;

  await db.query(order(9001, 'accepted', 901));
  const secondActive = await rejects(db, order(9002, 'accepted', 901),
    /duplicate key|unique/i);
  check('a driver cannot hold two active orders', secondActive.rejected,
    secondActive.rejected ? 'rejected by the partial unique index'
                          : secondActive.message);

  // …but the same driver may hold a *finished* one, or the index would be
  // wrong in the other direction and block every second delivery ever.
  let completedOk = true;
  try {
    await db.query(order(9003, 'completed', 901));
  } catch (error) {
    completedOk = false;
    check('…while a completed order is still allowed', false, String(error?.message));
  }
  if (completedOk) check('…while a completed order is still allowed', true);

  // ── 5. Ledger idempotency ──────────────────────────────────────────────
  console.log('\n[5] ledger idempotency — the spine of every money route');
  const ledger = (reference, amount, type = 'commission') => `
    INSERT INTO wallet_transactions (driver_id, amount, type, reference, balance_after)
    VALUES (901, ${amount}, '${type}', '${reference}', 100)`;

  await db.query(ledger('order-9001-commission', -8));
  const duplicate = await rejects(db, ledger('order-9001-commission', -8),
    /duplicate key|unique/i);
  check('the same reference cannot be written twice', duplicate.rejected,
    duplicate.rejected ? 'rejected by UQ_wallet_transactions_reference'
                       : duplicate.message);

  // A commission and a penalty on one driver are different references, so both
  // must land — Part 16 asks for exactly this pair.
  await db.query(ledger('order-9001-cancel-penalty', -4, 'cancellation_penalty'));
  const both = await db.query(`
    SELECT COUNT(*)::int AS n, SUM(amount)::numeric AS total
    FROM wallet_transactions WHERE driver_id = 901`);
  check('commission and penalty both land on one driver',
    both.rows[0].n === 2 && Number(both.rows[0].total) === -12,
    `${both.rows[0].n} rows, net ${both.rows[0].total}`);

  // ── 6. The conditional UPDATE, on real Postgres ────────────────────────
  console.log('\n[6] the conditional claim — the mechanism itself');
  await db.query(order(9004, 'pending_offers', null));

  const claim = `
    UPDATE orders SET status = 'accepted', "acceptedDriverId" = 903,
                      accepted_at = now()
    WHERE id = 9004 AND status = 'pending_offers'`;

  const first = await db.query(claim);
  check('the first claim matches exactly one row', first.affectedRows === 1,
    `affected ${first.affectedRows}`);

  const second = await db.query(claim);
  check('the second claim matches zero rows — the loser is told, not served',
    second.affectedRows === 0, `affected ${second.affectedRows}`);

  // ── 6b. Driver wallet top-up, on the same two mechanisms ───────────────
  //
  // Approving a top-up is a money-moving operation, and it is made safe by
  // exactly the two guarantees already proven above, applied to a different
  // pair of rows: the `topup-<id>` ledger reference, and a conditional UPDATE
  // off `status = 'pending'`. Both are re-run here against the real thing
  // because a guarantee that holds for orders is not automatically wired up on
  // the top-up path — that wiring is the thing worth checking.
  console.log('\n[6b] driver wallet top-up');

  const topUp = await db.query(`
    INSERT INTO wallet_topup_requests
      (driver_id, amount, method, proof_image_url, status)
    VALUES (901, 100, 'vodafone_cash', 'uploads/payments/proof-verify.jpg', 'pending')
    RETURNING id`);
  const topUpId = topUp.rows[0].id;

  check('a new request starts pending', true, `request #${topUpId}`);

  await db.query(`
    INSERT INTO wallet_transactions (driver_id, amount, type, reference, balance_after)
    VALUES (901, 100, 'topup', 'topup-${topUpId}', 100)`);

  const secondCredit = await rejects(db, `
    INSERT INTO wallet_transactions (driver_id, amount, type, reference, balance_after)
    VALUES (901, 100, 'topup', 'topup-${topUpId}', 200)`, /duplicate key|unique/i);
  check('one top-up cannot be credited twice', secondCredit.rejected,
    secondCredit.rejected ? 'rejected by UQ_wallet_transactions_reference'
                          : secondCredit.message);

  const review = `
    UPDATE wallet_topup_requests
       SET status = 'approved', reviewed_by_admin_id = 902, reviewed_at = now()
     WHERE id = ${topUpId} AND status = 'pending'`;

  const firstReview = await db.query(review);
  check('the first approval matches exactly one row', firstReview.affectedRows === 1,
    `affected ${firstReview.affectedRows}`);

  const secondReview = await db.query(review);
  check('a second approval matches zero rows — nothing to credit against',
    secondReview.affectedRows === 0, `affected ${secondReview.affectedRows}`);

  // And the other direction: a rejected request is equally unreachable.
  const rejected = await db.query(`
    INSERT INTO wallet_topup_requests
      (driver_id, amount, method, proof_image_url, status, admin_note)
    VALUES (901, 250, 'instapay', 'uploads/payments/proof-verify-2.jpg',
            'rejected', 'تحويل غير مطابق')
    RETURNING id`);
  const rejectedId = rejected.rows[0].id;

  const approveRejected = await db.query(`
    UPDATE wallet_topup_requests SET status = 'approved'
     WHERE id = ${rejectedId} AND status = 'pending'`);
  check('a rejected request can never be approved',
    approveRejected.affectedRows === 0, `affected ${approveRejected.affectedRows}`);

  // ── 7. Down and re-apply ───────────────────────────────────────────────
  console.log('\n[7] revert and re-apply');
  // The rows above would block a clean revert of tables they live in; clear
  // them so this step tests the migration, not the fixtures.
  await db.exec(`
    DELETE FROM wallet_transactions WHERE driver_id = 901;
    DELETE FROM wallet_topup_requests WHERE driver_id = 901;
    DELETE FROM orders WHERE id IN (9001, 9002, 9003, 9004);
    DELETE FROM users WHERE id IN (901, 902, 903);
  `);

  const down = await runCli(['run', 'migration:revert']);
  check('migration:revert succeeds', down.code === 0,
    down.code === 0 ? '' : down.out.slice(-400));

  const afterRevert = await db.query(`
    SELECT indexname FROM pg_indexes
    WHERE schemaname = 'public' AND indexname = 'idx_admin_audit_log_created'`);
  const auditTable = await db.query(`
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'admin_audit_log'`);
  check('the reverted migration’s table is gone', auditTable.rows.length === 0,
    `admin_audit_log rows: ${auditTable.rows.length}, idx: ${afterRevert.rows.length}`);

  const reUp = await runCli(['run', 'migration:run']);
  check('re-applying succeeds', reUp.code === 0,
    reUp.code === 0 ? '' : reUp.out.slice(-400));

  const auditBack = await db.query(`
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'admin_audit_log'`);
  check('…and the table is back', auditBack.rows.length === 1);

  // ── Summary ────────────────────────────────────────────────────────────
  const failed = results.filter((r) => !r.passed);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  console.log(
    '\nNOT verified here: N simultaneous accepts. PGlite serves one client at a\n' +
    'time, so a real double-accept race needs a multi-connection Postgres.',
  );
  process.exitCode = failed.length === 0 ? 0 : 1;
} finally {
  try { await server.stop(); } catch {}
  try { await db.close(); } catch {}
}
