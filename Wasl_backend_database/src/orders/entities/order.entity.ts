import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
} from 'typeorm';

import { User } from '../../users/entities/user.entity';

export enum OrderStatus {
  PENDING_OFFERS = 'pending_offers',
  ACCEPTED = 'accepted',
  AT_STORE = 'at_store',
  ITEMS_BOUGHT = 'items_bought',
  DELIVERING = 'delivering',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

@Entity('orders')
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

  @Column()
  categoryType!: string;

  @Column({ nullable: true })
  storeName?: string;

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

  @Column({ nullable: true })
  acceptedDriverId?: number;

  @ManyToOne(() => User, { nullable: true, eager: false })
  acceptedDriver?: User;

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
