# Wasl (وصل) — Full Project Audit Report

**Date:** 2026-07-25 (re-verified)
**Scope:** `wasl_app` (Flutter) + `Wasl_backend_database` (NestJS + PostgreSQL/TypeORM) + `wasl_admin_panel` (static HTML/JS)

## Verification actually performed this pass

| Check | Result |
|---|---|
| `npm install` (backend) | ✅ 798 packages, 6 vulns (1 moderate, 5 high) |
| `npm run build` (backend) | ✅ **passes, 0 errors** |
| Boot `node dist/main.js` | ✅ **full Nest DI graph initializes** (AppModule, TypeOrm, Jwt, Config, Schedule, Categories, Stores, Http…). Stops only at the DB TCP connect — no Postgres reachable on this machine. |
| Postgres via Docker | ⚠️ Not possible here — Docker daemon would not start. |
| `flutter analyze` | ⚠️ **Not run** — Flutter SDK is not installed on this machine (`C:\src\flutter` from `codes.txt` does not exist). Flutter findings below are from static code review only. |

> **Conclusion on "does the backend build and run":** Yes. It compiles with zero
> errors and the application itself boots cleanly; it only needs a reachable
> Postgres (the Neon instance per `DEPLOYMENT.md`).

---

## ⚠️ Correction to the previous version of this report

The earlier report described a backend that no longer exists. **Phases 0–2 of its
own recommendations have since been implemented.** The following claims are now
**OUT OF DATE and false**:

| Old claim | Reality today |
|---|---|
| "No JWT guard on any orders/users endpoint" | ❌ Wrong — `@UseGuards(JwtAuthGuard)` covers the **whole** orders controller, plus `drivers`, `wallet`; admin routes add `RolesGuard`. |
| "No global ValidationPipe" | ❌ Wrong — registered in `main.ts` with `whitelist` + `transform`. |
| "Hardcoded DB password in app.module.ts" | ❌ Wrong — reads `DATABASE_URL` / env; only a dev-only localhost fallback remains. |
| "Drivers have no location fields" | ❌ Wrong — `currentLatitude`, `currentLongitude`, `lastLocationUpdate`, `availabilityRadiusKm` exist; `DeliveryService` does haversine nearest-driver with expanding radius. |
| "Commission hardcoded to flat 5" | ❌ Wrong — `PricingService.commissionForFee()` uses a configurable `COMMISSION_PERCENT` setting. |
| "No pricing engine" | ❌ Wrong — `PricingService` has distance tiers (city/nearby/far), all admin-editable. |
| "OTP is Firebase, no OtpService" | ❌ Wrong (now) — provider-agnostic `OtpService` + Meta WhatsApp adapter + `/auth/otp/send|verify|reset-password`, and the Flutter app calls them. Firebase phone auth is gone from `lib/` (§2.4). |
| "Payment webhook can credit any wallet" | ❌ Wrong — self-service top-up now throws; crediting goes through admin-verified `WalletTopUpRequest` + an auditable `WalletTransaction` ledger. |
| "Order stores only one coordinate pair" | ❌ Wrong — pickup **and** destination coords, plus `distanceKm` and `estimatedDeliveryFee`. |

---

## 1. What genuinely exists and works today

### Backend (NestJS) — 13 modules registered in `app.module.ts`
| Module | State | Notes |
|---|---|---|
| `auth` | ✅ Working | register (multipart + docs), bcrypt login, JWT, rate-limited; social-check disabled (§2.6a) |
| `otp` | ✅ Working | `OtpService` + `MetaWhatsappProvider`; dev mode logs the code |
| `orders` | ✅ Working | create, offers, accept, status machine, radius-scoped notifications, commission debit, auto-cancel cron |
| `delivery` | ✅ Working | driver GPS persistence, haversine nearest-driver, expanding-radius search |
| `pricing` | ✅ Working | distance tiers + configurable commission % + min-wallet rule |
| `payments` | ✅ Working | top-up requests, admin approve/reject, wallet ledger |
| `settings` | ✅ Working | admin-editable runtime settings (`AppSetting`) |
| `admin` | ✅ Working | approvals, registrations, dashboard stats; JWT + Roles guarded |
| `users` | ⚠️ Partial | only own-account status; now JWT-guarded |
| `categories` | ⚠️ Stub | hardcoded array |
| `stores` | ⚠️ Real but empty | now queries approved merchants by distance; returns `[]` until merchants exist (§2.1) |
| `merchant` | ❌ **Entity only** | no controller/service/module; **not imported** in `app.module.ts` |

