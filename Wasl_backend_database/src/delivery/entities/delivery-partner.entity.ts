import {
  Entity,
  PrimaryColumn,
  Column,
  OneToOne,
  JoinColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

import { User } from '../../users/entities/user.entity';

export enum VehicleType {
  MOTORCYCLE = 'motorcycle',
  SCOOTER = 'scooter',
  CAR = 'car',
  BICYCLE = 'bicycle',
}

export enum DeliveryVerificationStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('delivery_partners')
export class DeliveryPartner {
  @PrimaryColumn({ name: 'user_id' })
  userId!: number;

  @OneToOne(() => User, (user) => user.deliveryPartner, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ name: 'national_id_front' })
  nationalIdFront!: string;

  @Column({ name: 'national_id_back' })
  nationalIdBack!: string;

  @Column()
  selfie!: string;

  @Column({ name: 'vehicle_image' })
  vehicleImage!: string;

  @Column({
    type: 'enum',
    enum: VehicleType,
  })
  vehicleType!: VehicleType;

  @Column({
    name: 'license_number',
    nullable: true,
  })
  licenseNumber?: string;

  @Column({
    type: 'enum',
    enum: DeliveryVerificationStatus,
    default: DeliveryVerificationStatus.PENDING,
  })
  verificationStatus!: DeliveryVerificationStatus;

  @Column({
    name: 'admin_notes',
    type: 'text',
    nullable: true,
  })
  adminNotes?: string;

  // 💵 محفظة الكابتن مسبقة الدفع (التي يتم الخصم منها ديناميكياً)
  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0.0,
  })
  balance!: number;

  // 📡 [التعديل السحري الجديد]: حالة السائق إذا كان مستعداً لاستقبال وتقديم عروض أسعار
  @Column({
    name: 'is_online',
    type: 'boolean',
    default: false,
  })
  isOnline!: boolean;

  @Column({
    type: 'decimal',
    precision: 3,
    scale: 2,
    default: 5.0,
  })
  rating!: number;

  @CreateDateColumn({
    name: 'created_at',
  })
  createdAt!: Date;

  @UpdateDateColumn({
    name: 'updated_at',
  })
  updatedAt!: Date;
}
