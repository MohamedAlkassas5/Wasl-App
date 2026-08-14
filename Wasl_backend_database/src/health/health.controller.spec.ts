import { HttpStatus } from '@nestjs/common';
import type { Response } from 'express';
import { DataSource } from 'typeorm';

import { HealthController } from './health.controller';

/**
 * The health endpoint exists to answer one question honestly: can this
 * instance serve a request? The route it replaces answered a different one —
 * whether the Node process was running — and an instance with an unreachable
 * database passed it every time.
 */
describe('HealthController', () => {
  let controller: HealthController;
  let queried: string[];
  let statusSet: number | undefined;
  let failWith: Error | null;

  const response = () =>
    ({
      status: (code: number) => {
        statusSet = code;
        return {} as Response;
      },
    }) as unknown as Response;

  const dataSource = {
    query: (sql: string) => {
      queried.push(sql);
      return failWith ? Promise.reject(failWith) : Promise.resolve([{ '?column?': 1 }]);
    },
  };

  beforeEach(() => {
    queried = [];
    statusSet = undefined;
    failWith = null;
    controller = new HealthController(dataSource as unknown as DataSource);
    jest.spyOn(controller['logger'], 'warn').mockImplementation(() => undefined);
  });

  describe('when the database answers', () => {
    it('reports ok with 200', async () => {
      const report = await controller.check(response());

      expect(statusSet).toBe(HttpStatus.OK);
      expect(report).toMatchObject({ status: 'ok', database: 'up' });
    });

    it('actually queries rather than assuming', async () => {
      await controller.check(response());

      expect(queried).toEqual(['SELECT 1']);
    });

    it('includes uptime', async () => {
      const report = await controller.check(response());

      expect(report.uptimeSeconds).toBeGreaterThanOrEqual(0);
    });
  });

  describe('when the database is unreachable', () => {
    beforeEach(() => {
      failWith = new Error('Connection terminated unexpectedly');
    });

    it('reports degraded with 503 so the platform stops sending traffic', async () => {
      const report = await controller.check(response());

      expect(statusSet).toBe(HttpStatus.SERVICE_UNAVAILABLE);
      expect(report).toMatchObject({ status: 'degraded', database: 'down' });
    });

    it('does not throw — a thrown 503 would flood Sentry on every probe', async () => {
      await expect(controller.check(response())).resolves.toBeDefined();
    });
  });
});
