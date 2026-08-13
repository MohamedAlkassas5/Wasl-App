import { Type } from 'class-transformer';
import {
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';

/** A plain text message. */
export class SendMessageDto {
  @IsString()
  @Length(1, 2000)
  body!: string;
}

/** Optional caption sent alongside an image. */
export class SendImageMessageDto {
  @IsOptional()
  @IsString()
  @Length(1, 2000)
  body?: string;
}

/** Incremental fetch: only what arrived after the last message we hold. */
export class ListMessagesDto {
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

/** The driver's request to change the purchase price. */
export class CreatePriceProposalDto {
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  @Max(100000)
  newItemsPrice!: number;

  @IsOptional()
  @IsString()
  @Length(1, 255)
  reason?: string;
}
