import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';

import { SupportConversation } from './support-conversation.entity';

/** What a support message carries. */
export enum SupportMessageKind {
  TEXT = 'text',
  IMAGE = 'image',
  /** Written by the server, not by a person (e.g. the opening greeting). */
  SYSTEM = 'system',
}

/**
 * Which side wrote it.
 *
 * 🔐 Always derived from the authenticated caller's role on the server, never
 * taken from the request body. It is what the app renders each bubble from, so
 * a client that could set it could paint its own message as an official reply
 * from the admin team.
 */
export enum SupportMessageSender {
  USER = 'user',
  ADMIN = 'admin',
  SYSTEM = 'system',
}

/**
 * One message in a support thread. Append-only, like `order_messages`:
 * nothing in the API edits or deletes a row, because this history is the
 * record of what support actually promised a driver about their money.
 */
@Entity('support_messages')
@Index('idx_support_messages_conversation', ['conversationId', 'createdAt'])
// The unread badge on both sides: "this thread, from the other side, unread".
@Index('idx_support_messages_unread', ['conversationId', 'senderRole', 'readAt'])
export class SupportMessage {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'conversation_id' })
  conversationId!: number;

  @ManyToOne(() => SupportConversation, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conversation_id' })
  conversation!: SupportConversation;

  /** Author's user id. 0 for server-written system messages. */
  @Column({ name: 'sender_id' })
  senderId!: number;

  @Column({ name: 'sender_role', type: 'varchar', length: 16 })
  senderRole!: SupportMessageSender;

  @Column({ type: 'varchar', length: 16, default: SupportMessageKind.TEXT })
  kind!: SupportMessageKind;

  /** Text content. Null for an image-only message. */
  @Column({ type: 'text', nullable: true })
  body?: string | null;

  /**
   * Storage key of an attached image (`uploads/support/support-….jpg`) —
   * usually the transfer screenshot behind a wallet complaint.
   *
   * Served only through `FilesController`, which re-checks that the caller
   * either owns the thread or is an admin.
   */
  @Column({ name: 'attachment_url', type: 'varchar', nullable: true })
  attachmentUrl?: string | null;

  /** When the other side read it. Null while unread. */
  @Column({ name: 'read_at', type: 'timestamp', nullable: true })
  readAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
