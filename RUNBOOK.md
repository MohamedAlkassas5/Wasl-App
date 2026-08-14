# Wasl — Operations Runbook

What to do when something is wrong, and what to do regularly so that fewer
things go wrong. Written for whoever is on the other end of "the app is down".

Scope note: this covers the **database** and the **running service**. Uploaded
files (`uploads/` — national IDs, vehicle photos, payment proofs) are **not**
covered by anything here; see §5.

---

## 1. What production actually is

| Piece | Where | Notes |
|---|---|---|
| API | Render web service `wasl-backend` | Docker, free plan |
| Database | **Neon** Postgres | The intended production database (DEPLOYMENT.md §1) |
| Admin panel | Static host | Points at the API via `?api=` |

### ⚠️ Known discrepancy — read before touching the database

`render.yaml` declares its **own** Render Postgres (`wasl-db`) and wires
`DATABASE_URL` to it. DEPLOYMENT.md says production is **Neon**. Both are in the
repository and they disagree.

Consequences, which are not cosmetic:

- A blueprint deploy points the app at **Render's** database, not Neon.
- Render's free Postgres has **no automatic backups** and **is deleted 90 days**
  after creation.

**Before an incident, confirm which database the service is actually using** —
read `DATABASE_URL` in the Render dashboard. Restoring into the wrong one is a
second outage on top of the first. Overriding `DATABASE_URL` in the dashboard
with the Neon string is what makes Neon authoritative; a dashboard value beats
the blueprint.

Resolving this properly (removing one of the two) is deployment work outside
CP6-F and should be decided deliberately — deleting a database resource from a
live blueprint destroys the data in it.

---

## 2. Is it up?

```bash
curl -i https://<service>.onrender.com/health
```

| Response | Meaning | Action |
|---|---|---|
| `200 {"status":"ok","database":"up"}` | Serving normally | — |
| `503 {"status":"degraded","database":"down"}` | Process alive, **database unreachable** | §4.1 |
| Connection refused / timeout | Process is not running | Render dashboard → logs → §4.2 |

This endpoint runs a real `SELECT 1`. It is what Render's health check points
at, so a degraded instance stops receiving traffic on its own.

### Finding the logs for one failed request

Every response carries `x-request-id`. Every log line for that request carries
the same value in its `requestId` field, and if Sentry is configured the event
is tagged with it. Ask the reporting user for that header, or read it from the
error body (`{"statusCode":500,"requestId":"…"}`), then search the logs for it.

Logs are JSON, one object per line, when `NODE_ENV=production`.

---

## 3. Backup and restore

### 3.1 Take a backup

```bash
cd Wasl_backend_database
DATABASE_URL='<production connection string>' npm run db:backup -- ./backups
```

Writes `backups/wasl-<timestamp>.dump` (`pg_dump --format=custom`). Requires
PostgreSQL client tools whose version is **>= the server's**; set `PG_DUMP_PATH`
if `pg_dump` is not on `PATH`.

**Do this before every migration deploy and before any restore.**

Neon also provides its own point-in-time restore in the dashboard, which is
faster than these scripts for "undo the last few hours" and needs no local
tooling. These scripts exist so a copy lives somewhere Neon does not control.

### 3.2 Restore

> Destructive. It drops and recreates every object in the target.

```bash
cd Wasl_backend_database
npm run db:restore -- ./backups/wasl-<timestamp>.dump --target='<connection string>'
```

The target is a required argument and deliberately does **not** default to
`DATABASE_URL`. Restoring onto production additionally requires
`--i-understand-this-is-production`.

`pg_restore` frequently exits non-zero over harmless role/extension errors. **Its
exit code is not the test.** §3.3 is the test.

### 3.3 Verify the restore — this step is not optional

A restore that was not checked is a guess.

```bash
psql '<target>' -c "SELECT count(*) FROM users;"
psql '<target>' -c "SELECT count(*) FROM migrations;"
psql '<target>' -c "SELECT name FROM migrations ORDER BY timestamp DESC LIMIT 1;"
psql '<target>' -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';"
```

Then check **content**, not just counts — a restore can produce the right number
of rows with mangled text:

