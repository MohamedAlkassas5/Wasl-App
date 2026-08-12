import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateRestaurantDto {
  @IsString()
  @MaxLength(160)
  name!: string;

  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsString() openingHours?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}
