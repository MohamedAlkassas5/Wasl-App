import { BadRequestException } from '@nestjs/common';

import { buildOrderItems, SellableProduct } from './order-items.builder';
import { OrderItemDto } from './dto/create-order.dto';
import { Product } from '../catalog/entities/product.entity';
import {
  ProductAddon,
  ProductSize,
} from '../catalog/entities/product-option.entity';

/**
 * Who decides what an item costs.
 *
 * The cart used to be flattened into a text blob and stored with whatever
 * `itemsPrice` the app claimed — so the customer's device set the bill, and an
 * order kept no record of what a line had actually cost. These tests pin the
 * replacement: the client sends identifiers, the server prices them from the
 * catalog, and every figure is copied onto the order rather than referenced.
 */
describe('buildOrderItems', () => {
  const sandwich = {
    product: { id: 1, name: 'ساندويتش دجاج', price: 0 } as Product,
    sizes: [
      { id: 11, name: 'وسط', price: 65, isAvailable: true } as ProductSize,
      { id: 12, name: 'كبير', price: 85, isAvailable: true } as ProductSize,
    ],
    addons: [
      {
        id: 101,
        name: 'جبنة زيادة',
        price: 10,
        isAvailable: true,
      } as ProductAddon,
      { id: 102, name: 'بطاطس', price: 20, isAvailable: true } as ProductAddon,
    ],
  };

  const juice: SellableProduct = {
    product: { id: 2, name: 'عصير طازج', price: 25 } as Product,
    sizes: [],
    addons: [],
  };

  const catalog: SellableProduct[] = [sandwich, juice];

  const line = (overrides: Partial<OrderItemDto> = {}): OrderItemDto => ({
    productId: 2,
    quantity: 1,
    ...overrides,
  });

  describe('pricing', () => {
    it('prices a plain item from the catalog', () => {
      const { items, itemsTotal } = buildOrderItems([line()], catalog);

      expect(items[0].unitPrice).toBe(25);
      expect(items[0].lineTotal).toBe(25);
      expect(itemsTotal).toBe(25);
    });

    it('uses the chosen size price, not the base price', () => {
      const { items } = buildOrderItems(
        [line({ productId: 1, sizeId: 12 })],
        catalog,
      );

      expect(items[0].unitPrice).toBe(85);
      expect(items[0].sizeName).toBe('كبير');
    });

    it('adds add-ons on top of the size price', () => {
      const { items } = buildOrderItems(
        [line({ productId: 1, sizeId: 11, addonIds: [101, 102] })],
        catalog,
      );

      expect(items[0].unitPrice).toBe(95); // 65 + 10 + 20
      expect(items[0].addons).toEqual([
        { name: 'جبنة زيادة', price: 10 },
        { name: 'بطاطس', price: 20 },
      ]);
    });

    it('multiplies by quantity', () => {
      const { items, itemsTotal } = buildOrderItems(
        [line({ productId: 1, sizeId: 11, quantity: 3 })],
        catalog,
      );

      expect(items[0].lineTotal).toBe(195);
      expect(itemsTotal).toBe(195);
    });

    it('totals a multi-line cart', () => {
      const { itemsTotal } = buildOrderItems(
        [
          line({ productId: 1, sizeId: 12, quantity: 2 }), // 170
          line({ productId: 2, quantity: 3 }), // 75
        ],
        catalog,
      );

      expect(itemsTotal).toBe(245);
    });

    it('ignores any price the client tries to attach to a line', () => {
      // The DTO has no price field at all; even a smuggled one is not read.
      const { items } = buildOrderItems(
        [
          {
            ...line({ productId: 2 }),
            unitPrice: 1,
            price: 1,
          } as unknown as OrderItemDto,
        ],
        catalog,
      );

      expect(items[0].unitPrice).toBe(25);
    });
  });

  describe('refusals', () => {
    it('rejects an item that is not on this merchant’s menu', () => {
      // Delisted between browsing and checkout, or simply another shop's.
      expect(() =>
        buildOrderItems([line({ productId: 999 })], catalog),
      ).toThrow(BadRequestException);
    });

    it('rejects an empty cart', () => {
      expect(() => buildOrderItems([], catalog)).toThrow(BadRequestException);
    });

    it('demands a size when the item has sizes', () => {
      expect(() => buildOrderItems([line({ productId: 1 })], catalog)).toThrow(
        /الحجم/,
      );
    });

    it('rejects a size that belongs to a different item', () => {
      expect(() =>
        buildOrderItems([line({ productId: 1, sizeId: 999 })], catalog),
      ).toThrow(BadRequestException);
    });

    it('rejects a size on an item that has none', () => {
      expect(() =>
        buildOrderItems([line({ productId: 2, sizeId: 11 })], catalog),
      ).toThrow(BadRequestException);
    });

    it('rejects an unavailable size', () => {
      const withSoldOutSize: SellableProduct = {
        ...sandwich,
        sizes: [{ ...sandwich.sizes[0], isAvailable: false }],
      };
      expect(() =>
        buildOrderItems(
          [line({ productId: 1, sizeId: 11 })],
          [withSoldOutSize],
        ),
      ).toThrow(BadRequestException);
    });

    it('rejects an unavailable add-on', () => {
      const withSoldOutAddon: SellableProduct = {
        ...sandwich,
        addons: [{ ...sandwich.addons[0], isAvailable: false }],
      };
      expect(() =>
        buildOrderItems(
          [line({ productId: 1, sizeId: 11, addonIds: [101] })],
          [withSoldOutAddon],
        ),
      ).toThrow(BadRequestException);
    });

    it('rejects an add-on from a different item', () => {
      expect(() =>
        buildOrderItems(
          [line({ productId: 1, sizeId: 11, addonIds: [999] })],
          catalog,
        ),
      ).toThrow(BadRequestException);
    });
  });

  describe('the snapshot', () => {
    it('copies the name so a later rename cannot rewrite history', () => {
      const { items } = buildOrderItems([line({ productId: 2 })], catalog);
      expect(items[0].name).toBe('عصير طازج');

      // The catalog row moves on; the order does not.
      juice.product.name = 'عصير مانجو';
      expect(items[0].name).toBe('عصير طازج');
    });

    it('keeps the product id for analytics', () => {
      const { items } = buildOrderItems([line({ productId: 2 })], catalog);
      expect(items[0].productId).toBe(2);
    });

    it('keeps the per-line note', () => {
      const { items } = buildOrderItems(
        [line({ productId: 2, note: '  بدون تلج  ' })],
        catalog,
      );
      expect(items[0].note).toBe('بدون تلج');
    });

    it('stores null rather than an empty add-on list', () => {
      const { items } = buildOrderItems([line({ productId: 2 })], catalog);
      expect(items[0].addons).toBeNull();
    });

    it('produces a readable description for the driver', () => {
      const { description } = buildOrderItems(
        [
          line({
            productId: 1,
            sizeId: 12,
            addonIds: [101],
            quantity: 2,
            note: 'بدون بصل',
          }),
        ],
        catalog,
      );

      expect(description).toContain('2× ساندويتش دجاج');
      expect(description).toContain('كبير');
      expect(description).toContain('جبنة زيادة');
      expect(description).toContain('بدون بصل');
      expect(description).toContain('190.00');
    });
  });
});
