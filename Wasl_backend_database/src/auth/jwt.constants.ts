/**
 * Single source of truth for the JWT signing secret. Reads from the
 * environment in production (JWT_SECRET) and falls back to a dev default so
 * local runs work out of the box. Both the JwtModule and the guard import this,
 * so they can never drift apart.
 */
export const JWT_SECRET =
  process.env.JWT_SECRET || 'WASL_SUPER_SECRET_KEY_2026';

export const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '30d';
