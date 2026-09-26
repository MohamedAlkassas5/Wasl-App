import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { SupportService } from './support.service';
import { AdminAuditLogService } from '../admin/admin-audit-log.service';
import {
  ListSupportMessagesDto,
  SendSupportMessageDto,
  UpdateConversationStatusDto,
} from './dto/support.dto';
import { SupportConversationStatus } from './entities/support-conversation.entity';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';
import { AuthUser, CurrentUser } from '../auth/current-user';

/**
 * The support inbox. Guarded by JWT + ADMIN, the same pairing every other
 * admin surface uses.
 *
 * These routes DO take a conversation id — answering support means reaching
 * other people's threads, which is exactly why the role guard is the thing
 * standing in front of them.
 */
@Controller('admin/support')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminSupportController {
  constructor(
    private readonly supportService: SupportService,
    private readonly auditLog: AdminAuditLogService,
  ) {}

  @Get('conversations')
  list(@Query('status') status?: SupportConversationStatus) {
    return this.supportService.listConversations(status);
  }

  @Get('conversations/:id/messages')
  messages(
    @Param('id', ParseIntPipe) id: number,
    @Query() query: ListSupportMessagesDto,
  ) {
    return this.supportService.listConversationMessages(id, query);
  }

  @Post('conversations/:id/messages')
  async reply(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() admin: AuthUser,
    @Body() dto: SendSupportMessageDto,
  ) {
    const result = await this.supportService.replyAsAdmin(id, admin, dto);
    // Support tells drivers what happened to their money. Who said it, and
    // when, is worth being able to look up afterwards.
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'support.reply',
      targetType: 'support_conversation',
      targetId: id,
      payload: { length: dto.body.length },
    });
    return result;
  }

  @Post('conversations/:id/read')
  markRead(@Param('id', ParseIntPipe) id: number) {
    return this.supportService.markConversationRead(id);
  }

  @Patch('conversations/:id/status')
  async setStatus(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() admin: AuthUser,
    @Body() dto: UpdateConversationStatusDto,
  ) {
    const result = await this.supportService.setStatus(id, dto.status);
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'support.status',
      targetType: 'support_conversation',
      targetId: id,
      payload: dto,
    });
    return result;
  }
}
