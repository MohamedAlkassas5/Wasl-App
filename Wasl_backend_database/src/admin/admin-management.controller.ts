import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
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
  constructor(private readonly adminService: AdminService) {}

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
