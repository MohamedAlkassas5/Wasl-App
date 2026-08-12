import { randomBytes } from 'crypto';

/**
 * Single source of truth for the JWT signing secret. The JwtModule and the
 * guard both import this, so signing and verification can never drift apart.
 *
 * There is **no committed fallback secret**. The previous version defaulted to
 * a literal (`WASL_SUPER_SECRET_KEY_2026`) baked into the repo, so any deploy
 * that forgot to set JWT_SECRET verified tokens against a value anyone with the
 * source could read — enough to forge an admin session. Render's blueprint
 * generates one automatically, but a VPS / Railway / plain-Docker deploy would
 * silently fall back to the leaked constant. This mirrors the admin-seeder
 * rule (see AdminSeederService): fail closed rather than trust a known value.
 *
 * - Production (NODE_ENV=production): JWT_SECRET is **required** (16+ chars) and
 *   the burned literal is rejected. Missing/weak → the app refuses to boot.
 * - Dev / test: a per-process random secret is generated when JWT_SECRET is
 *   unset. Tokens don't survive a restart, but nothing guessable is ever
 *   trusted. Tests sign and verify in the same process, so this is transparent.
 */

/** Baked into git history — must never be accepted as a live secret. */
const BURNED_SECRETS = ['WASL_SUPER_SECRET_KEY_2026'];
const MIN_SECRET_LENGTH = 16;

function resolveSecret(): string {
  const configured = process.env.JWT_SECRET?.trim();
  const isProd = process.env.NODE_ENV === 'production';

  if (configured) {
    if (BURNED_SECRETS.includes(configured)) {
      throw new Error(
        'JWT_SECRET is set to a value that was leaked in the repository. ' +
          'Generate a fresh random secret and set JWT_SECRET to it.',
      );
    }
    if (isProd && configured.length < MIN_SECRET_LENGTH) {
      throw new Error(
        `JWT_SECRET must be at least ${MIN_SECRET_LENGTH} characters in production.`,
      );
    }
    return configured;
  }

  if (isProd) {
    throw new Error(
      'JWT_SECRET is required in production and has no default. ' +
        'Set it to a long random string before starting the server.',
    );
  }

  // Dev / test only: a random secret so no committed value is ever trusted.

  console.warn(
    '⚠️  JWT_SECRET is not set — using a random per-process secret. ' +
      'Sessions will not survive a restart. Set JWT_SECRET for stable dev tokens.',
  );
  return randomBytes(48).toString('hex');
}

export const JWT_SECRET = resolveSecret();

export const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '30d';
