import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToMany,
  OneToOne,
  JoinColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

import { User } from '../../users/entities/user.entity';
import { MenuCategory } from '../../catalog/entities/menu-category.entity';
import { Product } from '../../catalog/entities/product.entity';

export enum MerchantStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  SUSPENDED = 'suspended',
}

@Entity('merchants')
export class Merchant {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({
    name: 'owner_id',
    unique: true,
  })
  ownerId!: number;

  @OneToOne(() => User, (user) => user.merchant, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({
    name: 'owner_id',
  })
  user!: User;

  @Column({
    name: 'store_name',
    length: 150,
  })
  storeName!: string;

  @Column({
    name: 'store_type',
    length: 100,
  })
  storeType!: string;

  @Column({
    nullable: true,
  })
  logo?: string;

  @Column({
    name: 'cover_image',
    nullable: true,
  })
  coverImage?: string;

  // 🎯 الـ GPS جاهز ومثالي جداً بحسابات الـ double precision ومستعد للـ Query
  @Column({
    type: 'double precision',
    nullable: true,
  })
  latitude?: number;

  @Column({
    type: 'double precision',
    nullable: true,
  })
  longitude?: number;

  @Column({
    name: 'address_details',
    type: 'text',
    nullable: true,
  })
  addressDetails?: string;

  @Column({
    type: 'enum',
    enum: MerchantStatus,
    default: MerchantStatus.PENDING,
  })
  status!: MerchantStatus;

  @Column({
    name: 'admin_notes',
    type: 'text',
    nullable: true,
  })
  adminNotes?: string;

  /**
   * The merchant's own catalog.
   *
   * There is no separate `Restaurant` entity: a restaurant, a pharmacy and a
   * shop are all merchants distinguished by {@link storeType}. Keeping a
   * second business entity alongside this one is what made the customer app
   * hand a `merchants.id` to a lookup against a different table entirely.
   */
  @OneToMany(() => MenuCategory, (category) => category.merchant)
  menuCategories!: MenuCategory[];

  @OneToMany(() => Product, (product) => product.merchant)
  products!: Product[];

  @CreateDateColumn({
    name: 'created_at',
  })
  createdAt!: Date;

  @UpdateDateColumn({
    name: 'updated_at',
  })
  updatedAt!: Date;
}
