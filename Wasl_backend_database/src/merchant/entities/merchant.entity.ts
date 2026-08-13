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

/**
 * Whether the platform has admitted this store at all.
 *
 * An **administrative** state, set by admin review and changing rarely. It is
 * not the same question as "are they open right now" — see
 * {@link Merchant.isAcceptingOrders}.
 */
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

  /**
   * Whether this store is open for business **right now**.
   *
   * Deliberately separate from {@link status}. Approval is administrative and
   * near-permanent: it answers "may this store trade on Wasl at all", and
   * revoking it is a serious act. This is operational and expected to flip
   * daily: the kitchen closed, the owner ran out of gas, it is 3 a.m. Folding
   * the two together would mean closing for the night looked identical to
   * being suspended for misconduct, and re-opening would need an admin review.
   *
   * Also — and this is a different axis again — nothing here relates to
   * `DeliveryPartner.isOnline`. That is a *driver* being available to carry
   * work; this is a *shop* being willing to sell. They share no table, no
   * rule and no consequence: a closed shop does not idle a driver, and a town
   * with no drivers online does not close the shops.
   *
   * V1 has no merchant dashboard, so an admin holds this switch. The column is
   * shaped for the merchant to own later without changing its meaning.
   */
  @Column({
    name: 'is_accepting_orders',
    type: 'boolean',
    default: true,
  })
  isAcceptingOrders!: boolean;

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
