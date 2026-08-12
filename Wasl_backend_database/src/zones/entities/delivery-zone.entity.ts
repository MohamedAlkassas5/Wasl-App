import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';
import { DeliveryZoneRate } from './delivery-zone-rate.entity';

// The constraint is named explicitly, exactly like `UQ_delivery_zone_rate_pair`
// on DeliveryZoneRate. An anonymous `unique: true` would make TypeORM expect a
// hashed name that the hand-written migration can't predict, and every future
// `migration:generate` would try to rename it.
@Entity('delivery_zones')
@Unique('UQ_delivery_zones_code', ['code'])
export class DeliveryZone {
  @PrimaryGeneratedColumn()
  id!: number;

  /**
   * Stable machine identifier for a zone (`kom_hamada`, `biban`, `breem`).
   *
   * Names are Arabic display strings and ids are database-assigned, so neither
   * is safe to reference from a seed, a test or the app. The code is, which is
   * what makes the zone seed idempotent and lets a test say "Breem" without
   * guessing a serial.
   */
  @Column({ type: 'varchar', length: 40, nullable: true })
  code?: string;

  @Column({ type: 'varchar', length: 120 })
  name!: string;

  @Column({ type: 'varchar', length: 120 })
  city!: string;

  /**
   * Flat fee (EGP) to deliver **into** this area on a normal order
   * (restaurants / pharmacy / stores). Destination alone sets the price —
   * distance and the merchant's own location deliberately do not affect it.
   *
   * `null` means the area is not an approved delivery destination, which is a
   * different thing from a zero fee: {@link ZonesService.quoteByDestination}
   * refuses it rather than quoting free delivery.
   */
  @Column({
    name: 'normal_delivery_fee',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  normalDeliveryFee?: number;

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
