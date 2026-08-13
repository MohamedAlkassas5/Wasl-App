import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../auth/current-user';
import { imageUploadPolicy } from '../common/upload-policy';
import { OrderChatService } from './order-chat.service';
import {
  CreatePriceProposalDto,
  ListMessagesDto,
  SendImageMessageDto,
  SendMessageDto,
} from './dto/chat.dto';

/**
 * One order-scoped conversation, shared by all four order types.
 *
 * 🔐 Every route is authenticated, and the caller's relationship to the order
 * is re-derived from the token inside the service on each call — the `:orderId`
 * in the path selects a conversation, it never grants access to one.
 *
 * Price changes are `POST`ed as explicit approve/reject actions. There is no
 * path here that reads a decision out of message text.
 */
@Controller('orders/:orderId/chat')
@UseGuards(JwtAuthGuard)
export class OrderChatController {
  constructor(private readonly chatService: OrderChatService) {}

  @Get('messages')
  listMessages(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Query() query: ListMessagesDto,
  ) {
    return this.chatService.listMessages(orderId, user, query);
  }

  @Get('unread-count')
  unreadCount(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.chatService.unreadCount(orderId, user);
  }

  @Post('read')
  markRead(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.chatService.markRead(orderId, user);
  }

  // Chat is the cheapest route in the app to spam; the global 120/min ceiling
  // is far too generous for a write that fans out to a notification.
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('messages')
  sendText(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: SendMessageDto,
  ) {
    return this.chatService.sendText(orderId, user, dto);
  }

  @Throttle({ default: { limit: 15, ttl: 60_000 } })
  @Post('messages/image')
  @UseInterceptors(FileInterceptor('attachment', imageUploadPolicy))
  sendImage(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: SendImageMessageDto,
  ) {
    return this.chatService.sendImage(orderId, user, file, dto?.body);
  }

  // ─── Price changes ───────────────────────────────────────────────────────

  @Get('price-proposals')
  listProposals(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.chatService.listProposals(orderId, user);
  }

  /** Driver only. Creates the request; changes nothing on the order. */
  @Post('price-proposals')
  createProposal(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: CreatePriceProposalDto,
  ) {
    return this.chatService.createProposal(orderId, user, dto);
  }

  /** Customer only. The only path that may change `orders.itemsPrice`. */
  @Post('price-proposals/:proposalId/approve')
  approveProposal(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Param('proposalId', ParseIntPipe) proposalId: number,
  ) {
    return this.chatService.decideProposal(orderId, proposalId, user, true);
  }

  /**
   * Customer only. Leaves the order untouched — no cancellation, no refund,
   * no money movement. What follows is the driver's decision and, if they
   * cancel, an admin's review.
   */
  @Post('price-proposals/:proposalId/reject')
  rejectProposal(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Param('proposalId', ParseIntPipe) proposalId: number,
  ) {
    return this.chatService.decideProposal(orderId, proposalId, user, false);
  }
}
