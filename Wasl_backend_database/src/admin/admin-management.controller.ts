import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminAuditLogService } from './admin-audit-log.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole, AccountStatus } from '../users/entities/user.entity';

/**
 * Admin panel read endpoints: registration lists (with documents) and
 * dashboard counters. Guarded by JWT + ADMIN role.
 */
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminManagementController {
  constructor(
    private readonly adminService: AdminService,
    private readonly auditLog: AdminAuditLogService,
  ) {}

  /**
   * The administrator action trail (CP-E / S10).
   *
   * Read-only and paginated. Reading the log is itself *not* audited — every
   * page view would bury the actions the log exists to show, and looking is
   * not an action on the platform.
   */
  @Get('audit-log')
  auditTrail(
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.auditLog.list({
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  @Get('registrations')
  registrations(
    @Query('role') role?: UserRole,
    @Query('status') status?: AccountStatus,
  ) {
    return this.adminService.getRegistrations(role, status);
  }

  @Get('dashboard')
  dashboard() {
    return this.adminService.getDashboardStats();
  }
}
