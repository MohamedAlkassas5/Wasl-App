import { IsNumber, IsEnum, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { TopUpMethod } from '../entities/wallet-topup-request.entity';

export class CreateTopUpRequestDto {
  /**
   * A first, cheap sanity check. The binding limits are the admin-configured
   * `topup_min_amount` / `topup_max_amount`, applied in
   * `PaymentsService.validateAmount` — this decorator only keeps obvious
   * nonsense out of the service.
   */
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  amount!: number;

  @IsEnum(TopUpMethod)
  method!: TopUpMethod;

  @IsOptional()
  @IsString()
  senderReference?: string;

  /**
   * Server-populated. `PaymentsController.createTopUp` overwrites this with
   * the key `UploadService` produced from the uploaded bytes, so a value sent
   * by a client never reaches the database — it cannot point the request at
   * another driver's screenshot.
   */
  @IsOptional()
  @IsString()
  proofImageUrl?: string;
}

export class ReviewTopUpDto {
  /** Doubles as the rejection reason the driver is shown. */
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
