import { Controller, Get, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { AdminAuditLogService } from '../admin/admin-audit-log.service';
import { UpdateSettingDto } from './dto/update-setting.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser, AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

/**
 * Admin-only surface to read and edit the runtime business configuration
 * (pricing tiers, commission %, search radius). Guarded by JWT + ADMIN role.
 */
@Controller('admin/settings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class SettingsController {
  constructor(
    private readonly settingsService: SettingsService,
    private readonly auditLog: AdminAuditLogService,
  ) {}

  @Get()
  getAll() {
    return this.settingsService.getAll();
  }

  @Patch(':key')
  async update(
    @Param('key') key: string,
    @Body() dto: UpdateSettingDto,
    @CurrentUser() admin: AuthUser,
  ) {
    const result = await this.settingsService.set(key, dto.value);
    // These values move real money — commission percent, penalty percent, the
    // minimum wallet. "Who changed the commission to 40%" needs an answer.
    // targetId is the setting key: not every audited target is numeric.
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'setting.update',
      targetType: 'setting',
      targetId: key,
      payload: { value: dto.value },
    });
    return result;
  }
}
