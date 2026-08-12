import { IsNumber, Min } from 'class-validator';
import { Type } from 'class-transformer';

/** Move the caller to one of the approved delivery areas. */
export class UpdateAreaDto {
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  customerZoneId!: number;
}
