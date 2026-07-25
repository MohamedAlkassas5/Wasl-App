import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum TopUpMethod {
  VODAFONE_CASH = 'vodafone_cash',
  INSTAPAY = 'instapay',
}

export enum TopUpStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

/**
 * A driver-submitted wallet top-up. The driver first pays into the platform's
 * Vodafone Cash / InstaPay account, then files this request with the amount and
 * a proof screenshot. Balance is credited ONLY after an admin verifies the
 * payment — drivers can no longer self-credit their wallet.
 */
@Entity('wallet_topup_requests')
export class WalletTopUpRequest {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'driver_id' })
  driverId!: number;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount!: number;

  @Column({ type: 'enum', enum: TopUpMethod })
  method!: TopUpMethod;

  // The sender's wallet number / transaction reference the driver paid from.
  @Column({ name: 'sender_reference', type: 'varchar', nullable: true })
  senderReference?: string;

  @Column({ name: 'proof_image_url', type: 'varchar', nullable: true })
  proofImageUrl?: string;

  @Column({ type: 'enum', enum: TopUpStatus, default: TopUpStatus.PENDING })
  status!: TopUpStatus;

  @Column({ name: 'admin_note', type: 'text', nullable: true })
  adminNote?: string;

  @Column({ name: 'reviewed_by_admin_id', type: 'int', nullable: true })
  reviewedByAdminId?: number;

  @Column({ name: 'reviewed_at', type: 'timestamp', nullable: true })
  reviewedAt?: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
