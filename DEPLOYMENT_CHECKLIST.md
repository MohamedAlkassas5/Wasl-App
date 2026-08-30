# CP-K — Deployment and Staged Release Procedure

The exact sequence to take Wasl from this repository to production.
**Nothing here has been executed.** Every step needs an account, a credential
or a decision that is not in the repository.

Read with [RELEASE.md](RELEASE.md) (build configuration) and
[RUNBOOK.md](RUNBOOK.md) (operating the service once it is live).

---

## Phase 0 — Before anything is uploaded

The backend must be live and correct *before* the first internal build goes
out, or testers hit a dead API and report the app as broken.

### 0.1 Decide the two blocking values

| Value | Why it blocks | Question |
|---|---|---|
| Final `applicationId` **+ a matching `google-services.json`** | Play rejects `com.example.*`; changing the id without re-registering in Firebase silently kills push | **Q-G1** |
| Production API domain | The build-time `--dart-define`, CORS, and the listing | **Q-F1** |

⚠️ These two are coupled to work already done. See RELEASE.md §2 — the id and
the Firebase config file change **together or not at all**.

### 0.2 Resolve the database conflict

`render.yaml` provisions its own Render Postgres while DEPLOYMENT.md declares
Neon authoritative. They disagree today, and RUNBOOK.md §1 explains why that
is not cosmetic: Render's free tier has **no automatic backups and is deleted
after 90 days**.

**Do not delete either resource without deciding deliberately** — removing a
database from a live blueprint destroys the data in it. Pick one, override
`DATABASE_URL` in the dashboard accordingly, and record the choice.

### 0.3 Backend deployment

- [ ] Deploy the container; `migrationsRun: true` applies migrations on boot
- [ ] Secrets set in the platform's secret manager, never in the repo:
      `DATABASE_URL`, `JWT_SECRET` (32+ chars), `ADMIN_PHONE`,
      `ADMIN_PASSWORD` (12+ chars), `WHATSAPP_TOKEN`,
      `WHATSAPP_PHONE_NUMBER_ID`, `STORAGE_DRIVER=s3`, `R2_*`, `SENTRY_DSN`
- [ ] `TRUST_PROXY=true` — without it the rate limiter counts every request as
      one IP and one abusive client throttles everybody
- [ ] `GET /health` returns `200 {"status":"ok","database":"up"}`
- [ ] `npm run migration:show` reports everything applied
- [ ] `node scripts/verify-r2.js` passes against the real bucket (RUNBOOK §7)
- [ ] A backup taken **and a restore rehearsed** (RUNBOOK §3) — an untested
      backup is not a backup
- [ ] Rotate `JWT_SECRET` and the admin password if this deployment ever ran
      with the burned values (SECURITY.md)

### 0.4 The registration blocker

- [ ] WhatsApp Business account approved, with an **approved Arabic OTP
      template**, and a real code delivered end to end

> The OTP code is complete and activates on env vars alone — but with no
> approved template no code is ever delivered, which means **nobody can create
> an account**. Confirm this before you need it, not during rollout.

### 0.5 Real data

- [ ] Zones and zone rates seeded — without them every order fails to price
- [ ] At least one approved merchant with a real catalog, or the home screen
      is empty and looks unfinished
- [ ] Admin account created and its password rotated off any seeded value

---

## Phase 1 — Internal testing

- [ ] Upload keystore created **and backed up** (RELEASE.md §3)
- [ ] Play App Signing enrolled
- [ ] AAB built with the real `--dart-define=API_BASE_URL=...`
- [ ] Confirm it is **not** debug-signed:
      `keytool -printcert -jarfile app-release.aab` must not read `CN=Android Debug`
- [ ] Upload to the Internal testing track
- [ ] Install on a **real device** — not only the emulator

### The journeys that must pass on a real device

Both money paths, end to end, because neither is covered by an automated test
against a real backend:

- [ ] Customer: register → OTP → set area → order → see the **server-quoted
      price before confirming** → track → chat → receive → history
- [ ] Driver: register → upload documents → admin approves → top-up approved →
      go online → receive an offer → accept → at store → invoice + items price
      → customer approves the price change → deliver → **commission debited
      exactly once**
- [ ] Cancellation, both directions: customer requests → driver approves →
      **no penalty** (Q-B3); and driver cancels outright → penalty charged →
      appeal → admin refunds
- [ ] Push arrives on a real device for an offer and an order update
- [ ] Account deletion from inside the app, then re-register with the same
      phone number

---

## Phase 2 — Closed testing

- [ ] Store listing complete in **Arabic and English** (STORE_LISTING.md)
- [ ] Privacy policy and the account-deletion page published at real, public
      URLs and linked in the console
- [ ] Data Safety form completed to match STORE_LISTING.md §2
- [ ] Content rating questionnaire submitted
- [ ] Screenshots from a real device, with no real person's phone number,
      address or identity document visible
- [ ] Reviewer test accounts created and verified working **without** a
      WhatsApp code
- [ ] 12+ testers for the required period, if applying for production access
- [ ] Crashes and ANRs reviewed in the console and in Sentry, and fixed

---

## Phase 3 — Staged production rollout

Roll out gradually. The first real users are the first real load.

- [ ] Start at **5%**
- [ ] Watch for 24–48h: Sentry error rate, `/health`, crash-free sessions,
      and the wallet ledger for anything anomalous
- [ ] 20% → 50% → 100%, pausing at each step for the same window
- [ ] Halt immediately on a spike in crashes, 5xx, or any duplicated ledger
      entry

---

## Phase 4 — Rollback

Decide the trigger in advance, not during an incident.

**Backend** (RUNBOOK.md §4.3): redeploy the previous image. If the bad deploy
included a migration, `npm run migration:revert` **before** the old image
boots — an older build against a newer schema fails in ways that are harder to
diagnose than the original fault.

**App:** Play cannot un-release a version. The rollback is to halt the staged
rollout and ship a fixed build with a higher version code. This asymmetry is
the reason for starting at 5%.

- [ ] Rollback trigger agreed and written down
- [ ] Previous container image known to be retained and deployable
- [ ] Someone is on call for the rollout window

---

## Phase 5 — iOS

Not startable on this machine: it needs an Apple Developer account and a Mac
with Xcode.

- [ ] Apple Developer enrollment (can take days — start early)
- [ ] Register `com.wasl.app`, create the App Store Connect record
- [ ] Signing and provisioning
- [ ] Privacy nutrition labels mirroring STORE_LISTING.md §2
- [ ] Archive and upload from Xcode
- [ ] **Physical-device testing — no iOS device testing has been done at all**

---

## What is already true

Verified in this repository, so it is not on the lists above:

- Background location is gone from **both** platforms, confirmed in the
  packaged Android manifest rather than only in source
- FCM is wired and present in the packaged manifest
- The old placeholder API URL is gone; a release built without a real one
  refuses to start instead of failing quietly
- Release signing reads `key.properties`, which is git-ignored
- Migrations apply, revert and re-apply cleanly on a real Postgres
- `verify-r2.js` and `verify-concurrency.js` are written and runnable, and
  both fail loudly rather than pretending to pass without their dependencies
