import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AdminAuditLog } from './entities/admin-audit-log.entity';
import { AdminAuditLogService } from './admin-audit-log.service';

/**
 * Global, like the storage seam, because the actions worth auditing are spread
 * across five modules — approvals, payments, settings, catalog and
 * cancellations. Importing this into each of them would be five edits to make
 * one cross-cutting concern available, and a sixth omission is how a route
 * ends up silently unaudited.
 */
@Global()
@Module({
  imports: [TypeOrmModule.forFeature([AdminAuditLog])],
  providers: [AdminAuditLogService],
  exports: [AdminAuditLogService],
})
export class AdminAuditLogModule {}
