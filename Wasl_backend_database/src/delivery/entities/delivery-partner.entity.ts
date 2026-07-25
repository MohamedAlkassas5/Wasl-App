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

  // 🛰️ Live GPS location of the driver (updated periodically while online).
  // Never hardcoded — populated by PATCH /drivers/:id/location from the app.
  @Column({
    name: 'current_latitude',
    type: 'double precision',
    nullable: true,
  })
  currentLatitude?: number;

  @Column({
    name: 'current_longitude',
    type: 'double precision',
    nullable: true,
  })
  currentLongitude?: number;

  // Timestamp of the last GPS fix — used to ignore stale/offline positions.
  @Column({
    name: 'last_location_update',
    type: 'timestamp',
    nullable: true,
  })
  lastLocationUpdate?: Date;

  // How far (km) this driver is willing to travel for a pickup. Configurable
  // per-driver; defaults to the platform search radius.
  @Column({
    name: 'availability_radius_km',
    type: 'double precision',
    default: 5,
  })
  availabilityRadiusKm!: number;

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
