import { Module } from '@nestjs/common';

import { HealthController } from './health.controller';

/**
 * No providers: the controller needs only the DataSource, which the root
 * TypeOrmModule already exposes application-wide.
 */
@Module({
  controllers: [HealthController],
})
export class HealthModule {}
