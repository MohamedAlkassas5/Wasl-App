import {
  IsNumber,
  IsOptional,
  IsString,
  IsEnum,
  IsArray,
  IsInt,
  Length,
  Min,
  Max,
  MaxLength,
  ValidateNested,
  ArrayMaxSize,
} from 'class-validator';
import { Type } from 'class-transformer';
import { PaymentMethod, OrderType } from '../entities/order.entity';

/**
 * One line the customer configured in the cart.
 *
 * Note what is **not** here: any price. The client says which product, which
 * size and which add-ons; the server looks all three up in the catalog and
 * computes the money itself. A line that carried its own price would let a
 * customer name what they feel like paying.
 */
export class OrderItemDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  productId!: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  sizeId?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @Type(() => Number)
  @IsInt({ each: true })
  addonIds?: number[];

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  quantity!: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

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

  /**
   * Which contract this order follows. Optional so builds that predate typing
   * keep working — the server infers `waslly` from a zone pair and otherwise
   * falls back to `general`.
   */
  @IsOptional()
  @IsEnum(OrderType)
  orderType?: OrderType;

  /** The merchant the cart came from. Required for an itemised order. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  merchantId?: number;

  @IsOptional()
  @IsString()
  storeName?: string;

  /**
   * Structured cart lines, priced by the server from the catalog.
   *
   * `items` used to be `unknown[]` that the controller JSON-parsed and then
   * discarded — the cart survived only as text inside `itemsDescription`.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items?: OrderItemDto[];

  // ─── Pharmacy ───────────────────────────────────────────────────────────

  @IsOptional()
  @IsString()
  @MaxLength(160)
  pharmacyName?: string;

  @IsOptional()
  @IsString()
  prescriptionImageUrl?: string;

  // ─── Waslly recipient ───────────────────────────────────────────────────

  @IsOptional()
  @IsString()
  @Length(8, 20)
  recipientPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  recipientName?: string;

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
