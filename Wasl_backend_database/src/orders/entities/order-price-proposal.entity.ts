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

export enum PriceProposalStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

/**
 * A driver's request to change what the goods actually cost, and the
 * customer's answer to it.
 *
 * This is a table rather than a message kind because the approval is a
 * financial state transition, not a sentence. It has to be queryable on its
 * own, constrained by the database, and readable long after the conversation
 * scrolls away — the previous behaviour was that a driver simply wrote a new
 * `itemsPrice` onto the order and the customer found out when they paid.
 *
 * Rejection deliberately does **nothing** to the order here: it does not
 * cancel it and it moves no money. The approved rule is that the driver then
 * cancels, the standing cancellation penalty applies, and only an admin — after
 * reviewing this history — may refund it. None of that is automatic, so none of
 * it happens in this table.
 */
@Entity('order_price_proposals')
@Index('idx_price_proposals_order', ['orderId', 'createdAt'])
export class OrderPriceProposal {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'order_id' })
  orderId!: number;

  @ManyToOne(() => Order, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'order_id' })
  order!: Order;

  /** The assigned driver who asked. */
  @Column({ name: 'proposed_by' })
  proposedBy!: number;

  /** `orders.itemsPrice` at the moment of asking, so the delta is provable. */
  @Column({
    name: 'old_items_price',
    type: 'decimal',
    precision: 10,
    scale: 2,
  })
  oldItemsPrice!: number;

  @Column({
    name: 'new_items_price',
    type: 'decimal',
    precision: 10,
    scale: 2,
  })
  newItemsPrice!: number;

  @Column({ type: 'varchar', length: 255, nullable: true })
  reason?: string | null;

  @Column({ type: 'varchar', length: 16, default: PriceProposalStatus.PENDING })
  status!: PriceProposalStatus;

  /** The customer (or admin) who answered. */
  @Column({ name: 'decided_by', type: 'int', nullable: true })
  decidedBy?: number | null;

  @Column({ name: 'decided_at', type: 'timestamp', nullable: true })
  decidedAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
