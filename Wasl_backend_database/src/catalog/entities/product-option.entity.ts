import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Product } from './product.entity';

/**
 * A required choice that sets the price — "وسط" / "كبير".
 *
 * The customer app has always parsed these; the backend simply had nowhere to
 * store them, so every menu came back with the size choices silently dropped
 * and a single flat price.
 */
@Entity('product_sizes')
@Index('idx_product_sizes_product', ['productId'])
export class ProductSize {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'product_id' })
  productId!: number;

  @ManyToOne(() => Product, (product) => product.sizes, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'product_id' })
  product!: Product;

  @Column({ length: 80 })
  name!: string;

  /** The full price for this size — not a surcharge on top of the base. */
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price!: number;

  @Column({ default: 0 })
  sortOrder!: number;

  @Column({ default: true })
  isAvailable!: boolean;
}

/** An optional paid extra — "جبنة زيادة", "بطاطس وسط". */
@Entity('product_addons')
@Index('idx_product_addons_product', ['productId'])
export class ProductAddon {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'product_id' })
  productId!: number;

  @ManyToOne(() => Product, (product) => product.addons, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'product_id' })
  product!: Product;

  @Column({ length: 80 })
  name!: string;

  /** Added on top of the size (or base) price. */
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price!: number;

  @Column({ default: 0 })
  sortOrder!: number;

  @Column({ default: true })
  isAvailable!: boolean;
}
