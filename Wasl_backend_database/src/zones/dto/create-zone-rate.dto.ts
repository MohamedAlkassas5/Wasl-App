import { IsBoolean, IsInt, IsNumber, IsOptional, Min } from 'class-validator';

export class CreateZoneRateDto {
  @IsInt()
  @Min(1)
  pickupZoneId!: number;

  @IsInt()
  @Min(1)
  dropoffZoneId!: number;

  @IsNumber()
  @Min(0)
  deliveryFee!: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  estimatedMinutes?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
