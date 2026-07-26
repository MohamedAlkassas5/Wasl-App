#!/usr/bin/env node
/**
 * Prints fresh, strong values for the secrets that must be rotated on every
 * live deployment (see SECURITY.md). It only generates — it never reads,
 * writes, or transmits anything. Copy the output into your host's environment
 * variables, then redeploy.
 *
 *   npm run secrets:gen
 */
const { randomBytes } = require('crypto');

// A 96-char hex JWT secret (48 random bytes). Rotating this invalidates every
// previously issued token, which is the point after the committed-fallback leak.
const jwtSecret = randomBytes(48).toString('hex');

// A 24-char admin password from a URL-safe alphabet, comfortably over the
// 12-char minimum the seeder enforces, and never the burned default.
const alphabet =
  'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^&*';
const pick = (n) =>
  Array.from(randomBytes(n))
    .map((b) => alphabet[b % alphabet.length])
    .join('');
const adminPassword = pick(24);

console.log(`
# --- Fresh secrets (generated locally, never stored) ---
# Paste these into your host's environment, then redeploy.
# Rotating JWT_SECRET forces every existing session to log in again.

JWT_SECRET=${jwtSecret}
ADMIN_PASSWORD=${adminPassword}

# Still to rotate by hand (provider dashboards — this script can't reach them):
#   - Database password  -> update DATABASE_URL / DB_PASSWORD
#   - WhatsApp token      -> regenerate in Meta, set WHATSAPP_TOKEN
# See SECURITY.md for the full checklist and post-rotation verification.
`);
