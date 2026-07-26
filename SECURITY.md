# Wasl — Security & Secret Rotation Checklist

This file tracks secrets that were exposed and **must be rotated on the live
systems**. Rotation — not editing files or rewriting git history — is the only
real fix: once a secret has been committed (and possibly pushed/cloned), assume
someone has a copy. Rewriting it is the only thing that makes that copy useless.

> This document never contains secret values. It names *what* to rotate and
> *where*, not the secrets themselves.

## Why history matters here

`codes.txt` and `Database pass.txt` were removed from tracking in commit
`8d210aa` and are git-ignored now — but they are **still readable in older
commits** (`git show 350def7:codes.txt`). Untracking stops *future* commits; it
does not remove a blob already in history. So the exposure stands until the
secrets are rotated. (History was intentionally left intact — rewriting it
changes every commit hash, needs a force-push, and does nothing about clones
already made.)

## Rotate these (exposed in `codes.txt` / `Database pass.txt` in git history)

- [ ] **Database password** (the Neon/Postgres credential). Change it in the DB
      provider, then update `DATABASE_URL` / `DB_PASSWORD` in the host's env.
      Nothing in the repo should hold it — `.env` is git-ignored.
- [ ] **Admin account password.** The seeder now requires `ADMIN_PASSWORD`
      (12+ chars, the old leaked value is rejected — see AUDIT §2.11). Set a
      fresh one in the host env; on redeploy the seeder rotates the stored hash.
- [ ] **Any real user passwords** that appear in `codes.txt` (test/personal
      accounts). Reset them from the app, or delete those accounts.
- [ ] **`JWT_SECRET`.** Was a committed fallback until AUDIT §2.13. Set a fresh
      random value in the host env. **Every token signed with the old value is
      forgeable** — rotating it invalidates them, forcing a clean re-login.
      Required in production; the app refuses to boot without it.

> Shortcut: `npm run secrets:gen` prints fresh `JWT_SECRET` and `ADMIN_PASSWORD`
> values ready to paste into your host's environment. It only generates — it
> never reads or transmits anything. The DB and WhatsApp secrets still have to
> be rotated in their provider dashboards by hand.
- [ ] **WhatsApp Cloud API token** (`WHATSAPP_TOKEN`), if one was ever committed
      or shared — regenerate it in Meta and set it in the host env.

## After rotating

- [ ] Confirm the old DB password no longer connects.
- [ ] Confirm `01000000000 / WaslAdmin@2026` and any password from `codes.txt`
      no longer log in against the live API.
- [ ] Confirm old JWTs are rejected (any pre-rotation session must re-login).
- [ ] Move `codes.txt` / `Database pass.txt` off disk into a password manager
      once their contents are rotated; they are git-ignored but still sit in the
      working tree as plaintext.

## Standing rules (already enforced in code)

- Secrets come from environment variables only; `.env` is git-ignored and
  `.env.example` ships **blank** required values, not real ones.
- `ADMIN_PHONE` / `ADMIN_PASSWORD` and `JWT_SECRET` are required in production
  with no fallback — the app fails closed rather than inventing a known value.
- `**/uploads/` (real national-ID scans and payment proofs) and Android signing
  keys (`*.jks`, `*.keystore`, `key.properties`) are git-ignored pre-emptively.
