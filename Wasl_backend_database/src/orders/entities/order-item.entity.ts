import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Order } from './order.entity';
import { Product } from '../../catalog/entities/product.entity';

/**
 * One line of an order, frozen at the moment it was placed.
 *
 * The cart used to be flattened into a single `itemsDescription` string, so an
 * order was a paragraph of text: nothing could total it, verify it, or say what
 * a line had actually cost. Worse, anything that *did* need a price had to go
 * back to the catalog — which is editable — so last month's order would quietly
 * re-price itself when a merchant raised a menu item.
 *
 * Every field a customer was charged on is therefore copied here rather than
 * referenced. `productId` is kept for analytics and is deliberately nullable
 * with `SET NULL`: the item may be delisted later, and that must not take the
 * order's own record with it.
 */
@Entity('order_items')
@Index('idx_order_items_order', ['orderId'])
export class OrderItem {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'order_id' })
  orderId!: number;

  @ManyToOne(() => Order, (order) => order.items, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'order_id' })
  order!: Order;

  /** Points at the catalog row this came from, when it still exists. */
  @Column({ name: 'product_id', type: 'int', nullable: true })
  productId?: number | null;

  @ManyToOne(() => Product, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'product_id' })
  product?: Product | null;

  // ─── snapshot ────────────────────────────────────────────────────────────

  @Column({ length: 160 })
  name!: string;

  /** The chosen size's name, e.g. "كبير". Null when the item has no sizes. */
  @Column({ name: 'size_name', type: 'varchar', length: 80, nullable: true })
  sizeName?: string | null;

  /** Price of one unit including its add-ons, as charged. */
  @Column({ name: 'unit_price', type: 'decimal', precision: 10, scale: 2 })
  unitPrice!: number;

  @Column({ type: 'int' })
  quantity!: number;

  /** `unitPrice × quantity`, stored so a total never depends on recomputation. */
  @Column({ name: 'line_total', type: 'decimal', precision: 10, scale: 2 })
  lineTotal!: number;

  /**
   * The add-ons chosen on this line, as `[{ name, price }]`.
   *
   * Stored as JSON rather than its own table on purpose: these are a frozen
   * copy, never queried or joined, and only ever read back with their line.
   * A table would imply they are still live catalog rows, which is the exact
   * mistake this entity exists to avoid.
   */
  @Column({ type: 'jsonb', nullable: true })
  addons?: { name: string; price: number }[] | null;

  /** "بدون بصل" — the customer's note for this line. */
  @Column({ type: 'text', nullable: true })
  note?: string | null;
}
