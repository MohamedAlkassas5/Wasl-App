import { Controller, Get, HttpStatus, Logger, Res } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import type { Response } from 'express';

/** What the endpoint reports about one dependency. */
type Probe = 'up' | 'down';

interface HealthReport {
  status: 'ok' | 'degraded';
  uptimeSeconds: number;
  database: Probe;
}

/**
 * `GET /health` — is this instance actually able to serve?
 *
 * The route that existed before this returned the string `Hello World!` from
 * `GET /`, and Render's health check pointed at it. That only ever proved the
 * Node process was alive. An instance whose database was unreachable answered
 * it perfectly happily, so the platform would keep routing traffic to a server
 * that could not fulfil a single request.
 *
 * This runs a real query. `SELECT 1` is deliberately the cheapest statement
 * there is — the check runs every few seconds, forever, and a health probe that
 * costs anything real becomes its own load problem.
 *
 * Unauthenticated on purpose: the prober is a platform, not a user, and it has
 * no token. Nothing here discloses anything — uptime and a reachability
 * boolean — so there is nothing to protect.
 */
@Controller('health')
export class HealthController {
  private readonly logger = new Logger(HealthController.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  // Exempt from the global 120/min limit. Render probes far more often than a
  // user does, and a rate-limited health check reports a healthy server as
  // failing, which is the one lie that matters here.
  @SkipThrottle()
  @Get()
  async check(
    @Res({ passthrough: true }) response: Response,
  ): Promise<HealthReport> {
    const database = await this.probeDatabase();
    const healthy = database === 'up';

    // 503 is written onto the response rather than thrown. A thrown exception
    // would reach the global filter and be reported to Sentry — and since this
    // route is polled continuously, one database blip would become thousands of
    // identical events. The condition is logged once per probe instead.
    response.status(healthy ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE);

    return {
      status: healthy ? 'ok' : 'degraded',
      uptimeSeconds: Math.floor(process.uptime()),
      database,
    };
  }

  private async probeDatabase(): Promise<Probe> {
    try {
      await this.dataSource.query('SELECT 1');
      return 'up';
    } catch (error) {
      this.logger.warn(
        `Health probe: database unreachable — ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return 'down';
    }
  }
}
