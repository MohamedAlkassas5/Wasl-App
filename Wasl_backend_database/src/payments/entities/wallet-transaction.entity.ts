import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Unique,
} from 'typeorm';

export enum WalletTxType {
  TOPUP = 'topup', // credit after admin-verified payment
  COMMISSION = 'commission', // debit on completed order
  ADJUSTMENT = 'adjustment', // manual admin correction
  CANCELLATION_PENALTY = 'cancellation_penalty', // debit when an accepted order is cancelled
  PENALTY_REFUND = 'penalty_refund', // credit when an admin finds the driver not at fault
}

/**
 * Immutable ledger of every change to a driver's wallet balance. Gives the
 * admin a full audit trail behind the single `balance` figure on the driver.
 */
@Entity('wallet_transactions')
@Unique('UQ_wallet_transactions_reference', ['reference'])
export class WalletTransaction {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'driver_id' })
  driverId!: number;

  /**
   * Idempotency key for money that must only ever move once — currently the
   * commission on an order (`order-<id>-commission`).
   *
   * This is the *database's* guarantee, not the service's: two concurrent
   * completions both passing their in-code checks still collide on the unique
   * constraint, and the loser's whole transaction rolls back. Null for entries
   * that are legitimately repeatable, such as manual admin adjustments.
   */
  @Column({ type: 'varchar', length: 120, nullable: true })
  reference?: string | null;

  /** The order this entry settles, when it settles one. */
  @Column({ name: 'order_id', type: 'int', nullable: true })
  orderId?: number | null;

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
