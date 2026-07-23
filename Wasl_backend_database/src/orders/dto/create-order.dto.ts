import { IsNumber, IsOptional, IsString, IsArray } from 'class-validator';
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

  @Type(() => Number)
  @IsNumber()
  latitude!: number;

  @Type(() => Number)
  @IsNumber()
  longitude!: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  itemsPrice?: number;

  @IsOptional()
  @IsString()
  itemsImageUrl?: string;
}
