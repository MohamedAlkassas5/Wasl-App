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

/** What a message carries. */
export enum OrderMessageKind {
  TEXT = 'text',
  IMAGE = 'image',
  /** A driver's request to change the purchase price. Carries `proposalId`. */
  PRICE_PROPOSAL = 'price_proposal',
  /** The customer's approve/reject of a proposal. Carries `proposalId`. */
  PRICE_DECISION = 'price_decision',
  /** Written by the server, not by a person. */
  SYSTEM = 'system',
}

/** Which side of the order sent it. */
export enum OrderMessageSender {
  CUSTOMER = 'customer',
  DRIVER = 'driver',
  SYSTEM = 'system',
}

/**
 * One message in an order's conversation.
 *
 * There is exactly one conversation per order and it is keyed by `orderId` —
 * no separate thread table, because there is nothing to disambiguate. The same
 * table serves all four order types (restaurant, pharmacy, store, Waslly).
 *
 * Rows are **append-only**. Nothing in the API edits or deletes a message, and
 * that is deliberate: an approved price change and the exchange around it are
 * the record of what the two parties agreed to, and a cancellation dispute is
 * later settled by an admin reading exactly this history.
 */
@Entity('order_messages')
@Index('idx_order_messages_order', ['orderId', 'createdAt'])
@Index('idx_order_messages_unread', ['orderId', 'senderId', 'readAt'])
export class OrderMessage {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'order_id' })
  orderId!: number;

  @ManyToOne(() => Order, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'order_id' })
  order!: Order;

  /** Author. 0 for server-written system messages. */
  @Column({ name: 'sender_id' })
  senderId!: number;

  @Column({
    name: 'sender_role',
    type: 'varchar',
    length: 20,
  })
  senderRole!: OrderMessageSender;

  @Column({ type: 'varchar', length: 24, default: OrderMessageKind.TEXT })
  kind!: OrderMessageKind;

  /** Text content. Null for an image-only message. */
  @Column({ type: 'text', nullable: true })
  body?: string | null;

  /**
   * Storage key of an attached image (`uploads/chat/chat-….jpg`).
   *
   * Served only through `FilesController`, which re-checks that the caller is
   * a party to this order.
   */
  @Column({ name: 'attachment_url', type: 'varchar', nullable: true })
  attachmentUrl?: string | null;

  /** The price proposal this message announces or decides. */
  @Column({ name: 'proposal_id', type: 'int', nullable: true })
  proposalId?: number | null;

  /** When the other party read it. Null while unread. */
  @Column({ name: 'read_at', type: 'timestamp', nullable: true })
  readAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
