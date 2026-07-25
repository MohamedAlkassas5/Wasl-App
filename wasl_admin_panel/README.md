# Wasl Admin Panel

A zero-build, static web dashboard for managing the Wasl platform. It talks to
the NestJS backend over its REST API.

## Features
- **Login** with an admin account (seeded on backend boot).
- **Dashboard** — pending drivers/merchants, active drivers, total customers.
- **Registrations** — review driver/merchant applications, view uploaded ID /
  vehicle / store documents (click to enlarge), and **Accept / Request edits /
  Reject** each one.
- **Wallet top-ups** — see driver top-up requests with their payment proof,
  **verify & credit** or **reject**, and **manually credit** any driver's balance.
- **Settings** — edit pricing tiers, commission %, driver search radius, and the
  platform Vodafone Cash / InstaPay numbers — applied live, no redeploy.

## Running it
It's plain HTML/CSS/JS — no build step.

- **Locally:** open `index.html` in a browser, or serve the folder:
  ```bash
  npx serve wasl_admin_panel
  ```
- **Point it at your backend:** by default it calls `http://localhost:3000`.
  For a deployed backend, open it as:
  `index.html?api=https://your-backend-url` (the choice is remembered), or edit
  `API_BASE` at the top of `app.js`.

## Hosting (free)
Being static, it deploys free to Netlify, Vercel, GitHub Pages, or Cloudflare
Pages — just publish this folder. Set the API base via the `?api=` query param
or by editing `app.js`.

## Default admin
Seeded on first backend boot (override with `ADMIN_PHONE` / `ADMIN_PASSWORD`
env vars): **01000000000 / WaslAdmin@2026**. Change the password after first login.
