import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Restaurant } from './restaurant.entity';
import { MenuCategory } from './menu-category.entity';

@Entity('products')
export class Product {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  restaurantId!: number;

  @ManyToOne(() => Restaurant, (restaurant) => restaurant.products, {
    onDelete: 'CASCADE',
  })
  restaurant!: Restaurant;

  @Column({ nullable: true })
  categoryId?: number;

  @ManyToOne(() => MenuCategory, { nullable: true, onDelete: 'SET NULL' })
  category?: MenuCategory;

  @Column({ length: 160 })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price!: number;

  @Column({ nullable: true })
  imageUrl?: string;

  @Column({ default: true })
  isAvailable!: boolean;
}
