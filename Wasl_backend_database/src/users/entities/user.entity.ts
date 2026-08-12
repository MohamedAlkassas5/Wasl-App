import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  JoinColumn,
  ManyToOne,
  OneToOne,
} from 'typeorm';
import { DeliveryPartner } from '../../delivery/entities/delivery-partner.entity'; // 👈 استيراد موديل المناديب
import { Merchant } from '../../merchant/entities/merchant.entity'; // 👈 استيراد موديل التجار
import { DeliveryZone } from '../../zones/entities/delivery-zone.entity';

export enum UserRole {
  CUSTOMER = 'customer',
  DELIVERY = 'delivery',
  MERCHANT = 'merchant',
  ADMIN = 'admin',
}

export enum AccountStatus {
  ACTIVE = 'active',
  PENDING = 'pending',
  REJECTED = 'rejected',
  SUSPENDED = 'suspended',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 100 })
  name!: string;

  @Column({ type: 'varchar', length: 20, unique: true })
  phone!: string;

  @Column({ type: 'varchar' })
  passwordHash!: string;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.CUSTOMER })
  role!: UserRole;

  @Column({ type: 'enum', enum: AccountStatus, default: AccountStatus.ACTIVE })
  status!: AccountStatus;

  @Column({ type: 'text', nullable: true, name: 'admin_notes' })
  admin_notes?: string;

  // 🌐 [جديد ولايف] حقول المعرفات الاجتماعية لتأمين الدخول السريع عبر فيسبوك وجوجل
  @Column({ type: 'varchar', length: 150, nullable: true, unique: true })
  // `| null` because the column really is nullable and closing an account
  // clears it — without it TypeScript refuses the very write that scrubs it.
  email?: string | null;

  @Column({
    type: 'varchar',
    length: 255,
    nullable: true,
    unique: true,
    name: 'firebase_uid',
  })
  firebaseUid?: string | null;

  /**
   * 📍 The customer's home area — one of the approved delivery zones.
   *
   * This is what prices a normal order: the fee is a function of the
   * destination area and nothing else. Nullable because it postdates the
   * accounts already in the database and because drivers/merchants/admins have
   * no customer area; a customer without one simply can't be quoted a normal
   * delivery until they pick one.
   */
  @Column({ name: 'customer_zone_id', nullable: true })
  customerZoneId?: number | null;

  @ManyToOne(() => DeliveryZone, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'customer_zone_id' })
  customerZone?: DeliveryZone;

  // 🎯 1. ربط العلاقة العكسية للمناديب ليتعرف عليها ملف delivery-partner.entity
  @OneToOne(() => DeliveryPartner, (delivery) => delivery.user)
  deliveryPartner?: DeliveryPartner;

  // 🎯 2. ربط العلاقة العكسية للتجار ليتعرف عليها ملف merchant.entity
  @OneToOne(() => Merchant, (merchant) => merchant.user)
  merchant?: Merchant;

  /**
   * When the owner closed this account, or null while it is live.
   *
   * A closed account keeps its row: the orders on it reference a driver who
   * was paid and a commission that was charged, so the row has to stay for
   * those records to make sense. Everything personal on it is scrubbed and the
   * phone released — see `AuthService.deleteUserRecord`.
   */
  @Column({ name: 'deleted_at', type: 'timestamp', nullable: true })
  deletedAt?: Date | null;

  @CreateDateColumn()
  created_at!: Date;
}
