import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsSelect, In, Repository } from 'typeorm';
import { MenuCategory } from './entities/menu-category.entity';
import { Product } from './entities/product.entity';
import { ProductAddon, ProductSize } from './entities/product-option.entity';
import { Merchant, MerchantStatus } from '../merchant/entities/merchant.entity';
import { CreateMenuCategoryDto } from './dto/create-menu-category.dto';
import { CreateProductDto } from './dto/create-product.dto';

/** The shape a size or add-on is exposed to the app in. */
function toOption(option: ProductSize | ProductAddon) {
  return { id: option.id, name: option.name, price: Number(option.price) };
}

/**
 * The merchant columns a customer is allowed to see.
 *
 * `adminNotes` and `ownerId` are absent on purpose. `adminNotes` holds the
 * free text an admin types when approving or rejecting a store — see
 * `AdminService.reviewApproval`, which writes it onto the merchant row — and
 * `ownerId` is the internal user id behind the shop. Neither is the
 * customer's business, and both were being served to **unauthenticated**
 * callers, because the reads below returned whole entities.
 *
 * Applied as a `select` on the query rather than stripped from the result
 * afterwards: the columns never leave the database, so a later refactor
 * cannot leak them again by forgetting to map a field.
 *
 * The admin reads are deliberately not routed through this. `getMenuForAdmin`
 * still returns the whole row, because an admin is exactly who `adminNotes`
 * was written for.
 */
const CUSTOMER_MERCHANT_COLUMNS: FindOptionsSelect<Merchant> = {
  id: true,
  storeName: true,
  storeType: true,
  logo: true,
  coverImage: true,
  latitude: true,
  longitude: true,
  addressDetails: true,
  status: true,
  isAcceptingOrders: true,
  createdAt: true,
  updatedAt: true,
};

/**
 * A merchant's catalog.
 *
 * There is no separate restaurant catalog: a restaurant, a pharmacy and a shop
 * are merchants that differ by `storeType`, and they all read through here.
 */
@Injectable()
export class CatalogService {
  constructor(
    @InjectRepository(Merchant)
    private readonly merchants: Repository<Merchant>,
    @InjectRepository(MenuCategory)
    private readonly categories: Repository<MenuCategory>,
    @InjectRepository(Product) private readonly products: Repository<Product>,
    @InjectRepository(ProductSize)
    private readonly sizes: Repository<ProductSize>,
    @InjectRepository(ProductAddon)
    private readonly addons: Repository<ProductAddon>,
  ) {}

  /**
   * Approved merchants, optionally narrowed to one store type.
   *
   * Unauthenticated — it backs the customer store list, and `/restaurants` is
   * an alias onto this same method, so the projection below is what protects
   * both routes.
   */
  listMerchants(storeType?: string) {
    return this.merchants.find({
      where: {
        status: MerchantStatus.APPROVED,
        ...(storeType ? { storeType } : {}),
      },
      select: CUSTOMER_MERCHANT_COLUMNS,
      order: { storeName: 'ASC' },
    });
  }

  /**
   * The menu a customer sees.
   *
   * Only approved merchants resolve — an unapproved store is not open for
   * business, and its catalog must not be browsable through a guessed id.
   * Sizes and add-ons are attached to their products in one pass rather than
   * a query per item.
   */
  /**
   * The same catalog, but as an administrator has to see it.
   *
   * `getMenu` below is the *customer* menu and filters to `isAvailable` /
   * `isActive` — correct there, and unusable for management: a product the
   * admin switches off vanishes from the list that holds the switch, so it can
   * never be switched back on. This returns everything, and is admin-guarded
   * at the controller.
   *
   * It also does not require the merchant to be APPROVED. Building a menu
   * before a store goes live is exactly when this is needed, and the panel's
   * own store list only offers approved merchants anyway.
   */
  async getMenuForAdmin(merchantId: number) {
    const merchant = await this.merchants.findOne({
      where: { id: merchantId },
    });
    if (!merchant) throw new NotFoundException('المتجر غير موجود');

    const [categories, products] = await Promise.all([
      this.categories.find({
        where: { merchantId },
        order: { sortOrder: 'ASC', name: 'ASC' },
      }),
      this.products.find({
        where: { merchantId },
        order: { name: 'ASC' },
      }),
    ]);

    return { merchant, categories, products };
  }

