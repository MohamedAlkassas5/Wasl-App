import {
  IsNumber,
  IsOptional,
  IsString,
  IsArray,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateOrderDto {
  @Type(() => Number)
  @IsNumber()
  customerId!: number;

  @IsString()
  customerName!: string;

  @IsString()
  customerPhone!: string;

  @IsString()
  categoryType!: string;

  @IsOptional()
  @IsString()
  storeName?: string;

  // 🎯 الحقول الجديدة مضافة بشكل رسمي وصريح لمنع الـ Linter Errors:
  @IsOptional()
  @IsArray()
  items?: unknown[];

  @IsOptional()
  @IsString()
  itemsDescription?: string;

  @IsString()
  deliveryAddressText!: string;

  @IsOptional()
  @IsString()
  pickupTitle?: string;

  @IsOptional()
  @IsString()
  dropoffTitle?: string;

  // Destination (delivery) coordinates — required, real GPS from the app.
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  // Pickup coordinates (order-from-anywhere). Optional: when omitted the trip
  // distance can't be computed and the order falls back to the city tier.
  @IsOptional()
  @IsString()
  pickupAddressText?: string;

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
  itemsPrice?: number;

  @IsOptional()
  @IsString()
  itemsImageUrl?: string;

  @IsOptional()
  @IsString()
  voiceNoteUrl?: string;
}
