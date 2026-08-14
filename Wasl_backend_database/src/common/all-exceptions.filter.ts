import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';

import { currentRequestId } from './request-context';
import { reportError } from './sentry';

/**
 * The one place an unhandled error is turned into a response.
 *
 * Its job is narrow on purpose: **report** server errors, and otherwise reply
 * exactly as the framework already did. Before this filter existed Nest's
 * built-in handler produced these responses, and a filter that "improved" them
 * would silently change the API contract every client is written against — so
 * the shapes below are deliberate copies, not a redesign.
 *
 * What is new is the reporting rule: 5xx only.
 *
 * 4xx is not an incident. A rejected login, a validation failure, an expired
 * token — those are the API working correctly, and they are by far the most
 * common exceptions this server throws. Reporting them would bury the one real
 * bug of the week under thousands of "user typed the wrong password" events and
 * exhaust the Sentry quota doing it.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('UnhandledError');

  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const requestId = currentRequestId();

      // Logged whether or not Sentry is configured, so a deployment without a
      // DSN still leaves a trace of what broke.
      this.logger.error(
        `${request.method} ${request.url} failed: ${describe(exception)}`,
        exception instanceof Error ? exception.stack : undefined,
      );

      reportError(exception, {
        requestId,
        method: request.method,
        route: request.route?.path ?? request.url,
      });
    }

    // From here down: reproduce the framework's own behaviour.
    if (exception instanceof HttpException) {
      response.status(status).json(exception.getResponse());
      return;
    }

    // An unknown throw must never leak its message — it can carry a connection
    // string, a query, or a stack path. The request id is safe and is what
    // makes the report findable when a user quotes it.
    response.status(status).json({
      statusCode: status,
      message: 'Internal server error',
      requestId: currentRequestId(),
    });
  }
}

function describe(exception: unknown): string {
  if (exception instanceof Error) return `${exception.name}: ${exception.message}`;
  return String(exception);
}