```bash
PGCLIENTENCODING=UTF8 psql '<target>' -t -A \
  -c "SELECT md5(string_agg(name||phone||role, ',' ORDER BY id)) FROM users;"
```

Compare against the same query run before the restore. Arabic text is the thing
most likely to break silently; if names come back as `????`, the data is lost
even though every count matches.

### 3.4 Drill record

This procedure was executed end to end against a real PostgreSQL 17.2 —
backup → drop the entire schema → restore → verify. 23 tables, 3 seeded rows and
18 migration records returned, and the pre/post content fingerprint matched
exactly (`4219d4057ae4179106773347da611aa3`), including Arabic names.

**Re-run the drill whenever the schema changes materially.** A backup procedure
that has not been exercised since the last three migrations is a hypothesis.

---

## 4. Incidents

### 4.1 `/health` says `database: down`

1. Check the provider dashboard (Neon) — is the instance suspended? Neon's free
   tier auto-suspends when idle and takes seconds to wake; a single failing
   probe during wake-up is not an incident.
2. Check connection limits. The free tiers are small, and `DB_POOL_MAX` above
   what the provider allows exhausts them.
3. Confirm `DATABASE_URL` in the dashboard still points where you expect (§1).
4. If the database is gone rather than unreachable, restore: §3.

### 4.2 The service will not start

Read the Render logs. The two startup failures this codebase raises on purpose:

- `CORS_ORIGINS is required in production.` — set it (§1 of DEPLOYMENT.md).
- `JWT_SECRET is required in production and has no default.` — set it. Note
  that changing it invalidates every existing session.

A failed migration also stops startup; migrations run automatically on boot
(`migrationsRun: true`), so the app will not serve against a schema it does not
recognise. That is intentional. Go to §4.3.

### 4.3 Rolling back a bad deploy

**Application rollback and database rollback are different operations with very
different risk. Do not conflate them.**

#### Application / image rollback — low risk, do this first

In the Render dashboard, redeploy the previous successful deploy.

This reverts **code only**. The database keeps whatever migrations the bad
deploy applied. That is usually fine and usually enough: migrations in this
codebase are additive (new tables, new columns, new indexes), and older code
simply ignores a column it does not know about.

**Try this first, always.** It is reversible and it loses nothing.

#### Database migration rollback — high risk, last resort

```bash
cd Wasl_backend_database
npm run migration:show     # what is applied
npm run migration:revert   # reverts exactly ONE migration, the most recent
```

Understand before running it:

- **`down()` destroys data by design.** Reverting a migration that added a table
  or column *drops* it, and everything in it. `RefreshTokens.down()` drops
  `refresh_tokens` — every signed-in user is signed out. That is not a bug in
  the migration; it is what reversing means.
- **It is not symmetric.** `up()` then `down()` does not return you to the prior
  state — it returns you to the prior *schema*, minus any data that lived only
  in what was dropped.
- **One at a time.** Each invocation reverts a single migration. Going back
  three means running it three times and being right three times.
- **Migrations run on boot.** If you revert while the old image is still
  deployed, the next boot **re-applies** the migration immediately. Roll the
  image back *first*, confirm it is serving, and only then revert.
- **Some migrations are not safely reversible at all** — a data-backfill
  migration's `down()` cannot reconstruct what it overwrote.

**Order of operations:**

1. Take a backup (§3.1). Non-negotiable.
2. Roll the image back and confirm `/health` is 200.
3. Only if the schema genuinely blocks the old code, revert one migration.
4. Verify (§3.3).

If in doubt, restoring a backup (§3.2) is more predictable than reverting
migrations, because it lands on a state that provably existed.

---

## 5. What is *not* backed up

**Uploaded files.** National IDs, vehicle photos, store logos and payment proofs
are written to `uploads/` on the container's filesystem. They are:

- **not** in any database backup — nothing in §3 touches them;
- **not durable on Render at all** — the container disk is ephemeral, so they
  are lost on every deploy and every restart, backup or no backup.

A database restore therefore brings back the row referencing a document, and the
document is still gone. Approved drivers' identity documents in particular are
already being lost on each deploy today.

Fixing this means moving uploads to object storage. That work is **CP6-G**, and
its code is complete — see §7. What remains is the live bucket itself, so until
that exists this section still describes reality.

---

