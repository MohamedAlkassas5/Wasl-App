import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  OneToMany,
} from 'typeorm';

import { User } from '../../users/entities/user.entity';
import { OrderItem } from './order-item.entity';

export enum OrderStatus {
  PENDING_OFFERS = 'pending_offers',
  ACCEPTED = 'accepted',
  AT_STORE = 'at_store',
  ITEMS_BOUGHT = 'items_bought',
  DELIVERING = 'delivering',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

/**
 * How the customer pays.
 *
 * Cash on delivery only. `paymob` and `fawry` used to sit here as enum values
 * with no integration anywhere behind them — no provider account, no webhook,
 * no payment record — so an order could be created claiming to be card-paid
 * and nothing would ever collect the money. Offering a payment method the
 * system cannot take payment through is worse than not offering it, so they
 * are gone until a provider is actually chosen and wired.
 */
export enum PaymentMethod {
  COD = 'cod',
}

/**
 * What kind of order this is.
 *
 * Drives which contract applies: an itemised catalog order, a free-text
 * pharmacy request, or a courier run between two areas. Previously only
 * `categoryType` existed — a free-text Arabic label chosen by the app — which
 * meant the server could not tell a restaurant order from a Waslly one, and
 * so could not validate either.
 */
export enum OrderType {
  /** Itemised, from a merchant's catalog. */
  RESTAURANT = 'restaurant',
  STORE = 'store',
  /** Free-text medicines, optionally with a prescription photo. */
  PHARMACY = 'pharmacy',
  /** Courier run: area → area, nothing bought. */
  WASLLY = 'waslly',
  /** "هاتلي" and anything predating the typed contracts. */
  GENERAL = 'general',
}

/** Order types where the driver buys goods and needs a shop stage. */
export const PURCHASE_ORDER_TYPES: readonly OrderType[] = [
  OrderType.RESTAURANT,
  OrderType.STORE,
  OrderType.PHARMACY,
  OrderType.GENERAL,
];

/**
 * Which pricing rule produced the fee stored on an order.
 *
 * Persisted so a settled order can always be explained, and so changing the
 * rate table later never silently re-prices history.
 */
export enum PricingSource {
  /** Normal order: flat fee for the destination area. */
  NORMAL_ZONE = 'normal_zone',
  /** Waslly: fixed fee for the pickup-area → drop-off-area route. */
  WASLLY_ROUTE = 'waslly_route',
  /**
   * Legacy distance tiers. Only reachable for an order with no zones on it;
   * kept so pre-existing orders and any client that has not been updated yet
   * still resolve to a real number instead of failing.
   */
  LEGACY_DISTANCE = 'legacy_distance',
}

export enum PaymentStatus {
  PENDING = 'pending',
  PAID = 'paid',
  FAILED = 'failed',
  COD_DUE = 'cod_due',
}

/** Whether the platform has taken its commission for this order yet. */
export enum SettlementStatus {
  /** No money has moved for this order. */
  PENDING = 'pending',
  /** Commission charged, driver share recorded. Happens exactly once. */
  SETTLED = 'settled',
}

@Entity('orders')
@Index('idx_orders_status', ['status'])
@Index('idx_orders_customer', ['customerId', 'createdAt'])
@Index('idx_orders_driver_status', ['acceptedDriverId', 'status'])
export class Order {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  customerId!: number;

  @ManyToOne(() => User)
  customer!: User;

  // 🎯 [جديد حياً]: حقول بيانات العميل اللحظية لسهولة تواصل مندوب التوصيل
  @Column({ nullable: true })
  customerName?: string;

  @Column({ nullable: true })
  customerPhone?: string;

  /**
   * The typed contract this order follows. `categoryType` below stays as the
   * customer-facing Arabic label the app already shows; this is the one the
   * server validates against.
   */
  @Column({
    name: 'order_type',
    type: 'varchar',
    length: 20,
    default: OrderType.GENERAL,
  })
  orderType!: OrderType;

  @Column()
  categoryType!: string;

  @Column({ nullable: true })
  storeName?: string;

  /** The merchant this order is for, when it came from a catalog. */
  @Column({ name: 'merchant_id', type: 'int', nullable: true })
  merchantId?: number | null;

  /** Itemised lines with their prices frozen. Empty for pharmacy/Waslly. */
  @OneToMany(() => OrderItem, (item) => item.order)
  items!: OrderItem[];

  // ─── Pharmacy request ────────────────────────────────────────────────────

  @Column({
    name: 'pharmacy_name',
    type: 'varchar',
    length: 160,
    nullable: true,
  })
  pharmacyName?: string | null;

  /**
   * Photo of a prescription. Sensitive medical data — served only through
   * `FilesController`, which checks the caller is a party to this order.
   */
  @Column({
    name: 'prescription_image_url',
    type: 'varchar',
    nullable: true,
  })
  prescriptionImageUrl?: string | null;

