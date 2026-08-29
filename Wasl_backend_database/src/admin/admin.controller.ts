import {
  Controller,
  Patch,
  Param,
  Body,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';

import { AdminService } from './admin.service';
import { AdminAuditLogService } from './admin-audit-log.service';
import { UpdateApprovalDto } from './dto/update-approval.dto';

// 👈 استيراد الحراس (Guards) والمثبتات الصافية 100%
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser, AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

@Controller('admin/approvals')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly auditLog: AdminAuditLogService,
  ) {}

  @Patch('review/:userId')
  @Roles(UserRole.ADMIN)
  async reviewRequest(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() updateApprovalDto: UpdateApprovalDto,
    @CurrentUser() admin: AuthUser,
  ) {
    const result = await this.adminService.reviewRegistration(
      userId,
      updateApprovalDto,
    );

    // Audited after the fact: a rejected review should leave no entry claiming
    // it happened. The actor is the token's `sub`, never anything in the body.
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'approval.review',
      targetType: 'user',
      targetId: userId,
      payload: updateApprovalDto,
    });

    return result;
  }
}
