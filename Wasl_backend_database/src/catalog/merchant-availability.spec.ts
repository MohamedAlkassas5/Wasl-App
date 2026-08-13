import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { CatalogService } from './catalog.service';
import { MenuCategory } from './entities/menu-category.entity';
import { Product } from './entities/product.entity';
import { ProductAddon, ProductSize } from './entities/product-option.entity';
import { Merchant, MerchantStatus } from '../merchant/entities/merchant.entity';

/**
 * Whether a store may take an order right now.
 *
 * Two independent conditions, and keeping them independent is the point.
 * `status` is administrative — may this store trade on Wasl at all — and moves
 * rarely, by admin review. `isAcceptingOrders` is operational and expected to
 * flip daily. Folded together, closing for the night would have looked
 * identical to being suspended for misconduct, and re-opening would have
 * needed an approval review.
 *
 * Neither has anything to do with `DeliveryPartner.isOnline`. That is a driver
 * being free to carry work; this is a shop being willing to sell.
 */
describe('merchant availability (CP6-D)', () => {
  let merchant: Partial<Merchant> | null;
  let saved: Partial<Merchant>[];
  let service: CatalogService;

  const openShop = (overrides: Partial<Merchant> = {}): Partial<Merchant> => ({
    id: 3,
    storeName: 'مطعم الشرقاوي',
    status: MerchantStatus.APPROVED,
    isAcceptingOrders: true,
    ...overrides,
  });

  const build = async (row: Partial<Merchant> | null) => {
    merchant = row;
    saved = [];

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogService,
        {
          provide: getRepositoryToken(Merchant),
          useValue: {
            findOneBy: () => Promise.resolve(merchant),
            save: (m: Partial<Merchant>) => {
              saved.push({ ...m });
              return Promise.resolve(m);
            },
            find: () => Promise.resolve([]),
            findOne: () => Promise.resolve(merchant),
          },
        },
        { provide: getRepositoryToken(MenuCategory), useValue: {} },
        { provide: getRepositoryToken(Product), useValue: {} },
        { provide: getRepositoryToken(ProductSize), useValue: {} },
        { provide: getRepositoryToken(ProductAddon), useValue: {} },
      ],
    }).compile();

    service = module.get(CatalogService);
  };

  describe('a store that may take orders', () => {
    it('accepts an approved, open store', async () => {
      await build(openShop());

      await expect(
        service.assertMerchantCanTakeOrders(3),
      ).resolves.toMatchObject({ id: 3 });
    });
  });

  describe('a store that may not', () => {
    it('refuses a store that is closed right now', async () => {
      await build(openShop({ isAcceptingOrders: false }));

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('names the store when it is closed, so the message is actionable', async () => {
      await build(openShop({ isAcceptingOrders: false }));

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        /مطعم الشرقاوي/,
      );
    });

    it('refuses a suspended store', async () => {
      await build(
        openShop({ status: MerchantStatus.SUSPENDED, isAcceptingOrders: true }),
      );

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('refuses a store still awaiting approval', async () => {
      await build(openShop({ status: MerchantStatus.PENDING }));

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('refuses a rejected store', async () => {
      await build(openShop({ status: MerchantStatus.REJECTED }));

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('refuses a store that does not exist', async () => {
      await build(null);

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('the two conditions are independent', () => {
    it('being open does not rescue an unapproved store', async () => {
      await build(
        openShop({ status: MerchantStatus.PENDING, isAcceptingOrders: true }),
      );

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('being approved does not rescue a closed store', async () => {
      await build(
        openShop({ status: MerchantStatus.APPROVED, isAcceptingOrders: false }),
      );

      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('reports the two refusals differently', async () => {
      // A customer told "we do not work with this store" when the truth is
      // "the kitchen shut twenty minutes ago" will not come back later.
      await build(openShop({ status: MerchantStatus.SUSPENDED }));
      const unapproved = await service
        .assertMerchantCanTakeOrders(3)
        .catch((e: Error) => e);

      await build(openShop({ isAcceptingOrders: false }));
      const closed = await service
        .assertMerchantCanTakeOrders(3)
        .catch((e: Error) => e);

      expect((unapproved as Error).message).not.toBe((closed as Error).message);
    });
  });

  describe('the admin switch', () => {
    it('closes a store', async () => {
      await build(openShop());

      const result = await service.setAcceptingOrders(3, false);

      expect(result).toMatchObject({ success: true, isAcceptingOrders: false });
      expect(saved[0].isAcceptingOrders).toBe(false);
    });

    it('opens it again', async () => {
      await build(openShop({ isAcceptingOrders: false }));

      const result = await service.setAcceptingOrders(3, true);

      expect(result).toMatchObject({ isAcceptingOrders: true });
      expect(saved[0].isAcceptingOrders).toBe(true);
    });

    it('never touches the approval status', async () => {
      // Closing for the night must not read as a judgement on the store, and
      // re-opening must not need an admin approval review.
      await build(openShop());

      await service.setAcceptingOrders(3, false);

      expect(saved[0].status).toBe(MerchantStatus.APPROVED);
    });

    it('refuses to toggle a store that does not exist', async () => {
      await build(null);

      await expect(service.setAcceptingOrders(3, false)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('can close a store that was never approved, without approving it', async () => {
      // The switch is orthogonal, so it works on any row it finds — but it
      // cannot be used to sneak a pending store into service.
      await build(openShop({ status: MerchantStatus.PENDING }));

      await service.setAcceptingOrders(3, true);

      expect(saved[0].status).toBe(MerchantStatus.PENDING);
      await expect(service.assertMerchantCanTakeOrders(3)).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