  async getMenu(merchantId: number) {
    const merchant = await this.merchants.findOne({
      where: { id: merchantId, status: MerchantStatus.APPROVED },
      select: CUSTOMER_MERCHANT_COLUMNS,
    });
    if (!merchant) throw new NotFoundException('المتجر غير متاح حالياً');

    const [categories, products] = await Promise.all([
      this.categories.find({
        where: { merchantId, isActive: true },
        order: { sortOrder: 'ASC', name: 'ASC' },
      }),
      this.products.find({
        where: { merchantId, isAvailable: true },
        order: { name: 'ASC' },
      }),
    ]);

    const productIds = products.map((p) => p.id);
    const [sizes, addons] = productIds.length
      ? await Promise.all([
          this.sizes.find({
            where: { productId: In(productIds), isAvailable: true },
            order: { sortOrder: 'ASC' },
          }),
          this.addons.find({
            where: { productId: In(productIds), isAvailable: true },
            order: { sortOrder: 'ASC' },
          }),
        ])
      : [[], []];

    const byProduct = <T extends { productId: number }>(rows: T[]) =>
      rows.reduce<Record<number, T[]>>((acc, row) => {
        (acc[row.productId] ??= []).push(row);
        return acc;
      }, {});
    const sizesFor = byProduct(sizes);
    const addonsFor = byProduct(addons);

    return {
      // One merchant object, once. `restaurant` used to be a second copy of
      // this same row, kept for app builds that were mid-migration; nothing
      // reads it now (the client takes `categories` and `products` only), and
      // a duplicate is a second place for a field to leak from.
      merchant,
      categories,
      products: products.map((product) => ({
        ...product,
        sizes: (sizesFor[product.id] ?? []).map(toOption),
        addons: (addonsFor[product.id] ?? []).map(toOption),
      })),
    };
  }

  /**
   * The one place that answers "may this store take an order right now".
   *
   * Both halves have to hold: admitted to the platform at all, and open for
   * business at this moment. They fail differently on purpose — "we no longer
   * work with this store" and "the kitchen is closed" are different facts and
   * a customer staring at a rejected cart deserves the right one.
   *
   * Every path that creates an order goes through here rather than repeating
   * the pair of conditions, so there is no route where one is checked and the
   * other forgotten.
   */
  async assertMerchantCanTakeOrders(merchantId: number): Promise<Merchant> {
    const merchant = await this.merchants.findOneBy({ id: merchantId });

    if (!merchant || merchant.status !== MerchantStatus.APPROVED) {
      throw new NotFoundException('المتجر غير متاح حالياً');
    }
    if (!merchant.isAcceptingOrders) {
      throw new BadRequestException(
        `${merchant.storeName} مقفول دلوقتي ومش بيستقبل طلبات. جرّب تاني بعدين أو اختار متجر تاني.`,
      );
    }

    return merchant;
  }

  /** Admin toggles a store open or closed. Approval is a separate decision. */
  async setAcceptingOrders(merchantId: number, isAcceptingOrders: boolean) {
    const merchant = await this.merchants.findOneBy({ id: merchantId });
    if (!merchant) throw new NotFoundException('المتجر غير موجود');

    merchant.isAcceptingOrders = isAcceptingOrders;
    await this.merchants.save(merchant);

    // Orders already placed are deliberately untouched. Closing a shop stops
    // new business; it does not reach back and cancel a delivery someone is
    // already driving, or one the kitchen has already cooked.
    return {
      success: true,
      merchantId,
      isAcceptingOrders: merchant.isAcceptingOrders,
    };
  }

  /**
   * A single product with its options, resolved fresh from the catalog.
   * Used when an order is placed, so the price charged is the merchant's
   * price and not a number the client sent.
   */
  async getSellableProducts(merchantId: number, productIds: number[]) {
    if (productIds.length === 0) return [];
    const products = await this.products.find({
      where: { id: In(productIds), merchantId, isAvailable: true },
    });
    const found = products.map((p) => p.id);
    const [sizes, addons] = found.length
      ? await Promise.all([
          this.sizes.find({ where: { productId: In(found) } }),
          this.addons.find({ where: { productId: In(found) } }),
        ])
      : [[], []];

    return products.map((product) => ({
      product,
      sizes: sizes.filter((s) => s.productId === product.id),
      addons: addons.filter((a) => a.productId === product.id),
    }));
  }

  async createCategory(dto: CreateMenuCategoryDto) {
    await this.assertMerchantExists(dto.merchantId);
    return this.categories.save(this.categories.create(dto));
  }

  async createProduct(dto: CreateProductDto) {
    await this.assertMerchantExists(dto.merchantId);
    return this.products.save(
      this.products.create({ ...dto, isAvailable: dto.isAvailable ?? true }),
    );
  }

  async updateProduct(id: number, dto: Partial<CreateProductDto>) {
    const entity = await this.products.preload({ id, ...dto });
    if (!entity) throw new NotFoundException('Product not found');
    return this.products.save(entity);
  }

  private async assertMerchantExists(merchantId: number) {
    const merchant = await this.merchants.findOneBy({ id: merchantId });
    if (!merchant) throw new NotFoundException('المتجر غير موجود');
  }
}
