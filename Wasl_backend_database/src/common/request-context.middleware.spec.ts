import type { NextFunction, Request, Response } from 'express';

import {
  REQUEST_ID_HEADER,
  RequestContextMiddleware,
} from './request-context.middleware';
import { currentRequestId } from './request-context';

/**
 * The request id is the thread that ties a log line, an error report and a
 * user's complaint together. These pin the two properties that make that work:
 * an id always exists, and an id that arrived with the request is kept rather
 * than replaced.
 */
describe('RequestContextMiddleware', () => {
  let middleware: RequestContextMiddleware;
  let headers: Record<string, string>;

  const requestWith = (inbound?: string): Request =>
    ({
      headers: inbound === undefined ? {} : { [REQUEST_ID_HEADER]: inbound },
    }) as unknown as Request;

  const response = () =>
    ({
      setHeader: (name: string, value: string) => {
        headers[name] = value;
      },
    }) as unknown as Response;

  beforeEach(() => {
    middleware = new RequestContextMiddleware();
    headers = {};
  });

  it('generates an id when the caller did not send one', () => {
    let seen: string | undefined;
    middleware.use(requestWith(), response(), (() => {
      seen = currentRequestId();
    }) as NextFunction);

    expect(seen).toBeTruthy();
    expect(seen).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('keeps an inbound id so the caller and server tell one story', () => {
    let seen: string | undefined;
    middleware.use(requestWith('from-the-load-balancer'), response(), (() => {
      seen = currentRequestId();
    }) as NextFunction);

    expect(seen).toBe('from-the-load-balancer');
  });

  it('echoes the id back, which is what makes a failure reportable', () => {
    middleware.use(requestWith('abc-123'), response(), (() => {}) as NextFunction);

    expect(headers[REQUEST_ID_HEADER]).toBe('abc-123');
  });

  it('gives each request its own id', () => {
    const ids: (string | undefined)[] = [];
    const capture = (() => ids.push(currentRequestId())) as NextFunction;

    middleware.use(requestWith(), response(), capture);
    middleware.use(requestWith(), response(), capture);

    expect(ids[0]).not.toBe(ids[1]);
  });

  it('ignores a blank inbound id rather than propagating emptiness', () => {
    let seen: string | undefined;
    middleware.use(requestWith('   '), response(), (() => {
      seen = currentRequestId();
    }) as NextFunction);

    expect(seen).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('caps a hostile id — it lands in every log line for the request', () => {
    let seen: string | undefined;
    middleware.use(requestWith('x'.repeat(5000)), response(), (() => {
      seen = currentRequestId();
    }) as NextFunction);

    expect(seen).toHaveLength(200);
  });

  it('leaves no context behind once the request is done', () => {
    middleware.use(requestWith(), response(), (() => {}) as NextFunction);

    // Work that is not a request — the seeder, a cron tick — must not inherit
    // the id of whatever request happened to run before it.
    expect(currentRequestId()).toBeUndefined();
  });
});
