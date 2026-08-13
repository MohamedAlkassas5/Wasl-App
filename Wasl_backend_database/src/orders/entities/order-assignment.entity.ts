import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';

import { Order } from './order.entity';

/**
 * Where one driver's offer on one order stands.
 *
 * `OFFERED` is the only live state; the other three are terminal and record
 * why the offer ended. `EXPIRED` covers both the driver running out of time and
 * the offer being withdrawn because somebody else took the order first — from
 * the driver's side those are the same event, and neither is a mark against
 * them the way `DECLINED` is.
 */
export enum AssignmentStatus {
  OFFERED = 'offered',
  ACCEPTED = 'accepted',
  DECLINED = 'declined',
  EXPIRED = 'expired',
}

/**
 * One order offered to one driver, for sixty seconds.
 *
 * This table replaced the open marketplace. Every pending order used to be
 * visible to every eligible driver at once, so the app was a scramble: whoever
 * refreshed at the right moment won, drivers a hundred metres away lost to
 * drivers across town, and nothing recorded who had been asked. Orders that
 * nobody wanted sat in `pending_offers` for ever, because there was no notion
 * of an offer to time out.
 *
 * Now the server picks three nearby, eligible, unoccupied drivers and offers to
 * exactly those three. If none answers inside the window the offers expire, the
 * radius widens, and the next wave goes out — up to a 10 km ceiling, after
 * which the order is marked `expired` and the customer is told plainly that no
 * captain was found.
 *
 * The row is also the audit trail: which wave, at what radius, who was asked,
 * who answered and when.
 */
@Entity('order_assignments')
// A driver is asked about a given order at most once, however many waves run.
@Index('idx_assignments_order_driver', ['orderId', 'driverId'], {
  unique: true,
})
// The candidate query and the driver's own inbox both filter on this.
@Index('idx_assignments_driver_status', ['driverId', 'status'])
// The sweep looks for live offers past their deadline.
@Index('idx_assignments_status_expiry', ['status', 'expiresAt'])
export class OrderAssignment {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'order_id' })
  orderId!: number;

  @ManyToOne(() => Order, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'order_id' })
  order!: Order;

  @Column({ name: 'driver_id' })
  driverId!: number;

  /** 1 for the first ring, incrementing each time the radius widens. */
  @Column({ name: 'wave_number', type: 'int', default: 1 })
  waveNumber!: number;

  /** The search radius (km) this wave went out at. Kept for explainability. */
  @Column({
    name: 'radius_km',
    type: 'double precision',
    nullable: true,
  })
  radiusKm?: number | null;

  /** How far this driver was from the pickup when they were offered it. */
  @Column({
    name: 'distance_km',
    type: 'double precision',
    nullable: true,
  })
  distanceKm?: number | null;

  @Column({ type: 'varchar', length: 16, default: AssignmentStatus.OFFERED })
  status!: AssignmentStatus;

  @Column({
    name: 'offered_at',
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
  })
  offeredAt!: Date;

  /** When this offer stops being answerable. Sixty seconds after it went out. */
  @Column({ name: 'expires_at', type: 'timestamp' })
  expiresAt!: Date;

  /** When the driver accepted or declined. Null if it simply ran out. */
  @Column({ name: 'responded_at', type: 'timestamp', nullable: true })
  respondedAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
