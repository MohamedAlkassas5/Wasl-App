# Wasl — Release Engineering (CP-I) and Store Readiness (CP-J)

Everything in this file that can be done without a paid account, a real
domain or a signing key **has been done**. What remains is listed under
"What I cannot do for you", with the exact value or action needed.

Nothing here has been submitted, published or uploaded.

---

## 1. What is already wired

| Item | State |
|---|---|
| Release signing config | ✅ Reads `android/key.properties`; falls back to the debug key with a loud Gradle warning when absent |
| `key.properties` / `*.jks` git-ignored | ✅ Verified with `git check-ignore` |
| `applicationId` behind configuration | ✅ `-PwaslApplicationId=<id>`, defaults to the current id |
| Placeholder production API URL removed | ✅ `https://api.wasl.invalid` is gone |
| Release build without an API host | ✅ Refuses to run — shows a red "Build misconfigured" screen at launch |
| AAB builds | ✅ `flutter build appbundle --release` produced a 70.4 MB bundle |
| Background location removed | ✅ Confirmed absent from the *packaged* manifest, not just the source |
| FCM wired | ✅ `FirebaseMessagingService`, `MESSAGING_EVENT`, `POST_NOTIFICATIONS` present in the packaged manifest |
| iOS bundle id | ✅ Already `com.wasl.app` |

### Building a release bundle

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-api-host>
```

The `--dart-define` is **not optional**. Without it the app builds and installs,
then shows a red error screen instead of starting. That is deliberate: the
previous default was a domain that does not exist, so a mis-built release
installed fine and failed every request with "connection failed", which looks
like a network problem rather than a build mistake.

---

## 2. ⚠️ The Firebase / applicationId coupling

`android/app/google-services.json` is registered to **`com.example.wasl_app`**.

Google Play **rejects** `com.example.*`, so the id must change before launch —
and changing it alone silently breaks push notifications, because the Firebase
config file will no longer match the package.

**Both steps, or neither:**

1. Firebase console → this project (`flash-tawseel-app`) → add an Android app
   with the new package name → download the new `google-services.json` →
   replace `android/app/google-services.json`.
2. Set the id, either by editing the default in `android/app/build.gradle`
   (`waslApplicationId`) or by building with `-PwaslApplicationId=<new id>`.

Then rebuild and confirm the packaged manifest still contains
`com.google.firebase.MESSAGING_EVENT`:

```bash
flutter build apk --debug
grep -o "MESSAGING_EVENT" build/app/intermediates/packaged_manifests/debug/processDebugManifestForPackage/AndroidManifest.xml
```

The Master Plan's Q-G1 suggests `com.wasl.app`, to match the iOS bundle id.
**It has not been applied** — it is your decision, and applying it without
step 1 would ship an app that cannot receive notifications.

---

## 3. Signing

Create the upload keystore (once, and back it up — losing it means you can
never update the app under the same listing unless Play App Signing is on):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `wasl_app/android/key.properties` — **never commit it**, it is
already git-ignored:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<absolute path to upload-keystore.jks>
```

The build picks it up automatically. To confirm a bundle is *not* debug-signed:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

The owner must not read `CN=Android Debug`.

---

## 4. Versioning

`pubspec.yaml` currently reads `version: 1.0.0+1`, which is correct for a first
submission. Play rejects a re-upload with an unchanged build number, so bump
the `+N` on **every** upload, including a re-upload of the same version name.

---

## 5. What I cannot do for you

Each of these needs a value, an account or a payment I do not have. None is
blocked on engineering.

| # | Needed | Blocks | Question |
|---|---|---|---|
| 1 | Final applicationId + the matching `google-services.json` | Any Play upload | **Q-G1** |
| 2 | Production API domain, with TLS | The `--dart-define`, CORS, the store listing | **Q-F1** |
| 3 | Upload keystore + passwords | A signed bundle | — |
| 4 | Google Play Console account (one-off fee) | Everything in CP-K | **Q-G3** |
| 5 | Apple Developer account (annual fee) | iOS entirely | **Q-G3** |
| 6 | A Mac with Xcode | The iOS archive — cannot be produced on this machine | — |
| 7 | Cloudflare R2 bucket + credentials | CP-G / S12 live verification | **Q-F2** |
| 8 | Sentry DSN | Error monitoring in production (code is wired) | **Q-F3** |
| 9 | Approved WhatsApp Business Arabic OTP template | **Registration in production.** Without it nobody can sign up | **Q-F5** |
| 10 | Hosting for the privacy policy and deletion pages | CP-J, and a Play requirement | — |
| 11 | Real catalog data — merchants, prices, photos | A useful launch | **Q-E2** |

Item 9 deserves its own line: the OTP code is complete and activates on env
vars alone, but an unapproved template means no OTP is delivered, which means
**no one can create an account**. It is worth confirming early.

---

## 6. Store readiness (CP-J) — what exists

- `PRIVACY.md` — privacy policy, with placeholders marked `[FILL IN]`
- `ACCOUNT_DELETION.md` — the public deletion instructions Play requires
- `STORE_LISTING.md` — Arabic listing copy, Data Safety mapping, screenshot
  checklist, reviewer test-account checklist

Those three carry placeholders wherever a real legal or company fact is
required. **They are deliberately not invented** — a privacy policy naming a
fictitious company is worse than no policy.

---

## 7. Pre-submission checklist

Nothing below has been done.

- [ ] applicationId decided, Firebase re-registered, `google-services.json` replaced
- [ ] Production API live over HTTPS, `/health` returning `200`
- [ ] `JWT_SECRET`, `ADMIN_PHONE`, `ADMIN_PASSWORD` set in the host's secret manager
- [ ] `STORAGE_DRIVER=s3` with real R2 credentials, verified by `npm run` on `scripts/verify-r2.js`
- [ ] WhatsApp OTP template approved and sending
- [ ] `render.yaml` vs Neon resolved (see RUNBOOK.md §1 — they currently disagree)
- [ ] Upload keystore created and backed up
- [ ] AAB built with the real `--dart-define`, confirmed not debug-signed
- [ ] Privacy policy and deletion pages published at real URLs
- [ ] Data Safety form completed to match `STORE_LISTING.md`
- [ ] Screenshots taken from a real device
- [ ] Reviewer accounts created for customer, driver and admin
- [ ] Backup taken and a restore rehearsed (RUNBOOK.md §3)
