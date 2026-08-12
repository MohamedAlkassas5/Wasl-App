import { Column, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Restaurant } from './restaurant.entity';

@Entity('menu_categories')
export class MenuCategory {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  restaurantId!: number;

  @ManyToOne(() => Restaurant, (restaurant) => restaurant.categories, {
    onDelete: 'CASCADE',
  })
  restaurant!: Restaurant;

  @Column({ length: 120 })
  name!: string;

  @Column({ default: 0 })
  sortOrder!: number;

  @Column({ default: true })
  isActive!: boolean;
}
