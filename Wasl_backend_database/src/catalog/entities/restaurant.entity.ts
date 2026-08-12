import { Column, Entity, OneToMany, PrimaryGeneratedColumn } from 'typeorm';
import { MenuCategory } from './menu-category.entity';
import { Product } from './product.entity';

@Entity('restaurants')
export class Restaurant {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ length: 160 })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ type: 'text', nullable: true })
  address?: string;

  @Column({ nullable: true })
  imageUrl?: string;

  @Column({ default: true })
  isActive!: boolean;

  @Column({ type: 'text', nullable: true })
  openingHours?: string;

  @OneToMany(() => MenuCategory, (category) => category.restaurant)
  categories!: MenuCategory[];

  @OneToMany(() => Product, (product) => product.restaurant)
  products!: Product[];
}
