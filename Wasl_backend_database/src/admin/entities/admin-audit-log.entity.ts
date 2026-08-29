import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

/**
 * What an administrator did, and to what.
 *
 * Admin actions were previously invisible. Cancellation reviews left a trail
 * because the decision is stored on the request row itself, but approving a
 * delivery partner, crediting a wallet, editing the commission percentage or
 * closing a store left nothing behind at all — so "who raised the commission
 * to 40% last Tuesday" had no answer, and neither did "which administrator
 * approved this account".
 *
 * The row is deliberately append-only. Nothing in the codebase updates or
 * deletes one; a log an administrator can edit is not evidence about
 * administrators. There is no FK to `users` for the same reason — the trail
 * has to survive the actor's account being removed, and `adminId` is kept as a
 * plain integer so a deleted admin does not cascade their history away.
 *
 * Writes are best-effort by design: see {@link AdminAuditLogService.record}.
 */
@Entity('admin_audit_log')
@Index('idx_admin_audit_log_admin', ['adminId'])
@Index('idx_admin_audit_log_target', ['targetType', 'targetId'])
@Index('idx_admin_audit_log_created', ['createdAt'])
export class AdminAuditLog {
  @PrimaryGeneratedColumn()
  id!: number;

  /**
   * The acting administrator's user id, taken from the verified JWT — never
   * from a request body. No foreign key: see the class note.
   */
  @Column({ name: 'admin_id' })
  adminId!: number;

  /**
   * What happened, as a stable dotted verb: `approval.review`,
   * `wallet.topup.approve`, `setting.update`, `merchant.availability`.
   *
   * Stable because this is what anyone reading the log filters on; renaming an
   * action orphans the history that used the old name.
   */
  @Column({ type: 'varchar', length: 64 })
  action!: string;

  /** The kind of thing acted on: `user`, `driver`, `merchant`, `setting`… */
  @Column({ name: 'target_type', type: 'varchar', length: 32 })
  targetType!: string;

  /**
   * Which one. A string rather than an integer because not every target is
   * numeric — settings are keyed by name (`commission_percent`).
   */
  @Column({ name: 'target_id', type: 'varchar', length: 128 })
  targetId!: string;

  /**
   * The request detail, after redaction.
   *
   * Never a raw body: {@link redactAuditPayload} strips passwords, tokens,
   * OTPs and document paths first. An audit log is read by more people than
   * the systems that produced it, and a log that quietly accumulates
   * credentials is a breach waiting for someone to grep it.
   */
  @Column({ type: 'jsonb', nullable: true })
  payload?: Record<string, unknown> | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
