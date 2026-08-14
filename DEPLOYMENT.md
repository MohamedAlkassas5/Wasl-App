# Wasl — Deployment Guide

This covers deploying the **backend + database** to a free cloud tier, wiring
the **WhatsApp OTP**, and pointing the **Flutter app** and **admin panel** at it.

> These steps require **your** accounts. I've made everything deploy-ready, but
> creating cloud accounts and clicking "Deploy" must be done by you (I can't log
> into your accounts or create accounts on your behalf).

---

## 1. Database (already on Neon 🎉)
Your `.env` already points `DATABASE_URL` at a **Neon** free-tier Postgres
(`ep-...neon.tech`). That's your free cloud database — nothing more to do, as
long as the instance is active in the Neon dashboard. (If it was paused, resume
it; if you want a fresh one, create a free project at neon.tech and copy its
connection string.)

The schema is owned by **migrations**, not by `synchronize`. TypeORM's
`synchronize` is off (it silently ALTERs and DROPs production columns); the app
runs any pending migrations automatically on boot, so a deploy brings the
database up to date before it starts serving. Check what is applied with
`npm run migration:show`.

> ⚠️ `render.yaml` also provisions a Render Postgres (`wasl-db`) and wires
> `DATABASE_URL` to it, which contradicts using Neon. Override `DATABASE_URL` in
> the Render dashboard with the Neon string to keep Neon authoritative. This
> matters for backups — see [RUNBOOK.md](RUNBOOK.md) §1.

## 2. Backend → Render (free)
The repo includes `Wasl_backend_database/Dockerfile` and `render.yaml`.

1. Push this repo to GitHub.
2. Go to **render.com → New → Blueprint**, pick the repo. It reads `render.yaml`.
3. Render provisions a free web service (and can provision its own free Postgres,
   or keep using Neon by setting `DATABASE_URL` yourself).
4. Set these env vars in the Render dashboard (see `.env.example`):
   - `DATABASE_URL` (your Neon string, if not using Render's DB)
   - `JWT_SECRET` (long random string)
   - `ADMIN_PHONE`, `ADMIN_PASSWORD`
   - `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID` (see §3)
5. Deploy. Your API is at `https://<service>.onrender.com`.

_Alternatives:_ Railway or Fly.io work the same way (Docker + `DATABASE_URL`).

## 3. WhatsApp OTP (free tier)
The backend already has a provider-agnostic OTP service with a **Meta WhatsApp
Cloud API** adapter. To go live:

1. Create a Meta app at **developers.facebook.com** → add **WhatsApp**.
2. Get a **Phone Number ID** and a **permanent access token**.
3. (Recommended) create an approved **authentication template** for the code.
4. Set env vars: `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`,
   `WHATSAPP_OTP_TEMPLATE`, `WHATSAPP_TEMPLATE_LANG=ar`.

Until those are set, OTP runs in **dev mode**: the code is printed to the server
logs instead of being sent — so you can test the full flow for free immediately.

Endpoints: `POST /auth/otp/send` `{ phone }` and `POST /auth/otp/verify`
`{ phone, code }` (issues a JWT on success).

## 4. Flutter app
The API base URL is a **build-time flag**, not a source edit — so the same
checkout builds for local, staging and production without a diff:

```bash
flutter build apk --dart-define=API_BASE_URL=https://<service>.onrender.com
```

Without the flag the app uses `http://localhost:3000` in debug builds. Release
builds have no usable default on purpose, so an APK can never ship silently
pointing at a developer's machine.

## 5. Admin panel
Static — host `wasl_admin_panel/` free on Netlify/Vercel/GitHub Pages, or open
`index.html` locally. Point it at the backend with `?api=https://<backend-url>`.

---

## Local development
```bash
# Backend (uses local Postgres when DATABASE_URL is empty)
cd Wasl_backend_database
npm install
npm run start:dev
```
Local DB config comes from `DB_HOST/DB_PORT/DB_USERNAME/DB_PASSWORD/DB_NAME`
(defaults to localhost / wasl_delivery_db). See `.env.example`.

---

## 6. Operations

Health checks, log correlation, error monitoring, database backup/restore and
rollback procedure are documented separately in **[RUNBOOK.md](RUNBOOK.md)**.

Two things worth knowing before the first production deploy:

- `CORS_ORIGINS` and `JWT_SECRET` are **required** in production — the app
  refuses to boot without them.
- Uploaded files are not durable on Render and are not covered by database
  backups (RUNBOOK.md §5).