### Frontend (Flutter) — ~40 screens
Auth (onboarding, splash, login, register, OTP, forgot/reset, driver identity, merchant register, pending), Customer (home, categories, full order-anywhere flow, cart-orders, offers, tracking, profile/wallet/offers/help/settings, notifications), Driver (home, marketplace, order details, job execution, bid dialog, orders, earnings, profile, rating). 5 services incl. `whatsapp_otp_service.dart` and `location_api_service.dart`.

### Admin panel (static, 277 lines JS)
Covers: dashboard, registrations, approvals review, top-up requests approve/reject, driver wallet credit, settings read/write. **No** orders/customers/stores management UI.

---

## 2. Remaining blockers for launch

### 2.1 Fabricated stores ✅ FIXED (now real, and honestly empty)
`stores.service.ts` **invented 4 fictional shops** around the caller's GPS on
every call ("مطعم وكافيه الشرقاوي", "صيدلية العزبي"…) by nudging their own
coordinates and calling the offset a distance. The customer app then had its own
hardcoded fallback list on top of that, so the home screen looked populated no
matter what was in the database — and tapping a "store" led nowhere.

`/stores/nearby` is now backed by the real `merchants` table: approved merchants
that have coordinates, haversine distance, nearest-first, inside a configurable
`store_search_radius_km` (default 10, admin-editable). No merchants near you →
an empty array. The route is JWT-guarded.

On the app side the fallback list is gone; the home screen shows a proper empty
state ("لا توجد متاجر شريكة في نطاقك حالياً…"), distinguishing *no GPS*, *none
nearby*, and *connection failed*. The store card also stopped printing invented
numbers — a fixed 4.7 rating, `distance×10+5` minutes and a `distance×5+10` EGP
fee that **contradicted the real pricing engine**. Name, type and real distance
only, until those have a genuine source.

Still missing (Track B): `store.entity.ts` is an empty `export class Store {}`,
there is no product catalog, and merchants have no way to be created with
coordinates yet — so in practice this endpoint returns `[]` until the merchant
side exists. That is the honest state, which is the point.

### 2.2 Merchant side does not exist 🔴
`Merchant` entity is complete, but there is **no MerchantModule, controller, or
service**, and it is not imported into `app.module.ts`. A merchant can register
from the app and then do **nothing** — no product management, no incoming
orders. The whole "Order Type 1 (Prepaid / from a registered store)" journey in
the vision document is unimplemented.

### 2.3 No product catalog / cart 🔴
No `Product`, `OrderItem`, or `CartItem` entities. Marketplace ordering
(browse store → pick products → cart → checkout) has no backing whatsoever.

### 2.4 App used Firebase OTP, not the backend's WhatsApp OTP ✅ FIXED
`whatsapp_otp_service.dart` existed and was correct, but no screen imported it —
`WaslRegisterScreen` and `WaslForgotPasswordScreen` called
`FirebaseAuth.verifyPhoneNumber`, so the server-side OTP path was built but dark.

Wiring it up surfaced that **the OTP step was decorative on the server too**:
`POST /auth/register` never checked that the phone had passed any verification,
so anyone could POST straight to it with a stranger's number and own that
identity. That is the substantive fix here; the client rewiring is the visible
half.

**Server**
- `AuthService.register` now refuses a phone that does not hold a fresh
  verification, and burns the verification once the account is created — one
  code, one account.
- A successful verification is time-boxed (`verified_at` + a 30-minute window,
  wide enough for a delivery partner to finish uploading documents). Previously
  `verified` was a permanent flag; a phone verified weeks ago still counted.
- New `POST /auth/otp/reset-password` (phone + code + newPassword, 10 / 10 min
  per IP). It re-proves the code, then rehashes the password and consumes the
  verification. Unknown phones get the same success response as known ones, so
  it can't be used to test which numbers have accounts.

