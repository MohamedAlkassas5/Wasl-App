import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';
import { DeliveryZone } from './delivery-zone.entity';

@Entity('delivery_zone_rates')
@Unique('UQ_delivery_zone_rate_pair', ['pickupZoneId', 'dropoffZoneId'])
export class DeliveryZoneRate {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'pickup_zone_id' })
  pickupZoneId!: number;

  @Column({ name: 'dropoff_zone_id' })
  dropoffZoneId!: number;

  @ManyToOne(() => DeliveryZone, (zone) => zone.pickupRates, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'pickup_zone_id' })
  pickupZone!: DeliveryZone;

  @ManyToOne(() => DeliveryZone, (zone) => zone.dropoffRates, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'dropoff_zone_id' })
  dropoffZone!: DeliveryZone;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  deliveryFee!: number;

  @Column({ type: 'integer', default: 30 })
  estimatedMinutes!: number;

  @Column({ default: true })
  isActive!: boolean;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
