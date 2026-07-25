# Wasl (وصل) — Full Project Audit Report

**Date:** 2026-07-25
**Scope:** `wasl_app` (Flutter customer/driver/merchant app) + `Wasl_backend_database` (NestJS + PostgreSQL/TypeORM)
**Baselines established:**
- Backend `npm run build` → **passes** (0 errors)
- Flutter `flutter analyze` → **186 issues, all `info`** (compiles; no errors/warnings)
- Toolchain: Flutter installed, Node v24, npm 11, Postgres target `wasl_delivery_db`

> This is an analysis-only document. No source files were modified to produce it.

---

## 1. What actually exists today (working / partially working)

### Backend (NestJS)
| Module | State | Notes |
|---|---|---|
| `auth` | Working | register (multipart + docs), login (bcrypt + JWT), social-check, delete-by-phone |
| `orders` | Working (core) | create order, offers, accept, status transitions, notifications, driver wallet debit, auto-cancel cron |
| `admin` | Working | approvals review — **only module with JWT + Roles guards** |
| `categories` | Stub | returns a **hardcoded array** (8 categories) |
| `stores` | **Fake** | `/stores/nearby` **fabricates 4 fictitious stores** around the caller's GPS |
| `users` | Partial | status lookup by phone |
| `delivery` | Entity only | no controller/service/module — driver logic lives inside `orders` |
| `merchant` | **Entity only** | **no controller, service, or module** — merchants cannot log in and manage anything |

### Frontend (Flutter) — ~40 screens present
- Auth: onboarding, splash, login, register, OTP (Firebase), forgot/reset password, delivery identity, merchant register, pending screen.
- Customer: home, category details, order-anywhere flow (category → location → map picker → details form → summary → invoice), cart-orders (offers, tracking, success/failure), profile (wallet, offers, help, settings), notifications.
- Driver: home, marketplace, order details, job execution, bid dialog, orders, earnings/payment, profile, rating.
- Services: only **2** (`auth_service.dart`, `orders_service.dart`). Theme `AppColors`, `UserProvider`.

---

## 2. Critical issues (must fix for a real MVP)

### 2.1 Security — Broken Access Control (highest priority)
- **No JWT guard on any `orders`, `users`, `stores`, or `categories` endpoint.** Every order route trusts a `customerId`/`driverId` passed in the URL or body. Any client can read/modify **any** user's orders, submit offers as any driver, top-up any wallet, delete any driver account, or mark any order completed. The `JwtAuthGuard` exists but is applied **only** in `admin`.
- **Hardcoded DB password** committed in `app.module.ts` (`147258369`) and a plaintext `Database pass.txt` at repo root.
- **No input validation** globally: `main.ts` does not register a `ValidationPipe`; DTOs largely unused/loose (`@Body() body: any`-style objects in the orders controller).
- Payment "webhook" (`/orders/payment/webhook`) has **no signature/verification** — anyone can POST `{status:'success'}` to credit any wallet.

### 2.2 Location system — not real (contradicts requirement #1)
- **Drivers have no location fields at all.** `DeliveryPartner` has `isOnline`, `balance`, `rating` but **no `latitude`/`longitude`/`lastUpdated`**. "Nearest driver" is impossible today.
- Order notifications go to **all** online drivers regardless of distance (no radius search).
- Backend **hardcodes Kom Hamada fallback coordinates** (`30.463284, 30.702954`) in `orders.service.createOrder`.
- `/stores/nearby` returns **invented stores** with fake distances — there is no `Store`/`Product` table backing it.
- No PostGIS, no geospatial index, no distance/ETA calculation between driver and pickup.
- Order model stores a **single** `latitude/longitude` (delivery only). Requirement needs **pickup + destination** coordinates for "order from anywhere".

### 2.3 Delivery pricing engine — does not exist (contradicts requirement #2)
- No `DeliveryPricingService`. Delivery fee is whatever a driver bids (offer model), with **no distance-based base pricing**.
- **Commission is hardcoded to a flat `5`** (`calculateWaslCommission()` returns `5` regardless of fee). Requirement asks for a **configurable percentage** (e.g. 20%). There is a correct percentage formula sitting in **commented-out dead code**.
- No admin-configurable pricing/commission settings table.

### 2.4 OTP — Firebase, not WhatsApp (contradicts requirement #3)
- OTP is done entirely client-side via **Firebase Phone Auth**; the backend never sends or verifies OTP and there is **no `OtpService` abstraction**. Requirement asks for a provider-agnostic WhatsApp OTP (`sendOtp`/`verifyOtp`).
- Register endpoint trusts the client's claim of a verified `firebaseUid` — the server never checks it.

### 2.5 Marketplace (Order Type 1) — not functional
- **No `Store`, `Product`, `CartItem`, or `Order-line-item` entities.** There is no product catalog, inventory, or store listing backed by the DB.
- Categories are hardcoded; stores are fabricated. A customer cannot actually browse a real store and buy real products.
- Merchant role can register but has **no way to add products or receive/manage store orders**.

