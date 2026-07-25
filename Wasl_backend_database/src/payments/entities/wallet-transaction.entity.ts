import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum WalletTxType {
  TOPUP = 'topup', // credit after admin-verified payment
  COMMISSION = 'commission', // debit on completed order
  ADJUSTMENT = 'adjustment', // manual admin correction
}

/**
 * Immutable ledger of every change to a driver's wallet balance. Gives the
 * admin a full audit trail behind the single `balance` figure on the driver.
 */
@Entity('wallet_transactions')
export class WalletTransaction {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'driver_id' })
  driverId!: number;

  // Signed: positive = credit, negative = debit.
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount!: number;

  @Column({ type: 'enum', enum: WalletTxType })
  type!: WalletTxType;

  @Column({ name: 'balance_after', type: 'decimal', precision: 10, scale: 2 })
  balanceAfter!: number;

  @Column({ type: 'text', nullable: true })
  note?: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