**App**
- `WaslRegisterScreen`, `WaslForgotPasswordScreen` → `WhatsappOtpService.sendOtp`.
- `WaslOtpScreen` → `verifyOtp`, then routes on the server's answer: existing
  account during signup → "log in instead"; customer → register immediately;
  delivery → documents screen, which registers after upload.
- **"Resend code" actually resent nothing** — it only restarted the countdown.
  It now calls the server and clears the entered digits.
- `firebase_auth` is no longer imported anywhere in `lib/` (`firebase_core`
  stays for FCM). The unused package is still in `pubspec.yaml`.

### 2.4a Password reset was theatre 🔴 ✅ FIXED
`WaslResetPasswordScreen` showed "تم تحديث كلمة المرور بنجاح! 🎉" and popped to the
root **without calling anything**. No reset endpoint existed. Every user who
"reset" their password still had the old one — and would be locked out believing
otherwise. It now calls `/auth/otp/reset-password` and reports the real result.

### 2.4b Fake social login removed 🔴 ✅ FIXED
The Facebook / email buttons on the login and register screens never did any
social sign-in: they sent a **hardcoded** address (`ahmed_google@wasl.com`) to
`/auth/social-check`, which minted a JWT for whatever account matched. The route
was already disabled (§2.6a); the buttons and `socialLoginCheck()` are now gone
too, so nothing calls a dead endpoint.

`WaslSocialCompleteDataScreen.dart` was **deleted**, not just unhooked: it
registered accounts with a **derivable password**
(`'SocialAuth_' + firebaseUid.substring(0,5)`), so anyone who learned a user's
Firebase uid could compute their password. Reviving social login would need
server-side `firebase-admin verifyIdToken`, not that screen. `firebase_auth`
was dropped from `pubspec.yaml` in the same pass (`firebase_core` stays for
FCM) — run `flutter pub get` to refresh `pubspec.lock`.

### 2.5 Authorization: authenticated ≠ authorized ✅ FIXED
`JwtAuthGuard` proved *who you are* but the order routes never checked that the
token's `sub` matched the `customerId`/`driverId` in the path or body — any
logged-in user could read another customer's orders, submit offers as another
driver, rate any driver, or delete any driver account.

Fixed by introducing `src/auth/current-user.ts` (`@CurrentUser()` +
`assertSelfOrAdmin()`) and reworking the controllers so identity always comes
from the token, never the URL: orders (list, status change, offers, accept,
rating, notifications) and driver location updates. ~148 lines of dead routes
(`topup-request`, an unauthenticated `payment/webhook`) were deleted.

### 2.6 Unguarded / unauthenticated endpoints ✅ FIXED
Rate limiting is now global — `ThrottlerModule` + a global `ThrottlerGuard`
(120 req/min per IP baseline), with `trust proxy` set so the real client IP is
used behind Render/Railway. Tighter caps where abuse is cheap:

| Route | Cap |
|---|---|
| `POST /auth/otp/send` | 5 / 10 min per IP (on top of the existing per-phone cooldown + hourly cap) |
| `POST /auth/otp/verify` | 15 / 10 min per IP |
| `POST /auth/otp/reset-password` | 10 / 10 min per IP |
| `POST /auth/login` | 10 / 5 min per IP |
| `POST /auth/register` | 5 / hour per IP |
| `GET /categories` | 30 / min per IP |

Endpoint changes in the same pass:
- `GET /users/status` — was **unauthenticated and took `?phone=`**, happily
  returning the name, id, role and admin notes of any number fed to it: a clean
  user-enumeration oracle. Now `JwtAuthGuard` + resolved from the token's `sub`;
  the phone parameter is gone.
- `POST /pricing/quote` — now behind `JwtAuthGuard` (the response exposes the
  commission split and tier table). The Flutter client already sent the token.
- `GET /categories` — deliberately left public (rendered pre-login, carries no
  user data), rate-limited only.

### 2.6a 🔴 Account takeover via `POST /auth/social-check` — FIXED (route disabled)
Found this pass. The route looked a user up by `email` **OR** `firebaseUid` and,
on any match, returned a signed JWT. Neither value was ever verified, so posting
a known email address returned a working session token for that account — full
takeover with no credential at all. The Flutter side never did real Google/
Facebook sign-in either; it sent a hardcoded `ahmed_google@wasl.com`.

