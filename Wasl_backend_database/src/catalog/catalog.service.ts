import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
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

  /** Approved merchants, optionally narrowed to one store type. */
  listMerchants(storeType?: string) {
    return this.merchants.find({
      where: {
        status: MerchantStatus.APPROVED,
        ...(storeType ? { storeType } : {}),
      },
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
  async getMenu(merchantId: number) {
    const merchant = await this.merchants.findOne({
      where: { id: merchantId, status: MerchantStatus.APPROVED },
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
      // `restaurant` is kept alongside `merchant` so app builds already
      // shipped keep rendering the header while they migrate.
      merchant,
      restaurant: merchant,
      categories,
      products: products.map((product) => ({
        ...product,
        sizes: (sizesFor[product.id] ?? []).map(toOption),
        addons: (addonsFor[product.id] ?? []).map(toOption),
      })),
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
