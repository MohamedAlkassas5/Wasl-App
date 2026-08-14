#!/usr/bin/env node
/**
 * Takes a backup of the production database.
 *
 *   node scripts/backup-database.js [outputDirectory]
 *
 * Reads `DATABASE_URL` — the same connection string the app uses — and writes a
 * timestamped `pg_dump` archive. Nothing else is read, so this works unchanged
 * against Neon (production), a local Postgres, or any other provider.
 *
 * ## What is and is not in this backup
 *
 * **In:** the entire database — schema, data, and the `migrations` table that
 * records which migrations have run. That last one matters more than it looks:
 * restoring a dump whose `migrations` table disagrees with the deployed image
 * is how a restore turns into a second outage. See RUNBOOK.md.
 *
 * **Out: uploaded files.** National IDs, vehicle photos and payment proofs live
 * on the filesystem under `uploads/`, not in Postgres, so this does not touch
 * them. On Render that disk is ephemeral and those files do not survive a
 * deploy at all. Moving them to object storage is CP6-G; until then, a database
 * restore brings back the row that references a document but not the document.
 *
 * ## Format
 *
 * `--format=custom`, which is compressed and, unlike a plain SQL file, can be
 * restored selectively by `pg_restore`. That flexibility is the whole point on
 * a bad day: it is what lets you pull back one table instead of replacing the
 * entire database.
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

require('dotenv/config');

const PG_DUMP = process.env.PG_DUMP_PATH || 'pg_dump';

function main() {
  const url = process.env.DATABASE_URL?.trim();
  if (!url) {
    fail(
      'DATABASE_URL is not set.\n' +
        'Point it at the database you intend to back up — for production that is\n' +
        'the Neon connection string from the Neon dashboard.',
    );
  }

  const outputDir = path.resolve(process.argv[2] || 'backups');
  fs.mkdirSync(outputDir, { recursive: true });

  // Sortable, and unambiguous across timezones.
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputFile = path.join(outputDir, `wasl-${stamp}.dump`);

  console.log(`Backing up to ${outputFile}`);

  const result = spawnSync(
    PG_DUMP,
    [
      url,
      '--format=custom',
      // Ownership and grants are provider-specific; carrying Neon's role names
      // into a local restore just produces errors about roles that do not exist.
      '--no-owner',
      '--no-privileges',
      `--file=${outputFile}`,
    ],
    { stdio: ['ignore', 'inherit', 'inherit'] },
  );

  if (result.error && result.error.code === 'ENOENT') {
    fail(
      `Could not find "${PG_DUMP}".\n` +
        'Install the PostgreSQL client tools, or set PG_DUMP_PATH to the full\n' +
        'path of pg_dump. The version must be >= the server version.',
    );
  }
  if (result.status !== 0) {
    fail(`pg_dump exited with code ${result.status}.`);
  }

  const { size } = fs.statSync(outputFile);
  if (size === 0) {
    fail('pg_dump produced an empty file — treat this backup as failed.');
  }

  console.log(`✅ Backup complete: ${outputFile} (${formatBytes(size)})`);
  console.log(
    'A backup is not a backup until it has been restored. See RUNBOOK.md §3.',
  );
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

function fail(message) {
  console.error(`\n❌ ${message}\n`);
  process.exit(1);
}

main();