The route now returns `410 Gone`, and the two service methods that existed only
to serve it were deleted. Reinstating social login requires verifying a real
Firebase ID token server-side (`firebase-admin.verifyIdToken`) and trusting only
the uid inside it.

### 2.6b 🔴 Unauthenticated account deletion via `DELETE /auth/:phone` — FIXED
Found this pass. No guard at all: anyone could delete any account by phone
number. Worse, the lookup was a suffix match (`LIKE '%<last 9 digits>'`), so it
could resolve to a *different* account whose number merely ended the same way.
Now `JwtAuthGuard`-protected; a non-admin deletes only themselves (id taken from
the token, `:phone` ignored), and the admin path uses an exact phone match.

### 2.7 Missing customer features 🟡
No tables/endpoints for saved addresses, favorites, coupons, customer wallet, or
search. Flutter screens for wallet/offers exist with no backend behind them.

### 2.8 Operational gaps 🟡
- ~~`synchronize: true` in production — no migrations; schema drift/data-loss
  risk.~~ ✅ **FIXED** — see §2.16.
- No push notifications (FCM) — notifications are DB rows the app must poll.
- No live driver→customer tracking channel (no sockets); tracking is polling.
- ~~Uploaded ID/selfie documents are served from a public, unauthenticated
  `/uploads` static route.~~ ✅ **FIXED** — see §2.9.
- `Database pass.txt` and `codes.txt` (containing plaintext passwords and a
  token) are committed at repo root.
- Backend `.env` is absent; `.env.example` ships a real-looking default password.
- Test suite is now green: **22 tests, 4 suites, all passing** (`npm test`). The
  two Nest CLI scaffolds that used to fail were rewritten as real tests of the
  authorization rules — `orders.controller.spec.ts` (ids come from the token,
  not the URL) and `orders.service.spec.ts` (order-ownership and cross-order
  offer acceptance). Coverage is still thin outside auth.
- `flutter analyze` unverified this pass (SDK not installed here).
- Every backend + Flutter file still carries an entire commented-out previous
  version of itself (hundreds of lines of noise).

### 2.9 Uploaded documents were world-readable ✅ FIXED
`main.ts` mounted `express.static` on `/uploads`, so every national ID scan,
selfie, vehicle photo, order picture, purchase receipt and payment-proof
screenshot was downloadable by anyone who could guess (or enumerate) a filename.
No token, no ownership check.

Replaced by `FilesModule` — `GET /uploads/:filename` and
`GET /uploads/:folder/:filename` behind `JwtAuthGuard`, with per-file ownership:

| Document | Who may read it |
|---|---|
| `uploads/<id/selfie/vehicle/logo>` | the partner or merchant it belongs to |
| `uploads/orders/<item photo>` | the customer, the assigned driver, and any driver while the order is still `pending_offers` (they must see the item to price it) |
| `uploads/invoices/<receipt>` | the customer and the assigned driver only |
| `uploads/payments/<proof>` | the driver who filed that top-up |
| anything | admins (approvals and payment verification are their job) |

Also: filenames restricted to `[A-Za-z0-9._-]`, folders whitelisted, resolved
path re-checked against the uploads root (path traversal), and responses sent
with `Cache-Control: private, no-store`.

The admin panel can't put a header on an `<img src>`, so it now fetches each
document with the token and renders a `blob:` URL — the session token never
appears in a URL, and the blobs are revoked on logout.

### 2.10 The project was not under version control 🔴 ✅ FIXED
Three sub-projects, months of work, no `git` — only an unused `.gitignore`
sitting in the root. Every "can I delete this?" question was being answered
conservatively because nothing was recoverable.

`git init` + an initial commit now exist. Two things were kept **out** of the
first commit, and matter more than the repo itself:

- **`Wasl_backend_database/uploads/` holds 9 real national-ID scans** and
  vehicle photos from actual registrations, plus a directory named after a
  customer's phone number. A plain `git add .` would have written real people's
  identity documents into the repository history permanently — and into GitHub
  the moment a remote was added. Now git-ignored. (§2.9 protects who can
  *fetch* these over HTTP; this is a different exposure with the same blast
  radius. §4 item 7 moves them off local disk entirely.)
