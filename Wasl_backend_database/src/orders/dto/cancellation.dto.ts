import { IsOptional, IsString, Length } from 'class-validator';

/**
 * A reason is mandatory on every cancellation, from either side.
 *
 * Not bureaucracy: the driver's penalty can later be refunded on appeal, and
 * an admin cannot judge a cancellation whose stated cause is blank.
 */
export class CreateCancellationRequestDto {
  @IsString()
  @Length(3, 500)
  reason!: string;
}

/** The driver's own cancellation. Same requirement, same reasons. */
export class DriverCancelOrderDto {
  @IsString()
  @Length(3, 500)
  reason!: string;
}

/** Rejecting a customer's request; an explanation is welcome, not required. */
export class DecideCancellationDto {
  @IsOptional()
  @IsString()
  @Length(1, 255)
  decisionReason?: string;
}

/** The driver's dispute over a penalty, pointing at the chat as evidence. */
export class AppealCancellationDto {
  @IsString()
  @Length(3, 500)
  reason!: string;
}

/** An admin's verdict on that dispute. */
export class ReviewCancellationDto {
  @IsOptional()
  @IsString()
  @Length(1, 500)
  note?: string;
}
