import { IsNumber, IsEnum, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { TopUpMethod } from '../entities/wallet-topup-request.entity';

export class CreateTopUpRequestDto {
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  amount!: number;

  @IsEnum(TopUpMethod)
  method!: TopUpMethod;

  @IsOptional()
  @IsString()
  senderReference?: string;

  @IsOptional()
  @IsString()
  proofImageUrl?: string;
}

export class ReviewTopUpDto {
  @IsOptional()
  @IsString()
  adminNote?: string;
}

export class AdminCreditDto {
  @Type(() => Number)
  @IsNumber()
  amount!: number;

  @IsOptional()
  @IsString()
  note?: string;
}
