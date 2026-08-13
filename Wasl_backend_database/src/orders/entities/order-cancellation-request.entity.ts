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

/** Which side asked for the cancellation. */
export enum CancellationInitiator {
  CUSTOMER = 'customer',
  DRIVER = 'driver',
}

/**
 * Where a cancellation stands.
 *
 * A customer's request opens as `PENDING` and the assigned driver answers it.
 * A driver's own cancellation is created already `APPROVED` — they are both
 * the requester and the decider, and there is nobody to ask.
 */
export enum CancellationStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

/**
 * The driver's dispute over a penalty they were charged.
 *
 * `NONE` until they appeal. An admin then either upholds the charge or refunds
 * it; both are terminal, and only `REFUNDED` moves money.
 */
export enum CancellationAppealStatus {
  NONE = 'none',
  PENDING = 'pending',
  UPHELD = 'upheld',
  REFUNDED = 'refunded',
}

/**
 * One cancellation event on an order: who asked, why, who decided, what it
 * cost, and how a dispute over that cost was resolved.
 *
 * Both flows share this table on purpose. A customer's request and a driver's
 * own cancellation produce the same shape of record, so the admin review queue
 * is a single query and the audit trail reads the same either way.
 *
 * Evidence is deliberately **not** stored here. The order's chat already holds
 * the conversation, images included, and it is append-only — duplicating
 * attachments onto this row would create a second, divergent record of the
 * same dispute.
 *
 * Money never lives on this row either. `penaltyAmount` and `refundAmount` are
 * a readable copy of what happened; the authoritative record is the
 * `wallet_transactions` entry named by `penaltyReference` / `refundReference`.
 */
@Entity('order_cancellation_requests')
@Index('idx_cancellation_order', ['orderId', 'createdAt'])
@Index('idx_cancellation_appeals', ['appealStatus', 'createdAt'])
export class OrderCancellationRequest {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'order_id' })
  orderId!: number;

  @ManyToOne(() => Order, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'order_id' })
  order!: Order;

  @Column({ name: 'requested_by' })
  requestedBy!: number;

  @Column({ name: 'requested_by_role', type: 'varchar', length: 12 })
  requestedByRole!: CancellationInitiator;

  /** Required from both sides — a cancellation with no stated reason is not
   * reviewable, and review is the whole point of this record. */
  @Column({ type: 'text' })
  reason!: string;

  @Column({ type: 'varchar', length: 16, default: CancellationStatus.PENDING })
  status!: CancellationStatus;

  @Column({ name: 'decided_by', type: 'int', nullable: true })
  decidedBy?: number | null;

  @Column({ name: 'decided_at', type: 'timestamp', nullable: true })
  decidedAt?: Date | null;

  @Column({
    name: 'decision_reason',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  decisionReason?: string | null;

  // ─── What it cost the driver ─────────────────────────────────────────────

  @Column({
    name: 'penalty_amount',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  penaltyAmount?: number | null;

  /** Idempotency key of the ledger debit (`order-<id>-cancel-penalty`). */
  @Column({
    name: 'penalty_reference',
    type: 'varchar',
    length: 120,
    nullable: true,
  })
  penaltyReference?: string | null;

  // ─── The driver's dispute, and the admin's answer ────────────────────────

  @Column({
    name: 'appeal_status',
    type: 'varchar',
    length: 16,
    default: CancellationAppealStatus.NONE,
  })
  appealStatus!: CancellationAppealStatus;

  @Column({
    name: 'appeal_reason',
    type: 'varchar',
    length: 500,
    nullable: true,
  })
  appealReason?: string | null;

  @Column({ name: 'appealed_at', type: 'timestamp', nullable: true })
  appealedAt?: Date | null;

  @Column({ name: 'reviewed_by', type: 'int', nullable: true })
  reviewedBy?: number | null;

  @Column({ name: 'reviewed_at', type: 'timestamp', nullable: true })
  reviewedAt?: Date | null;

  @Column({
    name: 'review_note',
    type: 'varchar',
    length: 500,
    nullable: true,
  })
  reviewNote?: string | null;

  @Column({
    name: 'refund_amount',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  refundAmount?: number | null;

  /** Idempotency key of the ledger credit (`order-<id>-cancel-refund`). */
  @Column({
    name: 'refund_reference',
    type: 'varchar',
    length: 120,
    nullable: true,
  })
  refundReference?: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
