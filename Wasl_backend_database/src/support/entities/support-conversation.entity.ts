import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';

import { User } from '../../users/entities/user.entity';

export enum SupportConversationStatus {
  OPEN = 'open',
  CLOSED = 'closed',
}

/**
 * One support thread between a user and the admin team.
 *
 * ## Why this is not the order chat
 *
 * `order_messages` is keyed by `orderId` and authorised by
 * `assertOrderParticipant` — the two parties to one delivery. Support has
 * neither an order nor a counterparty: the driver is talking to *the platform*,
 * often about something with no order at all ("I transferred 100 EGP and my
 * wallet is still empty"). Reusing the order thread would mean inventing a
 * fake order to hang it on, and would put the admin's side of a private
 * account conversation inside a record that a customer can read. They stay
 * separate on purpose.
 *
 * ## One thread per user
 *
 * `user_id` is UNIQUE. Support here is a continuous conversation, not a
 * ticket queue, so there is nothing to disambiguate — the same reasoning that
 * gives the order chat no thread table. Closing marks it handled; the next
 * message from the user reopens the same thread, keeping their whole history
 * in one place for whoever picks it up next.
 */
@Entity('support_conversations')
export class SupportConversation {
  @PrimaryGeneratedColumn()
  id!: number;

  /** The user this thread belongs to. One thread each — UNIQUE in the DB. */
  @Index('idx_support_conversations_user', { unique: true })
  @Column({ name: 'user_id' })
  userId!: number;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({
    type: 'varchar',
    length: 16,
    default: SupportConversationStatus.OPEN,
  })
  status!: SupportConversationStatus;

  /**
   * Sort key for the admin inbox — the whole point of having this table
   * rather than deriving threads from the messages. Kept current on every
   * append.
   */
  @Index('idx_support_conversations_recent')
  @Column({ name: 'last_message_at', type: 'timestamp', nullable: true })
  lastMessageAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
