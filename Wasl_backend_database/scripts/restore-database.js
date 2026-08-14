#!/usr/bin/env node
/**
 * Restores a backup produced by `backup-database.js`.
 *
 *   node scripts/restore-database.js <dumpFile> --target=<connection string>
 *
 * ## This is destructive
 *
 * It drops and recreates every object it restores. That is what makes it a
 * restore rather than a merge — but it means pointing it at the wrong database
 * destroys that database.
 *
 * So the target is a **required, explicit argument**. It deliberately does not
 * fall back to `DATABASE_URL`: the overwhelmingly common way to lose production
 * is to run a restore that silently defaults to it. Passing the target by hand
 * forces a moment of reading what you typed.
 *
 * Restoring onto production additionally requires `--i-understand-this-is-production`.
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

require('dotenv/config');

const PG_RESTORE = process.env.PG_RESTORE_PATH || 'pg_restore';

function main() {
  const args = process.argv.slice(2);
  const dumpFile = args.find((arg) => !arg.startsWith('--'));
  const target = valueOf(args, '--target');
  const acknowledged = args.includes('--i-understand-this-is-production');

  if (!dumpFile) fail('Usage: restore-database.js <dumpFile> --target=<url>');
  if (!fs.existsSync(dumpFile)) fail(`No such dump file: ${dumpFile}`);
  if (!target) {
    fail(
      'Missing --target=<connection string>.\n' +
        'This is required on purpose. A restore overwrites whatever it points at,\n' +
        'and defaulting to DATABASE_URL is how production gets destroyed.',
    );
  }

  // Not security — the target is supplied by the person running this. It is a
  // speed bump in front of the one mistake that cannot be undone.
  const productionUrl = process.env.DATABASE_URL?.trim();
  if (productionUrl && target === productionUrl && !acknowledged) {
    fail(
      'The target matches DATABASE_URL, i.e. production.\n' +
        'If you really mean to overwrite production, re-run with\n' +
        '  --i-understand-this-is-production\n' +
        'Take a fresh backup of the current state first (RUNBOOK.md §3).',
    );
  }

  console.log(`Restoring ${path.basename(dumpFile)} into the target database…`);

  const result = spawnSync(
    PG_RESTORE,
    [
      `--dbname=${target}`,
      // Drop each object before recreating it, so this works against a database
      // that is not empty.
      '--clean',
      '--if-exists',
      '--no-owner',
      '--no-privileges',
      // Keep going past errors, then report the count. A dump taken with
      // --no-owner always produces some noise about roles; stopping on the
      // first one would abort otherwise-good restores.
      '--exit-on-error=false',
      dumpFile,
    ],
    { stdio: ['ignore', 'inherit', 'inherit'] },
  );

  if (result.error && result.error.code === 'ENOENT') {
    fail(
      `Could not find "${PG_RESTORE}".\n` +
        'Install the PostgreSQL client tools or set PG_RESTORE_PATH.',
    );
  }

  // pg_restore exits non-zero when it emitted any error, including harmless
  // ones. The real check is the verification step below, not this code.
  if (result.status !== 0) {
    console.warn(
      `\n⚠️  pg_restore exited with code ${result.status}. Some statements failed.\n` +
        '   This is common and often harmless (roles, extensions). Do NOT treat\n' +
        '   the restore as successful until you have verified the data.\n',
    );
  }

  console.log('\nRestore finished. Now verify it — a restore that was not');
  console.log('checked is a guess. See RUNBOOK.md §3.3 for what to check.');
}

function valueOf(args, name) {
  const match = args.find((arg) => arg.startsWith(`${name}=`));
  return match ? match.slice(name.length + 1) : undefined;
}

function fail(message) {
  console.error(`\n❌ ${message}\n`);
  process.exit(1);
}

main();
