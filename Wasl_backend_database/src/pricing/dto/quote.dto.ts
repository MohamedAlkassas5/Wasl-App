import { IsNumber, IsOptional, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * A quote can be requested either from an explicit distance, or from a
 * pickup/destination coordinate pair (preferred — the server computes distance).
 */
export class QuoteDto {
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  pickupZoneId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  dropoffZoneId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  distanceKm?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  pickupLatitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  pickupLongitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  destinationLatitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  destinationLongitude?: number;
}
