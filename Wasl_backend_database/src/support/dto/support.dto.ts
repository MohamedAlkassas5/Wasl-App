import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';

import { SupportConversationStatus } from '../entities/support-conversation.entity';

/**
 * A support message.
 *
 * Note what is absent: `senderRole`, `senderId` and `conversationId`. All
 * three are decided by the server from the token, and the DTO whitelist
 * rejects them outright — a driver posting `senderRole: "admin"` gets a 400
 * rather than a forged official reply.
 */
export class SendSupportMessageDto {
  @IsString()
  @Length(1, 2000)
  body!: string;
}

/** Optional caption sent alongside an image. */
export class SendSupportImageDto {
  @IsOptional()
  @IsString()
  @Length(1, 2000)
  body?: string;
}

/** Incremental fetch: only what arrived after the last message we hold. */
export class ListSupportMessagesDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  after?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}

/** Admin marks a thread handled, or reopens it. */
export class UpdateConversationStatusDto {
  @IsEnum(SupportConversationStatus)
  status!: SupportConversationStatus;
}
