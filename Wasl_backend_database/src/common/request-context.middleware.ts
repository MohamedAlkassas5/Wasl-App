import { Injectable, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'crypto';

import { runWithRequestContext } from './request-context';

/** The header carrying the id, in and out. */
export const REQUEST_ID_HEADER = 'x-request-id';

/**
 * Gives every request an id, and makes it visible for the rest of its life.
 *
 * An inbound `X-Request-Id` is honoured rather than replaced, so an id set by a
 * load balancer or by the Flutter app stitches together with the server's logs
 * instead of splitting the same request into two unrelated stories. Anything
 * else gets a fresh UUID.
 *
 * The id is echoed back on the response, which is what makes a user-reported
 * failure findable: they can quote the id from the failing response and it maps
 * to exact log lines and, when configured, to the Sentry event.
 */
@Injectable()
export class RequestContextMiddleware implements NestMiddleware {
  use(request: Request, response: Response, next: NextFunction): void {
    const requestId = normalise(request.headers[REQUEST_ID_HEADER]) ?? randomUUID();

    response.setHeader(REQUEST_ID_HEADER, requestId);

    runWithRequestContext({ requestId }, () => next());
  }
}

/**
 * Header values arrive as `string | string[] | undefined`, and a client can
 * send anything at all. Length-capped because this value is echoed back and
 * written to every log line for the request — an unbounded one turns a single
 * request into megabytes of logs.
 */
function normalise(value: string | string[] | undefined): string | undefined {
  const raw = Array.isArray(value) ? value[0] : value;
  const trimmed = raw?.trim();
  if (!trimmed) return undefined;
  return trimmed.length > 200 ? trimmed.slice(0, 200) : trimmed;
}
