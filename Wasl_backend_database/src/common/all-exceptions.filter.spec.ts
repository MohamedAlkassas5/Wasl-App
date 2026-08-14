import {
  BadRequestException,
  HttpException,
  HttpStatus,
  UnauthorizedException,
} from '@nestjs/common';
import type { ArgumentsHost } from '@nestjs/common';

import { AllExceptionsFilter } from './all-exceptions.filter';
import { runWithRequestContext } from './request-context';
import * as sentry from './sentry';

/**
 * The filter has two jobs and must be boring at both: report the errors that
 * are actually incidents, and otherwise answer exactly as the framework did
 * before it existed.
 */
describe('AllExceptionsFilter', () => {
  let filter: AllExceptionsFilter;
  let status: number | undefined;
  let body: unknown;
  let reported: unknown[];

  const host = (url = '/orders', method = 'POST'): ArgumentsHost =>
    ({
      switchToHttp: () => ({
        getResponse: () => ({
          status: (code: number) => {
            status = code;
            return { json: (payload: unknown) => (body = payload) };
          },
        }),
        getRequest: () => ({ url, method, route: { path: url } }),
      }),
    }) as unknown as ArgumentsHost;

  beforeEach(() => {
    filter = new AllExceptionsFilter();
    status = undefined;
    body = undefined;
    reported = [];
    jest
      .spyOn(sentry, 'reportError')
      .mockImplementation((error) => void reported.push(error));
    // The filter logs 5xx; keep the test output readable.
    jest.spyOn(filter['logger'], 'error').mockImplementation(() => undefined);
  });

  afterEach(() => jest.restoreAllMocks());

  describe('client errors', () => {
    it('passes a 400 through untouched', () => {
      const thrown = new BadRequestException('المنطقة المختارة غير مدعومة');
      filter.catch(thrown, host());

      expect(status).toBe(400);
      expect(body).toEqual(thrown.getResponse());
    });

    it('does not report 4xx — they are the API working, not an incident', () => {
      filter.catch(new UnauthorizedException('bad password'), host());
      filter.catch(new BadRequestException('invalid phone'), host());

      expect(reported).toHaveLength(0);
    });

    it('preserves a validation pipe payload exactly', () => {
      // Nest's ValidationPipe returns `message` as an array; the Flutter client
      // reads `message[0]`, so flattening it here would break every error toast.
      const thrown = new BadRequestException({
        statusCode: 400,
        message: ['phone must be a string', 'password is too short'],
        error: 'Bad Request',
      });
      filter.catch(thrown, host());

      expect(body).toEqual(thrown.getResponse());
    });
  });

  describe('server errors', () => {
    it('reports a 500 to Sentry', () => {
      const thrown = new Error('connection terminated');
      filter.catch(thrown, host());

      expect(reported).toEqual([thrown]);
    });

    it('reports a thrown 5xx HttpException too', () => {
      filter.catch(
        new HttpException('upstream died', HttpStatus.BAD_GATEWAY),
        host(),
      );

      expect(reported).toHaveLength(1);
    });

    it('tags the report with the request id', () => {
      const spy = jest.spyOn(sentry, 'reportError');
      runWithRequestContext({ requestId: 'req-99' }, () =>
        filter.catch(new Error('boom'), host()),
      );

      expect(spy.mock.calls[0][1]).toMatchObject({ requestId: 'req-99' });
    });

    it('never leaks the underlying message', () => {
      // An unknown throw can carry a connection string or a query.
      filter.catch(
        new Error('password=hunter2 host=db.internal'),
        host(),
      );

      expect(status).toBe(500);
      expect(JSON.stringify(body)).not.toContain('hunter2');
      expect(body).toMatchObject({
        statusCode: 500,
        message: 'Internal server error',
      });
    });

    it('hands back the request id so the user can quote it', () => {
      runWithRequestContext({ requestId: 'req-77' }, () =>
        filter.catch(new Error('boom'), host()),
      );

      expect(body).toMatchObject({ requestId: 'req-77' });
    });

    it('handles a non-Error throw without falling over', () => {
      expect(() => filter.catch('just a string', host())).not.toThrow();
      expect(status).toBe(500);
    });
  });
});
