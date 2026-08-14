import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';

/**
 * One refresh token, as the server remembers it.
 *
 * **Only a hash is stored.** The token itself is random bytes handed to the
 * client once and never written down here, so a dump of this table is not a
 * pile of working credentials — the same reasoning that keeps passwords
 * bcrypted. SHA-256 rather than bcrypt because this value is already 32 bytes
 * of entropy from `randomBytes`: there is no weak password to slow an attacker
 * down over, and refresh runs on a request path where a deliberate KDF would
 * just be latency.
 *
 * Rotation is what the `familyId` and `usedAt` columns exist for. Every refresh
 * spends the presented token and issues a new one in the same family. Present a
 * token that has already been spent and there are only two explanations —
 * either it was stolen and replayed, or the legitimate client is replaying it —
 * and neither is a state worth guessing at, so the whole family is revoked and
 * the user signs in again.
 */
@Entity('refresh_tokens')
@Unique('UQ_refresh_tokens_hash', ['tokenHash'])
@Index('idx_refresh_tokens_user', ['userId'])
@Index('idx_refresh_tokens_family', ['familyId'])
export class RefreshToken {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'user_id' })
  userId!: number;

  /** SHA-256 of the token. The token itself is never persisted. */
  @Column({ name: 'token_hash', type: 'varchar', length: 64 })
  tokenHash!: string;

  /**
   * Every token descended from one sign-in shares this.
   *
   * Reuse revokes the family rather than the single row, because by the time a
   * spent token comes back the attacker may already hold the token that
   * replaced it — killing only what was presented would leave them signed in.
   */
  @Column({ name: 'family_id', type: 'varchar', length: 36 })
  familyId!: string;

  /** When this token was spent by a refresh. Null while it is still usable. */
  @Column({ name: 'used_at', type: 'timestamp', nullable: true })
  usedAt?: Date | null;

  /** Set on sign-out, on account closure, and on reuse detection. */
  @Column({ name: 'revoked_at', type: 'timestamp', nullable: true })
  revokedAt?: Date | null;

  @Column({ name: 'expires_at', type: 'timestamp' })
  expiresAt!: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
