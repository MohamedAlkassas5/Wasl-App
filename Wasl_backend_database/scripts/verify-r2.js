#!/usr/bin/env node
/**
 * Proves an object-storage bucket actually works, end to end.
 *
 *   node scripts/verify-r2.js
 *
 * Reads configuration from `.env` (never from arguments, so a secret cannot end
 * up in shell history). **No credential value is ever printed** — only the
 * bucket name and the endpoint's host.
 *
 * ## Why this drives the real provider
 *
 * It imports `S3StorageProvider` — the exact class the running server uses —
 * rather than talking to the SDK itself. A verification that reimplements the
 * upload proves the verification works, not the application.
 *
 * ## What it checks
 *
 *   1. upload            — save() puts an object
 *   2. existence         — exists() finds it
 *   3. integrity         — it reads back byte-for-byte identical
 *   4. absence           — exists() is false for a key never written
 *   5. privacy           — the object is NOT readable without credentials
 *   6. cleanup           — the test object is removed
 *
 * ## What it cannot check
 *
 * Step 5 proves the **S3 API endpoint** rejects anonymous reads. On Cloudflare
 * R2 a bucket can *also* be exposed through a separate public `r2.dev` domain
 * or a custom domain, and those URLs are not derivable from the S3 endpoint.
 * This script cannot see them. Confirm in the Cloudflare dashboard that the
 * bucket has **no Public Development URL and no custom domain** — that is a
 * human check, and CP6-G depends on it.
 */

const { randomBytes } = require('crypto');

require('ts-node/register');
require('dotenv/config');

const {
  S3StorageProvider,
} = require('../src/storage/s3-storage.provider');
const {
  S3Client,
  DeleteObjectCommand,
} = require('@aws-sdk/client-s3');

/** A genuinely valid 1x1 PNG — the app rejects anything that is not real image bytes. */
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64',
);

const results = [];

function record(name, passed, detail) {
  results.push({ name, passed, detail });
  console.log(`${passed ? '  ✅' : '  ❌'} ${name}${detail ? ` — ${detail}` : ''}`);
}

function requireConfig() {
  const driver = (process.env.STORAGE_DRIVER || '').toLowerCase();
  const endpoint = process.env.R2_ENDPOINT || process.env.S3_ENDPOINT;
  const bucket = process.env.R2_BUCKET || process.env.S3_BUCKET;

  const missing = [
    ['R2_ENDPOINT', endpoint],
    ['R2_BUCKET', bucket],
    ['R2_ACCESS_KEY_ID', process.env.R2_ACCESS_KEY_ID || process.env.S3_ACCESS_KEY_ID],
    [
      'R2_SECRET_ACCESS_KEY',
      process.env.R2_SECRET_ACCESS_KEY || process.env.S3_SECRET_ACCESS_KEY,
    ],
  ]
    .filter(([, value]) => !value)
    .map(([name]) => name);

  if (missing.length) {
    console.error(
      `\n❌ Missing configuration: ${missing.join(', ')}\n\n` +
        'Put these in Wasl_backend_database/.env (which is gitignored).\n' +
        'See RUNBOOK.md §7 for the Cloudflare R2 setup steps.\n',
    );
    process.exit(1);
  }

  if (driver !== 's3') {
    console.warn(
      `⚠️  STORAGE_DRIVER is "${driver || 'unset'}", not "s3". This script tests\n` +
        '   the bucket directly, but the server will not use it until that is set.\n',
    );
  }

  return { endpoint, bucket };
}

async function readAll(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function main() {
  const { endpoint, bucket } = requireConfig();

  // Host only — the endpoint embeds the account id, and the credentials are
  // never touched here.
  console.log(`\nVerifying bucket "${bucket}" at ${new URL(endpoint).host}\n`);

  const provider = new S3StorageProvider();
  const key = `uploads/_verify/verify-${Date.now()}-${randomBytes(4).toString('hex')}.png`;
  let uploaded = false;

  try {
    // 1 — upload
    try {
      await provider.save(key, PNG, 'image/png');
      uploaded = true;
      record('upload', true, `${PNG.length} bytes`);
    } catch (error) {
      record('upload', false, error.message);
      throw error;
    }

    // 2 — existence
    record('exists() finds it', await provider.exists(key));

    // 3 — integrity, byte for byte
    const readBack = await readAll(provider.createReadStream(key));
    record(
      'retrieved byte-for-byte',
      readBack.equals(PNG),
      `${readBack.length} bytes back`,
    );

    // 4 — absence. Guards the branch that turns a missing object into a 404
    // rather than an exception.
    const absent = await provider.exists(
      `uploads/_verify/never-written-${randomBytes(4).toString('hex')}.png`,
    );
    record('exists() is false for a missing key', absent === false);

    // 5 — privacy. The object must not be readable without credentials.
    const publicUrl = `${endpoint.replace(/\/+$/, '')}/${bucket}/${key}`;
    try {
      const response = await fetch(publicUrl, { redirect: 'manual' });
      record(
        'anonymous read is refused',
        response.status !== 200,
        `HTTP ${response.status}`,
      );
      if (response.status === 200) {
        console.error(
          '\n🔴 The object was readable with no credentials. Every ownership\n' +
            '   check in FilesService is bypassable by URL. Do not ship this.\n',
        );
      }
    } catch (error) {
      // A refused connection is also "not publicly readable".
      record('anonymous read is refused', true, `request failed: ${error.message}`);
    }
  } finally {
    // 6 — cleanup. Done with the SDK directly because StorageProvider has no
    // delete(); nothing in the app deletes objects, so the interface has none.
    if (uploaded) {
      try {
        const client = new S3Client({
          region: process.env.R2_REGION || process.env.S3_REGION || 'auto',
          endpoint,
          forcePathStyle: true,
          credentials: {
            accessKeyId:
              process.env.R2_ACCESS_KEY_ID || process.env.S3_ACCESS_KEY_ID,
            secretAccessKey:
              process.env.R2_SECRET_ACCESS_KEY ||
              process.env.S3_SECRET_ACCESS_KEY,
          },
        });
        await client.send(
          new DeleteObjectCommand({ Bucket: bucket, Key: key }),
        );
        record('cleanup', true);
      } catch (error) {
        record('cleanup', false, `leftover object: ${key} (${error.message})`);
      }
    }
  }

  const failed = results.filter((r) => !r.passed);
  console.log(
    `\n${failed.length ? '❌' : '✅'} ${results.length - failed.length}/${results.length} checks passed\n`,
  );

  if (!failed.length) {
    console.log(
      'Bucket-level verification passed. Still required for CP6-G:\n' +
        '  • confirm in the Cloudflare dashboard that no Public Development URL\n' +
        '    and no custom domain are enabled (this script cannot see them);\n' +
        '  • the live end-to-end run through /uploads (owner 200, stranger 403,\n' +
        '    anonymous 401).\n',
    );
  }

  // Set the code and let the process end on its own. Calling process.exit()
  // here tears down handles the SDK is still closing, which on Windows trips a
  // libuv assertion and turns a passing run into a crash at the last line.
  process.exitCode = failed.length ? 1 : 0;
}

main().catch((error) => {
  console.error(`\n❌ Verification aborted: ${error.message}\n`);
  process.exitCode = 1;
});
