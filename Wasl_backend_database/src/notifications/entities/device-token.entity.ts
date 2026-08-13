import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';

export enum DevicePlatform {
  ANDROID = 'android',
  IOS = 'ios',
}

/**
 * One push destination: a device, and the person currently signed in on it.
 *
 * The token is UNIQUE rather than the (user, token) pair, because a token
 * identifies a *device* and a device has one signed-in user at a time. When a
 * driver signs in on a phone their colleague used yesterday, FCM hands back the
 * same token — registering it simply moves it to the new owner. Keyed on the
 * pair instead, the old row would survive and that colleague would keep
 * receiving offers meant for someone else.
 *
 * Tokens are not secrets, but they are personal data: they identify a device
 * and are only ever readable by the server. Nothing here is returned to
 * clients.
 */
@Entity('device_tokens')
@Unique('UQ_device_tokens_token', ['token'])
@Index('idx_device_tokens_user', ['userId'])
export class DeviceToken {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'user_id' })
  userId!: number;

  /** The FCM registration token. Long, opaque, and rotated by the client. */
  @Column({ type: 'varchar', length: 512 })
  token!: string;

  @Column({ type: 'varchar', length: 16, default: DevicePlatform.ANDROID })
  platform!: DevicePlatform;

  /**
   * Last time the client re-registered this token.
   *
   * FCM tokens go stale silently. A token that has not been seen for months
   * almost certainly belongs to an uninstalled app, and this is what a future
   * cleanup would prune on — cheaper than waiting for every send to fail.
   */
  @Column({ name: 'last_seen_at', type: 'timestamp' })
  lastSeenAt!: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
