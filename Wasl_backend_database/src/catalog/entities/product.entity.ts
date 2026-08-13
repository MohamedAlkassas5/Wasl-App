import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { MenuCategory } from './menu-category.entity';
import { Merchant } from '../../merchant/entities/merchant.entity';
import { ProductAddon, ProductSize } from './product-option.entity';

/**
 * One item a merchant sells.
 *
 * Belongs to a `Merchant`, not to a separate `Restaurant`: the merchant is the
 * business that owns it, has an approved status, an owner account and a store
 * type. A restaurant, a pharmacy and a shop are all merchants that differ by
 * `storeType`, which is why one catalog serves all three.
 */
@Entity('products')
@Index('idx_products_merchant_available', ['merchantId', 'isAvailable'])
export class Product {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'merchant_id' })
  merchantId!: number;

  @ManyToOne(() => Merchant, (merchant) => merchant.products, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'merchant_id' })
  merchant!: Merchant;

  @Column({ nullable: true })
  categoryId?: number;

  @ManyToOne(() => MenuCategory, { nullable: true, onDelete: 'SET NULL' })
  category?: MenuCategory;

  @Column({ length: 160 })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  /**
   * Price when the item has no sizes. When {@link sizes} is non-empty the
   * chosen size's price is what the customer pays, and this is ignored.
   */
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price!: number;

  @Column({ nullable: true })
  imageUrl?: string;

  @Column({ default: true })
  isAvailable!: boolean;

  /** Surfaced under the menu's "الأكثر طلباً" tab. */
  @Column({ name: 'is_popular', default: false })
  isPopular!: boolean;

  @OneToMany(() => ProductSize, (size) => size.product)
  sizes!: ProductSize[];

  @OneToMany(() => ProductAddon, (addon) => addon.product)
  addons!: ProductAddon[];
}
