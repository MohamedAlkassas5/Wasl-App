import { IsNumber, IsOptional, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Normal order (restaurants / pharmacy / stores): the fee depends on the
 * destination area and nothing else.
 *
 * `dropoffZoneId` is optional because the usual case is "deliver to where I
 * live" — omit it and the server uses the area on the caller's own profile.
 * Passing one explicitly covers ordering to a different approved area.
 */
export class NormalQuoteDto {
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  dropoffZoneId?: number;
}

/** Waslly: a fixed fee for the chosen pickup-area → drop-off-area route. */
export class WasllyQuoteDto {
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  pickupZoneId!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(1)
  dropoffZoneId!: number;
}

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
