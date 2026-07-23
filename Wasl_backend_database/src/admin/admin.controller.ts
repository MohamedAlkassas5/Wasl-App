import {
  Controller,
  Patch,
  Param,
  Body,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';

import { AdminService } from './admin.service';
import { UpdateApprovalDto } from './dto/update-approval.dto';

// 👈 استيراد الحراس (Guards) والمثبتات الصافية 100%
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

@Controller('admin/approvals')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Patch('review/:userId')
  @Roles(UserRole.ADMIN)
  async reviewRequest(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() updateApprovalDto: UpdateApprovalDto,
  ) {
    return await this.adminService.reviewRegistration(
      userId,
      updateApprovalDto,
    );
  }
}
