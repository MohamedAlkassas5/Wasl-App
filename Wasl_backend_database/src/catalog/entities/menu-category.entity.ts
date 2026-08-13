import {
  Column,
  Entity,
  JoinColumn,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Merchant } from '../../merchant/entities/merchant.entity';

/** A tab inside a merchant's menu — "وجبات رئيسية", "مشروبات". */
@Entity('menu_categories')
@Index('idx_menu_categories_merchant', ['merchantId'])
export class MenuCategory {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'merchant_id' })
  merchantId!: number;

  @ManyToOne(() => Merchant, (merchant) => merchant.menuCategories, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'merchant_id' })
  merchant!: Merchant;

  @Column({ length: 120 })
  name!: string;

  @Column({ default: 0 })
  sortOrder!: number;

  @Column({ default: true })
  isActive!: boolean;
}