### 2.6 Missing customer features (listed in brief, absent in code/DB)
No backend tables or endpoints for: **saved addresses**, **favorites**, **coupons/promo codes**, **customer wallet** (only driver wallet exists), **search**. The Flutter screens for wallet/offers exist but have no real backend.

---

## 3. Architecture & code-quality problems

- **Massive commented-out dead code.** Nearly every backend and Flutter file contains one or more **entire previous versions of the file** pasted as comments (e.g. `order.entity.ts`, `orders.service.ts`, `orders.controller.ts`, `auth_service.dart`, `main.dart`). This is hundreds of lines of noise per file and a maintenance hazard.
- **Driver domain logic lives in `OrdersService`** (online status, wallet top-up, rating, profile delete). Should be a proper `DeliveryModule`/`DriverService`.
- **No global `ValidationPipe`**, inconsistent DTO usage, `any`-typed request bodies.
- **`synchronize: true`** on TypeORM in production config — dangerous for real data; needs migrations.
- **Two different commission formulas** (active flat-5 vs commented percentage) — inconsistent business logic.
- Frontend duplicates `baseUrl` and header logic; only partial migration to `WaslApiConfig`.
- `flutter analyze`: 186 infos — notably several **`use_build_context_synchronously`** (real crash/navigation-bug risk after `await`) and pervasive `print` in production paths.
- File naming: screens use `PascalCase.dart` (lints), inconsistent with Dart conventions (cosmetic; low priority given "keep existing" rule).
- Secrets/config hardcoded rather than `.env` (ConfigModule is imported but barely used).

---

## 4. Missing backend endpoints (needed for MVP)
- `POST /auth/otp/send`, `POST /auth/otp/verify` (provider-agnostic, WhatsApp).
- `PATCH /drivers/:id/location` (live GPS) + `GET /drivers/nearby?lat&lng&radius`.
- `POST /pricing/quote` (distance → fee) via `DeliveryPricingService`.
- Merchant: `POST /merchant/products`, `GET /merchant/orders`, `PATCH /merchant/orders/:id/status`, inventory CRUD.
- Stores/products: real `GET /stores`, `GET /stores/:id/products`.
- Customer: addresses CRUD, favorites, coupons validate/apply, customer wallet.
- Settings: `GET/PATCH /admin/settings` for commission % and pricing tiers.

## 5. Missing / incomplete database tables
- `Store`, `Product`, `OrderItem`, `Address`, `Favorite`, `Coupon`, `WalletTransaction`, `AppSetting` (pricing/commission), driver location columns, order pickup+destination coordinates.

## 6. Missing / broken screens & flows
- Merchant dashboard (product management, incoming orders) — **absent**.
- Real store browsing + product + cart + checkout wired to backend — **not backed**.
- Live driver-on-map tracking for customer — screen references location but no live driver coordinates exist server-side.
- Admin panel — backend approvals exist, but no admin UI (may be out of MVP scope / web).

---

## 7. Security issue summary (ranked)
1. No auth/authorization on order & user endpoints (IDOR across the whole app).
2. Unverified payment webhook can credit any wallet.
3. Hardcoded DB credentials in source + committed password file.
4. No server-side OTP verification (client asserts identity).
5. No global input validation.
6. `synchronize:true` + no migrations.

---

## 8. MVP readiness estimate (as-is)

| Area | Readiness |
|---|---|
| Auth (phone+password+JWT) | 70% (works, but OTP is client-only, no guards) |
| Order-from-anywhere flow | 55% (creates orders, offers, tracking; fake location + pricing) |
| Store/marketplace order | 15% (no real stores/products/cart backend) |
| Driver experience | 60% (offers, wallet, status; no live location/nearest-driver) |
| Merchant experience | 10% (register only) |
| Location system | 15% (client GPS exists; no server geospatial/nearest-driver) |
| Pricing & commission | 20% (flat hardcoded; no engine) |
| Security | 25% |
| **Overall** | **≈ 35%** |

---

## 9. Recommended implementation phases (proposed)

**Phase 0 — Stabilize & secure (no behavior change):** remove dead commented code, add global `ValidationPipe`, move secrets to `.env`, add `JwtAuthGuard` + ownership checks to order/user/driver endpoints, verify payment webhook.

**Phase 1 — Location & pricing engine:** add driver location columns + `PATCH /drivers/:id/location`; `DeliveryModule`; nearest-driver radius search (haversine now, PostGIS-ready); `DeliveryPricingService` (distance tiers) + `AppSetting` for configurable commission %; wire order to pickup+destination coords; radius-scoped driver notifications.

**Phase 2 — WhatsApp OTP:** provider-agnostic `OtpService` (`sendOtp`/`verifyOtp`) with a WhatsApp provider adapter + server-side verification; keep phone+password login.

**Phase 3 — Marketplace:** `Store`/`Product`/`OrderItem` entities; merchant product management + incoming-orders; real stores/products endpoints; wire Flutter store→product→cart→checkout.

**Phase 4 — Customer extras:** addresses, favorites, coupons, customer wallet.

**Phase 5 — Polish:** loading/empty/error states, animations, fix `use_build_context_synchronously`, remove `print`, tests + builds.