## 6. Error monitoring

Sentry reports **5xx only**. 4xx — rejected logins, validation failures, expired
tokens — are the API working correctly and are not reported; they would bury
real bugs and exhaust the quota.

`SENTRY_DSN` unset means Sentry is entirely inert: not initialised, nothing
sent, no network call. That is the state of every local checkout and CI run.
To enable it in production, create a Sentry project and set `SENTRY_DSN` in the
Render dashboard. There is no committed default, on purpose.

Events are tagged with `requestId`, `method` and `route`, so an event maps back
to the exact log lines for that request (§2).

---

## 7. Object storage (Cloudflare R2)

### Status: code complete, **live bucket outstanding**

The application is fully wired for R2. What has **not** happened is verification
against a real Cloudflare bucket, because no R2 account exists yet. Until that
run is done, CP6-G is not complete and uploads are still on ephemeral disk (§5).

| Verified | How |
|---|---|
| ✅ Provider logic | 23 unit tests (`s3-storage.provider.spec.ts`) |
| ✅ Real S3 wire protocol | `verify-r2.js` run against a local S3-compatible server: upload, exists, byte-for-byte retrieve, missing-key false, anonymous read refused, cleanup — 6/6 |
| ✅ End-to-end through the app | Server booted with `STORAGE_DRIVER=s3`; a real upload route stored the object in the bucket (not on disk) and `/uploads` served it back byte-identical |
| ✅ Authorization over object storage | owner 200 · stranger 403 · anonymous 401 · admin 200 · unreferenced 404 |
| ❌ **Cloudflare R2 itself** | **Not done — no account exists.** Nothing below has been proven against real R2 |

An S3-compatible server is not Cloudflare. It does not prove your credentials
work, your bucket exists, R2's error shapes match, or — most importantly — that
your bucket is private. Do not read the green rows above as "R2 works".

### Setting up the bucket

1. Cloudflare dashboard → **R2** → activate (expect to be asked for a payment
   method even on the free tier).
2. **Create bucket** — any name; pick the location hint deliberately, it is
   **permanent**.
3. In the bucket's **Settings**, leave it private:
   - ❌ no **Public Development URL** (`r2.dev`)
   - ❌ no **Custom Domain**
   - ❌ no public access policy

   This is not optional. Every file is served through `GET /uploads`, which runs
   the ownership rules in `FilesService.canRead` before sending a byte. A public
   object URL bypasses all of them — national IDs, prescriptions, payment proofs.
4. **Manage R2 API Tokens** → Create → **Object Read & Write**, scoped to that
   one bucket. Admin rights are not needed; the app never creates or deletes
   buckets. Copy the Access Key ID, Secret Access Key and endpoint — the secret
   is shown once.

### Configuration

Locally, in `Wasl_backend_database/.env` (gitignored — verified via
`git check-ignore`):

```
STORAGE_DRIVER=s3
R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
R2_BUCKET=<bucket name>
R2_ACCESS_KEY_ID=<access key id>
R2_SECRET_ACCESS_KEY=<secret access key>
```

In production, the same keys are set in the **Render dashboard** — `render.yaml`
declares them `sync: false` so no value is ever committed. Note `R2_*` takes
precedence over the `S3_*` aliases; set only one family.

### Verifying a real bucket

```bash
cd Wasl_backend_database && node scripts/verify-r2.js
```

Reads `.env`, never prints a credential, and cleans up after itself. It checks
upload, existence, byte-for-byte integrity, missing-key handling, that the S3
endpoint refuses anonymous reads, and deletion.

It **cannot** see whether a public `r2.dev` or custom domain is enabled — those
URLs are not derivable from the S3 endpoint. Confirm that in the dashboard by
hand; it is the single most important check in this section.

Then repeat the end-to-end run: upload through a real route, fetch it from
`/uploads` as the owner (200), a stranger (403) and anonymously (401).

### Once R2 is live

Uploaded files become durable and are no longer lost on deploy — §5 stops
applying to new uploads. They are still **not** covered by the database backup
in §3; object storage is versioned and replicated by Cloudflare rather than by
`pg_dump`. Existing files already on Render's disk are not migrated: they were
lost on earlier deploys, and CP6-G deliberately defines no migration.
