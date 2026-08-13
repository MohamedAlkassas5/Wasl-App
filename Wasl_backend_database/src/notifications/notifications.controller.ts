import { Body, Controller, Delete, Post, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/current-user';
import { NotificationsService } from './notifications.service';
import { RegisterDeviceDto, UnregisterDeviceDto } from './dto/device-token.dto';

/**
 * Device registration for push.
 *
 * 🔐 The owner is always the authenticated caller — there is no user id in the
 * body to point somewhere else. Without that, anyone with an account could
 * register their own device against another user's id and receive that
 * person's order notifications.
 */
@Controller('devices')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post('token')
  register(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceDto) {
    return this.notifications.registerDevice(user.sub, dto.token, dto.platform);
  }

  @Delete('token')
  unregister(@CurrentUser() user: AuthUser, @Body() dto: UnregisterDeviceDto) {
    return this.notifications.unregisterDevice(user.sub, dto.token);
  }
}
