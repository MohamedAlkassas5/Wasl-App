import { Logger } from '@nestjs/common';
import * as Sentry from '@sentry/node';

/**
 * Error monitoring, and what happens when it is not configured.
 *
 * `SENTRY_DSN` is the only switch. Unset — which is the case for every local
 * checkout, every test run and CI — and this whole module is inert: nothing is
 * initialised, nothing is sent, no network call is ever attempted. That is the
 * same shape the WhatsApp provider already uses for its dev mode, and it is
 * what keeps the DSN out of the repository: there is no committed fallback to
 * accidentally report production errors into someone's personal project.
 *
 * Set it, and unhandled 5xx responses are reported with the request id attached
 * (see `AllExceptionsFilter`), so an error in Sentry can be traced back to the
 * exact log lines for that request.
 */

let enabled = false;

export function initSentry(): boolean {
  const dsn = process.env.SENTRY_DSN?.trim();
  const logger = new Logger('Sentry');

  if (!dsn) {
    logger.log('SENTRY_DSN is not set — error monitoring is disabled.');
    enabled = false;
    return false;
  }

  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV || 'development',
    // Errors only. Performance tracing samples every request and is the usual
    // way a free Sentry quota is exhausted in a day; it can be turned on
    // deliberately later if it is ever wanted.
    tracesSampleRate: 0,
    // The release is what makes "this broke in the deploy an hour ago"
    // answerable. Render exposes the commit as RENDER_GIT_COMMIT.
    release: process.env.RENDER_GIT_COMMIT || undefined,
  });

  enabled = true;
  logger.log('Sentry initialised — 5xx errors will be reported.');
  return true;
}

/** True only when a DSN was configured and `initSentry` has run. */
export function isSentryEnabled(): boolean {
  return enabled;
}

/**
 * Reports an error, if monitoring is on at all.
 *
 * Failing to report must never escalate into a second failure — the caller is
 * already handling an error, and throwing from here would replace a useful 500
 * with an unhandled rejection.
 */
export function reportError(
  error: unknown,
  tags: Record<string, string | undefined> = {},
): void {
  if (!enabled) return;

  try {
    Sentry.withScope((scope) => {
      for (const [key, value] of Object.entries(tags)) {
        if (value) scope.setTag(key, value);
      }
      Sentry.captureException(error);
    });
  } catch {
    // Deliberately swallowed. See above.
  }
}

/** Test seam: lets a spec assert the disabled path without a real DSN. */
export function resetSentryForTesting(): void {
  enabled = false;
}