  // ─── Waslly ──────────────────────────────────────────────────────────────

  /**
   * Who receives the parcel, when that is not the customer.
   *
   * A third party's phone number: visible to the assigned driver once they
   * have accepted (they need to call ahead), never to drivers merely browsing
   * the marketplace. Enforced server-side in `OrdersService`, not by hoping
   * the app hides it.
   */
  @Column({
    name: 'recipient_phone',
    type: 'varchar',
    length: 20,
    nullable: true,
  })
  recipientPhone?: string | null;

  @Column({
    name: 'recipient_name',
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  recipientName?: string | null;

  @Column({ type: 'text' })
  itemsDescription!: string;

  @Column({ nullable: true })
  voiceNoteUrl?: string;

  @Column({ nullable: true })
  itemsImageUrl?: string;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  itemsPrice!: number;

  @Column({ nullable: true })
  invoiceImageUrl?: string;

  // 📍 العنوان النصي التفصيلي الذي يكتبه العميل يدوياً (مفعل ومدعوم بالكامل)
  @Column({ type: 'text' })
  deliveryAddressText!: string;

  // 🛰️ [جديد حياً]: إحداثيات الـ GPS الجغرافية الدقيقة لخرائط جوجل ومزامنة الرادار
  @Column({
    type: 'decimal',
    precision: 10,
    scale: 7,
    nullable: true,
  })
  latitude?: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 7,
    nullable: true,
  })
  longitude?: number;

  // 📦 [Order-from-anywhere]: pickup point is where the driver collects the
  // item; the destination is the existing latitude/longitude above. Both are
  // real GPS from the customer app — never hardcoded.
  @Column({ name: 'pickup_address_text', type: 'text', nullable: true })
  pickupAddressText?: string;

  @Column({
    name: 'pickup_latitude',
    type: 'decimal',
    precision: 10,
    scale: 7,
    nullable: true,
  })
  pickupLatitude?: number;

  @Column({
    name: 'pickup_longitude',
    type: 'decimal',
    precision: 10,
    scale: 7,
    nullable: true,
  })
  pickupLongitude?: number;

  @Column({ name: 'pickup_zone_id', nullable: true })
  pickupZoneId?: number;

  @Column({ name: 'dropoff_zone_id', nullable: true })
  dropoffZoneId?: number;

  // 🧮 Trip distance (km) and the pricing-engine estimate, computed at creation.
  @Column({
    name: 'distance_km',
    type: 'decimal',
    precision: 8,
    scale: 2,
    nullable: true,
  })
  distanceKm?: number;

