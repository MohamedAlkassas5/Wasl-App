import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { SupportService } from './support.service';
import {
  ListSupportMessagesDto,
  SendSupportImageDto,
  SendSupportMessageDto,
} from './dto/support.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../auth/current-user';
import { imageUploadPolicy } from '../common/upload-policy';

/**
 * The user's own support thread.
 *
 * 🔐 **No route here takes a conversation id.** The thread is resolved from
 * the token on every call, so one driver reading another's support history is
 * not something a check could fail to catch — there is no parameter through
 * which to ask for it. Contrast the admin controller, which does take an id
 * and is behind the ADMIN role.
 *
 * This is the driver ↔ admin channel. The customer ↔ driver conversation about
 * a specific delivery lives at `orders/:orderId/chat` and is a different thing
 * entirely: different table, different participants, different authorization.
 */
@Controller('support')
@UseGuards(JwtAuthGuard)
export class SupportController {
  constructor(private readonly supportService: SupportService) {}

  /** The caller's conversation. `after` keeps the poll loop cheap. */
  @Get('messages')
  listMine(
    @CurrentUser() user: AuthUser,
    @Query() query: ListSupportMessagesDto,
  ) {
    return this.supportService.listMyMessages(user, query);
  }

  /** Unread admin replies — the badge on the Settings item. */
  @Get('unread-count')
  unread(@CurrentUser() user: AuthUser) {
    return this.supportService.myUnreadCount(user);
  }

  @Post('read')
  markRead(@CurrentUser() user: AuthUser) {
    return this.supportService.markMyRead(user);
  }

  @Post('messages')
  send(@CurrentUser() user: AuthUser, @Body() dto: SendSupportMessageDto) {
    return this.supportService.sendMyMessage(user, dto);
  }

  /**
   * Attach a screenshot — the transfer receipt behind a wallet complaint is
   * the usual case. Same upload policy as every other image in the product:
   * memory storage, size cap, and the real type read from the bytes.
   */
  @Post('messages/image')
  @UseInterceptors(FileInterceptor('attachment', imageUploadPolicy))
  sendImage(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: SendSupportImageDto,
  ) {
    return this.supportService.sendMyImage(user, file, dto.body);
  }
}
