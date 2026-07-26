import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * One in-flight OTP challenge per phone number. The code itself is never
 * stored in plaintext — only a bcrypt hash. Includes expiry, attempt counter
 * and a resend timestamp so the service can enforce brute-force protection.
 */
@Entity('otp_verifications')
export class OtpVerification {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 20, unique: true })
  phone!: string;

  @Column({ name: 'otp_hash', type: 'varchar' })
  otpHash!: string;

  @Column({ name: 'expires_at', type: 'timestamp' })
  expiresAt!: Date;

  @Column({ type: 'int', default: 0 })
  attempts!: number;

  @Column({ name: 'sends_in_window', type: 'int', default: 0 })
  sendsInWindow!: number;

  @Column({ name: 'window_started_at', type: 'timestamp', nullable: true })
  windowStartedAt?: Date;

  @Column({ name: 'last_sent_at', type: 'timestamp', nullable: true })
  lastSentAt?: Date;

  @Column({ type: 'boolean', default: false })
  verified!: boolean;

  /**
   * When the code was proven correct. A successful verification is only good
   * for a limited window afterwards (see OtpService.VERIFIED_WINDOW_MS) — this
   * is what stops a phone that was verified weeks ago from still being
   * accepted as proof of ownership at registration or password reset.
   */
  // Typed `| null` rather than optional on purpose: TypeORM's `save()` skips
  // `undefined` properties, so clearing this on resend must write an explicit
  // null.
  @Column({ name: 'verified_at', type: 'timestamp', nullable: true })
  verifiedAt!: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