  @Column({
    name: 'estimated_delivery_fee',
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  estimatedDeliveryFee!: number;

  /**
   * The rule that produced {@link estimatedDeliveryFee}, frozen at creation.
   * Part of the order's price snapshot: editing the zone rate table afterwards
   * must never change what an existing order was quoted.
   */
  @Column({
    name: 'pricing_source',
    type: 'varchar',
    length: 32,
    nullable: true,
  })
  pricingSource?: PricingSource;

  @Column({
    type: 'enum',
    enum: OrderStatus,
    default: OrderStatus.PENDING_OFFERS,
  })
  status!: OrderStatus;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  finalDeliveryFee!: number;

  @Column({
    name: 'payment_method',
    type: 'varchar',
    length: 20,
    default: PaymentMethod.COD,
  })
  paymentMethod!: PaymentMethod;

  @Column({
    name: 'payment_status',
    type: 'varchar',
    length: 20,
    default: PaymentStatus.COD_DUE,
  })
  paymentStatus!: PaymentStatus;

  @Column({ name: 'payment_reference', nullable: true })
  paymentReference?: string;

  @Column({ nullable: true })
  acceptedDriverId?: number;

  @ManyToOne(() => User, { nullable: true, eager: false })
  acceptedDriver?: User;

  // ─── Financial snapshot ──────────────────────────────────────────────────
  //
  // Frozen at settlement. Rates and settings are admin-editable at runtime, so
  // an order that recomputed its own numbers on read would silently change
  // what a driver earned months after the fact. These columns are the record.

  /** Platform commission actually charged: max(fee × 20%, floor). */
  @Column({
    name: 'commission_amount',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  commissionAmount?: number | null;

  /** What the delivery fee left the driver after commission. */
  @Column({
    name: 'driver_share',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  driverShare?: number | null;

  @Column({
    name: 'settlement_status',
    type: 'varchar',
    length: 20,
    default: SettlementStatus.PENDING,
  })
  settlementStatus!: SettlementStatus;

  @Column({ name: 'settled_at', type: 'timestamp', nullable: true })
  settledAt?: Date | null;

  /**
   * The idempotency key used for this order's commission ledger entry. Stored
   * on the order too so a settlement can be traced from either side.
   */
  @Column({
    name: 'settlement_reference',
    type: 'varchar',
    length: 120,
    nullable: true,
  })
  settlementReference?: string | null;

  // ─── Lifecycle timestamps ────────────────────────────────────────────────
  // When each stage happened, rather than only the current state.

  @Column({ name: 'accepted_at', type: 'timestamp', nullable: true })
  acceptedAt?: Date | null;

  @Column({ name: 'delivering_at', type: 'timestamp', nullable: true })
  deliveringAt?: Date | null;

  @Column({ name: 'completed_at', type: 'timestamp', nullable: true })
  completedAt?: Date | null;

  @Column({ name: 'cancelled_at', type: 'timestamp', nullable: true })
  cancelledAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @OneToMany(() => OrderOffer, (offer) => offer.order)
  offers!: OrderOffer[];
}

@Entity('order_offers')
export class OrderOffer {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  orderId!: number;

  @ManyToOne(() => Order, (order) => order.offers, {
    onDelete: 'CASCADE',
  })
  order!: Order;

  @Column()
  driverId!: number;

  @ManyToOne(() => User)
  driver!: User;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
  })
  deliveryFee!: number;

  @Column()
  estimatedTime!: number;

  @CreateDateColumn()
  createdAt!: Date;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true, // 👈 ضيف دي عشان ما يجبركش على قيمة ابتدائية
    default: 0,
  })
  itemsPrice?: number;
}
// import {
//   Entity,
//   PrimaryGeneratedColumn,
//   Column,
//   CreateDateColumn,
//   ManyToOne,
//   OneToMany,
// } from 'typeorm';

// import { User } from '../../users/entities/user.entity';

// export enum OrderStatus {
//   PENDING_OFFERS = 'pending_offers',
//   ACCEPTED = 'accepted',
//   AT_STORE = 'at_store',
//   ITEMS_BOUGHT = 'items_bought',
//   DELIVERING = 'delivering',
//   COMPLETED = 'completed',
//   CANCELLED = 'cancelled',
// }

// @Entity('orders')
// export class Order {
//   @PrimaryGeneratedColumn()
//   id!: number;

//   @Column()
//   customerId!: number;

//   @ManyToOne(() => User)
//   customer!: User;

//   @Column({ nullable: true })
//   customerName?: string;

//   @Column({ nullable: true })
//   customerPhone?: string;

//   @Column()
//   categoryType!: string;

//   @Column({ nullable: true })
//   storeName?: string;

//   @Column({ type: 'text' })
//   itemsDescription!: string;

//   // 📸 دعم الصور والرسائل الصوتية في الطلب
//   @Column({ nullable: true })
//   voiceNoteUrl?: string;

//   @Column({ nullable: true })
//   itemsImageUrl?: string; // رابط صورة الطلبات التي يرفعها العميل

//   @Column({
//     type: 'decimal',
//     precision: 10,
//     scale: 2,
//     default: 0,
//   })
//   itemsPrice!: number;

//   @Column({ nullable: true })
//   invoiceImageUrl?: string; // صورة الفاتورة التي يرفعها الكابتن

//   @Column({ type: 'text' })
//   deliveryAddressText!: string;

//   @Column({
//     type: 'decimal',
//     precision: 10,
//     scale: 7,
//     nullable: true,
//   })
//   latitude?: number;

//   @Column({
//     type: 'decimal',
//     precision: 10,
//     scale: 7,
//     nullable: true,
//   })
//   longitude?: number;

//   @Column({
//     type: 'enum',
//     enum: OrderStatus,
//     default: OrderStatus.PENDING_OFFERS,
//   })
//   status!: OrderStatus;

//   @Column({
//     type: 'decimal',
//     precision: 10,
//     scale: 2,
//     default: 0,
//   })
//   finalDeliveryFee!: number;

//   @Column({ nullable: true })
//   acceptedDriverId?: number;

//   @ManyToOne(() => User, { nullable: true, eager: false })
//   acceptedDriver?: User;

//   @CreateDateColumn()
//   createdAt!: Date;

//   @OneToMany(() => OrderOffer, (offer) => offer.order)
//   offers!: OrderOffer[];
// }

// @Entity('order_offers')
// export class OrderOffer {
//   @PrimaryGeneratedColumn()
//   id!: number;

//   @Column()
//   orderId!: number;

//   @ManyToOne(() => Order, (order) => order.offers, {
//     onDelete: 'CASCADE',
//   })
//   order!: Order;

//   @Column()
//   driverId!: number;

//   @ManyToOne(() => User)
//   driver!: User;

//   @Column({
//     type: 'decimal',
//     precision: 10,
//     scale: 2,
//   })
//   deliveryFee!: number;

//   @Column()
//   estimatedTime!: number;

//   @CreateDateColumn()
//   createdAt!: Date;

//   // حقل اختياري يربط العرض بالسعر التقديري للمنتجات
//   @Column({
//     type: 'decimal',
//     precision: 10,
//     scale: 2,
//     nullable: true,
//     default: 0,
//   })
//   itemsPrice?: number;
// }
