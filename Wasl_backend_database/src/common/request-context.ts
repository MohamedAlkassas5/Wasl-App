import { AsyncLocalStorage } from 'async_hooks';

/**
 * What is known about the request currently being handled.
 *
 * Kept in `AsyncLocalStorage` rather than passed as an argument because the
 * point is to reach code that has no idea a request exists — a service five
 * calls deep, a logger, an exception filter. Threading a request id through
 * every signature to reach them would be a far larger change to the codebase
 * than the observability it buys.
 */
export interface RequestContext {
  /** Correlates every log line and error report from one request. */
  requestId: string;
}

const storage = new AsyncLocalStorage<RequestContext>();

/** Runs `work` with `context` visible to everything it calls, however deep. */
export function runWithRequestContext<T>(
  context: RequestContext,
  work: () => T,
): T {
  return storage.run(context, work);
}

/**
 * The current request's context, or undefined outside a request.
 *
 * Undefined is normal, not an error: the seeder, migrations on boot and
 * scheduled work all log without ever having been a request.
 */
export function currentRequestContext(): RequestContext | undefined {
  return storage.getStore();
}

/** Shorthand for the one field almost every caller wants. */
export function currentRequestId(): string | undefined {
  return storage.getStore()?.requestId;
}
