import {
  IsNumber,
  IsOptional,
  IsString,
  IsEnum,
  IsArray,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { PaymentMethod } from '../entities/order.entity';

export class CreateOrderDto {
  // 🔐 Optional and, when present, ignored: OrdersController overwrites this
  // with the id from the authenticated caller's JWT (`user.sub`) so nobody can
  // place an order in someone else's name. It used to be required, which meant
  // a client that (reasonably) stopped sending a field the server discards
  // would break order creation with a confusing "customerId must be a number"
  // validation error before the handler ever ran.
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  customerId?: number;

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
  itemsPrice?: number;

  @IsOptional()
  @IsString()
  itemsImageUrl?: string;

  @IsOptional()
  @IsString()
  voiceNoteUrl?: string;

  @IsOptional()
  @IsEnum(PaymentMethod)
  paymentMethod?: PaymentMethod;
}