- **`Database pass.txt` and `codes.txt`** — git-ignored, but note that ignoring
  is not fixing: the credentials still sit in the working tree, are **still
  readable in older commits** (`git show 350def7:codes.txt` — untracking in
  `8d210aa` didn't purge history), and are presumably still live. The only fix
  is rotation. A concrete rotation checklist now lives in **`SECURITY.md`** at
  the repo root (DB password, admin password, any user passwords in `codes.txt`,
  `JWT_SECRET`, WhatsApp token) with post-rotation verification steps. History
  was intentionally left intact (rewriting it changes every hash, needs a
  force-push, and doesn't help against clones already made).

`.gitignore` also now covers `*.jks` / `*.keystore` / `key.properties`
pre-emptively, so Android signing keys can't be committed later.

### 2.11 Admin account had publicly-known credentials 🔴 ✅ FIXED
`AdminSeederService` fell back to `01000000000` / `WaslAdmin@2026` whenever
`ADMIN_PHONE` / `ADMIN_PASSWORD` were unset. The same pair was **printed on the
admin panel's own login page** (`index.html`, as a "حساب افتراضي" hint), in
`wasl_admin_panel/README.md`, and in `.env.example`. Admin approves delivery
partners and can read every uploaded national ID, so this was the highest-value
credential on the platform, sitting in plain sight.

A second, quieter hole in the same file: the seeder promoted *any* existing
account on the admin phone to `ADMIN`. Since the default was `01000000000` — a
perfectly plausible Egyptian number — a customer who happened to register with
it would have been handed admin on the next boot.

- Both env vars are now **required**, with no fallback. Password must be 12+
  characters, and the leaked value is rejected outright.
- If no admin exists and nothing is configured, the app **refuses to boot**
  rather than inventing an account.
- Removing the fallback protects deployments that haven't booted yet, which
  does nothing for one that already has the leaked account live. So on every
  boot the seeder now checks each admin's hash against the burned password and
  **rotates it** to the configured `ADMIN_PASSWORD`. With nothing to rotate to,
  it refuses to start and says so.
- Promotion of an existing account still happens (the operator set that phone
  deliberately) but is now logged as a warning naming the consequence.
- The hint was removed from the login page, and both READMEs corrected.

⚠️ **Operational**: if the live deployment already seeded that admin, the fix
lands the moment it redeploys **with `ADMIN_PASSWORD` set** — that's what
triggers the rotation. Redeploying without it will refuse to boot, by design.
Verify by trying `01000000000` / `WaslAdmin@2026` against the live API; if it
succeeds today, treat the account as compromised and review what it touched.

### 2.12 🔴 Account takeover via `POST /auth/otp/verify` — FIXED

Found on 2026-07-26, and **demonstrated against a running server** rather than
inferred (see "Verification" below).

`OtpService.verifyOtp` had an idempotency branch: once a record was `verified`,
it returned `true` **without comparing the submitted code at all**. Read on its
own that looks defensible — the comment above it argued for exactly that, and
the 30-minute window is bounded.

It was an account takeover because of a second fact in another file:
`OtpController.verify` hands back a **session JWT** when a verified phone
already has an account, and *that path never consumes the verification*. So
after any legitimate OTP sign-in, the record sat in `verified` state for 30
minutes with nothing burning it, and during that window:

```
POST /auth/otp/verify  {"phone":"<victim>","code":"000000"}
  → 201 {"verified":true,"registered":true,"token":"eyJ..."}   ← full session
GET  /users/status                    (with that token) → 200, victim's account
GET  /orders/customer/<victim>        (with that token) → 200
POST /auth/otp/reset-password {"phone":"<victim>","code":"000000",
                               "newPassword":"..."}     → 200, password replaced
POST /auth/login              with the attacker-chosen password → session
```

Knowing a phone number was the entire attack. No code, no password. Delivery
partners' and admins' numbers are as guessable as anyone's.

**Fix** — the branch still permits genuine idempotent retries (the register or
reset step that follows a verify, or a retried request), but it re-compares the
submitted code against the stored hash and counts failed guesses against
`MAX_VERIFY_ATTEMPTS`. Two regression tests in `otp.service.spec.ts` pin both
halves: a wrong code is rejected after verification, and the real code still
works.

**Verification** — backend built and booted against a real Postgres, and the
sequence above run end-to-end as HTTP:

| Build | Attacker posts `000000` for a verified phone |
|---|---|
| before fix | `201` + working session token → password reset → **account taken over** |
| after fix | `400` ×3 (`000000`, `123456`, `999999`); victim's real code still returns a session |

`npm test` → **49 passed, 8 suites** (was 47).

> Note for future passes: this is the second bug of this exact shape (cf. §2.6a
> `social-check`) — a route that mints a session on evidence it never actually
> checked. Worth grepping for every path that can produce a JWT.

### 2.13 🔴 Committed fallback JWT secret → forgeable admin sessions — FIXED

Found 2026-07-26 while auditing every JWT-minting path (the follow-up the
§2.12 note asked for). `jwt.constants.ts` did:

```ts
export const JWT_SECRET = process.env.JWT_SECRET || 'WASL_SUPER_SECRET_KEY_2026';
```

The guard verifies incoming tokens against this same constant. Render's
blueprint injects a generated `JWT_SECRET`, so Render deploys were fine — but a
**VPS / Railway / plain-`docker run`** deploy that didn't set the env var would
silently fall back to a secret **sitting in the public source tree**. Anyone
with the repo could sign `{sub: <any id>, role: "admin"}` and be that user —
including the admin who reads every uploaded national ID. Same class as §2.11:
a known value used as a live secret.

**Fix** (`jwt.constants.ts`) mirrors the admin-seeder rule — fail closed:
- Production (`NODE_ENV=production`): `JWT_SECRET` is **required** (16+ chars);
  the burned literal is rejected. Missing/weak → the app refuses to boot.
- Dev/test: a random per-process secret is generated when unset (tokens don't
  survive a restart, but nothing guessable is ever trusted; tests sign and
  verify in-process so they're unaffected).

Verified: `NODE_ENV=production` with the var unset → refuses to boot; with the
leaked value → refuses; with a fresh random value → boots. `.env.example`
updated to show it as required with a generator command. Since the constant
was live in git, **rotate `JWT_SECRET` on any existing deployment** — every
token ever signed with the old value is forgeable.

### 2.14 🟡 `CreateOrderDto.customerId` required but ignored — FIXED

`POST /orders/create` overwrites `customerId` with the caller's JWT `sub`
(the §2.5 ownership fix), but the DTO still marked it **required**. Because the
global `ValidationPipe` runs before the handler, a client that (reasonably)
stopped sending a field the server discards would get a confusing
`customerId must be a number` 400 and be unable to create orders at all. Made
it `@IsOptional()` — the value is still ignored, but its absence no longer
breaks the core flow. Confirmed against a live DB: an order now creates with no
`customerId` in the body.

---

## 2.15 End-to-end verification against a real database (2026-07-26)

For the first time the backend was exercised against a **real Postgres** on
this machine — not a mock. Docker still won't start here, so a PGlite instance
(`@electric-sql/pglite` + `-socket`) served the real Postgres wire protocol on
`5432`; the **unmodified** NestJS build connected, `synchronize` created every
table, the admin seeder ran, and the whole "order from anywhere" money journey
ran as live HTTP:

| Step | Result |
|---|---|
| Driver online with empty wallet | ✅ blocked (min-wallet rule) |
| Admin credits wallet → driver online | ✅ ledger entry written |
| Customer creates order (real GPS) | ✅ haversine distance 0.75 km, city-tier fee 20 EGP |
| Stranger reads another customer's orders / offers | ✅ 403 |
| Driver bids → owner accepts (stranger can't) | ✅ 403 for stranger, ok for owner |
| Non-assigned driver advances status | ✅ 403 |
| Assigned driver → completed | ✅ **commission 7 EGP debited via ledger**, balance 100→93 |
| Rating without a completed order together | ✅ 403 |
| Admin reads driver's transaction ledger | ✅ credit + commission entries |

The differentiator flow is genuinely working and correctly authorized, on real
persistence. (Marketplace / merchant side, §2.2–2.3, still unbuilt.)

### 2.16 ✅ `synchronize: true` replaced with migrations

`synchronize: true` lets TypeORM ALTER/DROP live columns on every boot to match
the entities — the classic path from an innocent entity edit to lost production
data. Replaced with an explicit migration workflow:

- `src/database/data-source.ts` — a single `DataSource` shared by the app and
  the TypeORM CLI (via `buildDataSourceOptions()`), so `migration:generate`
  always diffs against the same DB/entity set the app uses; they can't drift.
  `synchronize` is hard-off with a comment saying why it must stay off. Adds an
  optional `DB_POOL_MAX` for managed tiers with low connection caps.
- `app.module.ts` now spreads that config and sets `migrationsRun: true`, so a
  deploy applies pending migrations before serving.
- `src/database/migrations/…-InitialSchema.ts` — the generated baseline: 10
  tables, 9 enums, 6 foreign keys. `up()` only creates; `down()` only drops.
- `package.json` scripts: `migration:generate|run|revert|show`.

**Verified against a real Postgres** (PGlite): generated the migration against
an empty DB, then booted the app on a **fresh** DB with `synchronize` off —
`migration:show` reported `[X] InitialSchema` executed, and the **full order
journey (§2.15) ran 16/16 green** on the migration-built schema, commission
ledger included. `npm test`: 49 passed.

> First deploy note: an **existing** database that was built by `synchronize`
> already has these tables, so `migration:run` would fail trying to re-create
> them. Fake the baseline as applied there once —
> `INSERT INTO migrations(timestamp, name) VALUES (...)` for InitialSchema (or
> `migration:run` only on fresh DBs) — then let later migrations flow normally.

---

## 3. MVP readiness (re-scored)

| Area | Readiness | Δ vs old report |
|---|---|---|
| Auth (phone + password + JWT) | 92% | ↑↑ server-verified WhatsApp OTP end-to-end, real password reset, fake social login removed |
| Order-from-anywhere (the core feature) | 85% | ↑ real coords, real pricing, real matching |
| Driver experience | 80% | ↑ live location, wallet ledger, offers |
| Pricing & commission | 95% | ↑ full configurable engine |
| Payments / wallet | 85% | ↑ admin-verified ledger |
| Admin | 75% | ↑ panel + guarded endpoints; default credentials removed (§2.11) |
| Location system | 85% | ↑ haversine + radius search |
| Store/marketplace ordering | 15% | ↑ no longer fabricated, but nothing to list yet |
| Merchant experience | 5% | — still register-only |
| Security | 90% | OTP-verify takeover (§2.12) and forgeable-JWT fallback (§2.13) closed this pass; still: rotate JWT_SECRET + admin creds on live, secrets in repo |
| **Overall** | **≈ 75%** | ↑ from ≈35% |

**The "order from anywhere" flow — the actual differentiator — is close to
launchable. The classic store-catalog marketplace is not started.**

---

## 4. Recommended path to launch

**Track A — Ship V1 fast (order-from-anywhere only).** The vision doc itself says
V1 = one city, cash only, driver wallet, customer picks from driver offers. That
flow is ~85% done. Remaining work is small:
1. ~~Ownership checks on order/driver routes (§2.5)~~ ✅ done
2. ~~Rate-limit + guard OTP and public endpoints (§2.6)~~ ✅ done
3. ~~Protect `/uploads` document access (§2.9)~~ ✅ done
4. ~~Stop `/stores/nearby` returning fabricated stores (§2.1)~~ ✅ done
5. ~~Wire Flutter to the backend WhatsApp OTP (§2.4)~~ ✅ done
6. Migrations instead of `synchronize:true`; move secrets out of the repo ← **next**
7. Move uploads to object storage (S3/Cloudinary) — Render/Railway disks are
   ephemeral, so approved partners' ID documents vanish on every deploy
8. FCM push notifications

**Track B — Then build the marketplace.** Real `Store` + `Product` + `OrderItem`
entities, a `MerchantModule` (products, incoming orders, status), real
`/stores/nearby` backed by the DB, and the Flutter store→product→cart→checkout
screens. This is the largest single chunk of remaining work.

**Track C — Customer extras.** Addresses, favorites, coupons, customer wallet, search.
