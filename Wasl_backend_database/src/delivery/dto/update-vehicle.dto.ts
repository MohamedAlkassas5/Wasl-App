import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
import { VehicleType } from '../entities/delivery-partner.entity';

/**
 * What a driver may change about their own vehicle.
 *
 * Only these two fields. Everything else on `delivery_partners` is either the
 * platform's business (`balance`, `isOnline`, `verificationStatus`,
 * `adminNotes`) or a document an admin approved (`nationalIdFront`, `selfie`,
 * `vehicleImage`) — a driver editing those would be editing the outcome of
 * their own verification. The DTO whitelist rejects them outright rather than
 * ignoring them silently, so an attempt shows up as a 400 instead of looking
 * like it worked.
 */
export class UpdateVehicleDto {
  @IsOptional()
  @IsEnum(VehicleType)
  vehicleType?: VehicleType;

  /** Plate / licence number. Empty string clears it. */
  @IsOptional()
  @IsString()
  @Length(0, 40)
  licenseNumber?: string;
}
