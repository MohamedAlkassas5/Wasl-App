import { Controller, Get, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { UpdateSettingDto } from './dto/update-setting.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

/**
 * Admin-only surface to read and edit the runtime business configuration
 * (pricing tiers, commission %, search radius). Guarded by JWT + ADMIN role.
 */
@Controller('admin/settings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  getAll() {
    return this.settingsService.getAll();
  }

  @Patch(':key')
  update(@Param('key') key: string, @Body() dto: UpdateSettingDto) {
    return this.settingsService.set(key, dto.value);
  }
}
