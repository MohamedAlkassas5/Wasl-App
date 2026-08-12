import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DeliveryZoneRate } from './delivery-zone-rate.entity';

@Entity('delivery_zones')
export class DeliveryZone {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 120 })
  name!: string;

  @Column({ type: 'varchar', length: 120 })
  city!: string;

  @Column({ default: true })
  isActive!: boolean;

  @Column({ type: 'double precision', nullable: true })
  latitude?: number;

  @Column({ type: 'double precision', nullable: true })
  longitude?: number;

  @Column({ type: 'double precision', nullable: true })
  radiusKm?: number;

  @OneToMany(() => DeliveryZoneRate, (rate) => rate.pickupZone)
  pickupRates!: DeliveryZoneRate[];

  @OneToMany(() => DeliveryZoneRate, (rate) => rate.dropoffZone)
  dropoffRates!: DeliveryZoneRate[];

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
