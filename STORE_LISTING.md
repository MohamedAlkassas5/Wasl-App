# Wasl — Store Listing, Data Safety and Review Checklist (CP-J)

Draft material for the Play Console listing. Nothing here has been submitted.

`[FILL IN]` marks a real-world fact I cannot invent. Everything else is
derived from what the app actually does.

**Language:** Arabic only. The Master Plan is explicit that a half-translated
app should not ship and that Arabic-only is a complete product for this
market, so there is no English listing here. English localisation is a
SHOULD-HAVE, not a launch blocker.

---

## 1. Listing copy (Arabic)

**App name (≤30 chars):** `وصل`

**Short description (≤80 chars):**

```
اطلب أي حاجة من أي مكان في مدينتك، وكابتن وصل يجيبهالك.
```

**Full description (≤4000 chars):**

```
وصل بيوصّلك أي حاجة من أي مكان في مدينتك.

🛵 اطلب من أي مكان
مش لازم المحل يكون مسجّل عندنا. اكتب اللي عايزه، حدّد مكان الاستلام
والتوصيل، وكابتن وصل هيروح يشتريه ويوصّله لحد باب البيت.

🍽️ من المطاعم والمحلات الشريكة
تصفّح المنيو، اختار، وأضف لسلتك — والأسعار زي ما هي في المحل بالظبط.

💰 السعر واضح قبل ما تأكّد
رسوم التوصيل محسوبة من جدول مناطق ثابت ومعلن، وبتشوفها قبل ما تأكّد الطلب.
مفيش مفاجآت على الباب.

💬 كلّم الكابتن
محادثة داخل كل طلب. ولو سعر المشتريات اختلف عن المتوقع، الكابتن بيطلب
موافقتك — ومحدش بيغيّر السعر من غير ما توافق.

📍 تابع طلبك
اعرف الكابتن فين، ووصل لحد فين، لحظة بلحظة.

💵 الدفع كاش عند الاستلام
ادفع للكابتن لما يوصّلك.

🧑‍🔧 وللكباتن
اشتغل بنظامك، استقبل طلبات قريبة منك، وتابع أرباحك ومحفظتك أول بأول.

وصل — مدينتك بين يديك.
```

**Category:** Food & Drink (or Lifestyle) · **Contact:** `[FILL IN]` ·
**Website:** `[FILL IN]` · **Privacy policy URL:** `[FILL IN]`

---

## 2. Data Safety form

This is the part most often filled in wrong. Every row below was checked
against the code, and the **"no"** rows matter as much as the "yes" ones.

### Collected and linked to the user

| Data | Collected | Shared | Optional | Purpose |
|---|---|---|---|---|
| Name | Yes | Yes — with the other party on an order | No | Account, order fulfilment |
| Phone number | Yes | Yes — with the other party on an order | No | Account, OTP, contact during delivery |
| Approximate location (area) | Yes | No | No | Delivery pricing |
| Precise location | Yes — **drivers only, in use** | Yes — the customer sees the driver's position | No, for drivers | Nearby orders, live tracking |
| Delivery address | Yes | Yes — with the assigned driver | No | Fulfilment |
| Photos | Yes — item photos, invoices, payment proofs | Only with the order's participants and admins | Yes | Order detail, receipts, top-up proof |
| Government ID | Yes — **drivers only** | No | No | Identity verification before approval |
| Purchase history | Yes | No | No | Order history and support |
| In-app messages | Yes | With the other party; admins on dispute | Yes | Order chat, cancellation review |
| Wallet transactions | Yes — **drivers only** | No | No | Commission, penalties, top-ups |

### Explicitly NOT collected

- **No payment information.** Cash on delivery only; no card data is
  requested, transmitted or stored anywhere in the app or backend.
- **No background location.** `ACCESS_BACKGROUND_LOCATION` is not declared —
  verified absent from the packaged manifest, not just the source.
- No contacts, no calendar, no SMS, no microphone, no audio recording.
- No advertising or analytics identifiers, and no third-party ad SDKs.
- Nothing is collected for advertising or sold to anyone.

### Security practices

- Encrypted in transit (HTTPS).
- Users can request deletion — in-app and via a public URL.
- Passwords stored as bcrypt hashes.
- Identity documents require authentication and an ownership check to read.

### Permissions the store will ask about

| Permission | Why |
|---|---|
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | Delivery address, and matching drivers to nearby orders |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_LOCATION` | Tracking while a driver is actively delivering |
| `POST_NOTIFICATIONS` | Order status and offer notifications |
| `INTERNET` / `ACCESS_NETWORK_STATE` | Talking to the API |
| `WAKE_LOCK` | Added by Firebase Messaging |

---

## 3. Screenshots — checklist

Play requires **at least 2**; 4–8 is better. All from a **real device**, with
**real data** — no mockups, and no obviously fake store names.

- [ ] Home / order type selection
- [ ] Zone picker with the **server-quoted price visible before confirming**
- [ ] Live order tracking with the driver on the map
- [ ] Order chat, ideally showing a price-approval prompt
- [ ] Order history
- [ ] Driver: an incoming offer with its countdown
- [ ] Driver: wallet and earnings

Feature graphic: 1024×500. App icon: 512×512.

> ⚠️ Screenshots must not show a real person's phone number, address or
> national ID. Use the reviewer test accounts below.

---

## 4. Reviewer test accounts

Play reviewers cannot receive a WhatsApp OTP on your business number, so the
app **must** be reviewable without one. Decide and record how:

`[FILL IN: how a reviewer signs in — a pre-created account with a fixed
password, or a documented test code]`

| Role | Phone | Password |
|---|---|---|
| Customer | `[FILL IN]` | `[FILL IN]` |
| Driver (approved, funded wallet) | `[FILL IN]` | `[FILL IN]` |
| Admin (only if the panel is being reviewed) | `[FILL IN]` | `[FILL IN]` |

Notes to include for the reviewer:

```
[FILL IN: e.g. "The driver account is pre-approved with wallet balance so the
reviewer can go online and accept an order without admin steps."]
```

- [ ] Driver account is **approved** and has balance ≥ `min_wallet_to_go_online`
      — otherwise the reviewer cannot go online and will report the app broken
- [ ] At least one merchant with a real catalog exists, or the home screen is
      empty and looks unfinished
- [ ] Zones and rates seeded, or every order fails to price

---

## 5. Content rating & declarations

- Questionnaire: no violence, no sexual content, no gambling.
- Target audience: adults.
- Ads: none.
- In-app purchases: none.
- **Data deletion URL:** `[FILL IN]` (see ACCOUNT_DELETION.md)

---

## 6. iOS (App Store) — when the account exists

- Bundle id `com.wasl.app` is already set.
- Privacy nutrition labels: mirror §2.
- `NSMicrophoneUsageDescription` is **not** needed — the audio dependency was
  removed in CP-E/S11. If audio is ever restored, that string must come back
  with it or review will reject the build.
- Physical-device testing is mandatory and has **not** been done.
