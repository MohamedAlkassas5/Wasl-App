import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToOne,
} from 'typeorm';
import { DeliveryPartner } from '../../delivery/entities/delivery-partner.entity'; // 👈 استيراد موديل المناديب
import { Merchant } from '../../merchant/entities/merchant.entity'; // 👈 استيراد موديل التجار

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
  email?: string;

  @Column({
    type: 'varchar',
    length: 255,
    nullable: true,
    unique: true,
    name: 'firebase_uid',
  })
  firebaseUid?: string;

  // 🎯 1. ربط العلاقة العكسية للمناديب ليتعرف عليها ملف delivery-partner.entity
  @OneToOne(() => DeliveryPartner, (delivery) => delivery.user)
  deliveryPartner?: DeliveryPartner;

  // 🎯 2. ربط العلاقة العكسية للتجار ليتعرف عليها ملف merchant.entity
  @OneToOne(() => Merchant, (merchant) => merchant.user)
  merchant?: Merchant;

  @CreateDateColumn()
  created_at!: Date;
}
