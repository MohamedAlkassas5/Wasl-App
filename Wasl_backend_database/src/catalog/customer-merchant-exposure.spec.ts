import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import type { FindManyOptions, FindOneOptions } from 'typeorm';

import { CatalogService } from './catalog.service';
import { MenuCategory } from './entities/menu-category.entity';
import { Product } from './entities/product.entity';
import { ProductAddon, ProductSize } from './entities/product-option.entity';
import { Merchant, MerchantStatus } from '../merchant/entities/merchant.entity';

/**
 * What an unauthenticated customer may learn about a merchant.
 *
 * `GET /merchants`, its `/restaurants` alias and `GET /merchants/:id/menu` are
 * all unguarded — there is no `@UseGuards` on them and the only global guard is
 * the throttler. They used to return whole `Merchant` entities, which carried
 * two fields that are nobody's business but the platform's:
 *
 *  - `adminNotes` — the free text an admin types when approving or rejecting a
 *    store. `AdminService.reviewApproval` writes it straight onto the merchant
 *    row, so this was live operational commentary about real businesses, served
 *    to anyone who called the endpoint.
 *  - `ownerId` — the internal user id behind the shop.
 *
 * These tests are written to fail if either comes back, and deliberately do
 * **not** trust a mock that ignores `select`: the fake repository below applies
 * the projection the way TypeORM does, and the projection itself is asserted
 * separately. A test that only checked the returned object against a mock which
 * hands back whatever it likes would pass just as happily with the fix removed.
 */
describe('customer-facing merchant exposure', () => {
  /** Every column the entity has, including the two that must never escape. */
  const FULL_ROW: Record<string, unknown> = {
    id: 3,
    ownerId: 77,
    storeName: 'مطعم الشرقاوي',
    storeType: 'مطاعم',
    logo: 'logo.png',
    coverImage: 'cover.png',
    latitude: 30.1,
    longitude: 31.2,
    addressDetails: 'شارع المحطة',
    status: MerchantStatus.APPROVED,
    isAcceptingOrders: true,
    adminNotes: 'صاحب المحل متأخر في السداد — ملاحظة داخلية',
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-02'),
  };

  /** The fields the apps actually read, so the fix cannot quietly gut them. */
  const CUSTOMER_VISIBLE = [
    'id',
    'storeName',
    'storeType',
    'logo',
    'coverImage',
    'latitude',
    'longitude',
    'addressDetails',
    'status',
    'isAcceptingOrders',
  ];

  const SECRET_FIELDS = ['adminNotes', 'ownerId'];

  /**
   * Applies a TypeORM `select` the way the driver would.
   *
   * Without this the mock would return `FULL_ROW` whatever the service asked
   * for, and every assertion below would pass with the fix reverted.
   */
  const project = (
    row: Record<string, unknown>,
    select?: Record<string, unknown>,
  ): Record<string, unknown> => {
    if (!select) return { ...row };
    const out: Record<string, unknown> = {};
    for (const [key, wanted] of Object.entries(select)) {
      if (wanted) out[key] = row[key];
    }
    return out;
  };

  let service: CatalogService;
  /** The options each merchant read was called with, so `select` is assertable. */
  let merchantFindOptions: FindManyOptions<Merchant> | undefined;
  let merchantFindOneOptions: FindOneOptions<Merchant> | undefined;

  beforeEach(async () => {
    merchantFindOptions = undefined;
    merchantFindOneOptions = undefined;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogService,
        {
          provide: getRepositoryToken(Merchant),
          useValue: {
            find: (opts: FindManyOptions<Merchant>) => {
              merchantFindOptions = opts;
              return Promise.resolve([
                project(
                  FULL_ROW,
                  opts?.select as Record<string, unknown> | undefined,
                ),
              ]);
            },
            findOne: (opts: FindOneOptions<Merchant>) => {
              merchantFindOneOptions = opts;
              return Promise.resolve(
                project(
                  FULL_ROW,
                  opts?.select as Record<string, unknown> | undefined,
                ),
              );
            },
            findOneBy: () => Promise.resolve({ ...FULL_ROW }),
          },
        },
        {
          provide: getRepositoryToken(MenuCategory),
          useValue: {
            find: () =>
              Promise.resolve([
                { id: 1, merchantId: 3, name: 'وجبات', isActive: true },
              ]),
          },
        },
        {
          provide: getRepositoryToken(Product),
          useValue: {
            find: () =>
              Promise.resolve([
                {
                  id: 10,
                  merchantId: 3,
                  name: 'ساندويتش',
                  price: 65,
                  isAvailable: true,
                },
              ]),
          },
        },
        {
          provide: getRepositoryToken(ProductSize),
          useValue: { find: () => Promise.resolve([]) },
        },
        {
          provide: getRepositoryToken(ProductAddon),
          useValue: { find: () => Promise.resolve([]) },
        },
      ],
    }).compile();

    service = module.get(CatalogService);
  });

  describe('GET /merchants (and the /restaurants alias, same method)', () => {
    it('does not expose adminNotes or ownerId', async () => {
      const [merchant] = await service.listMerchants();

      for (const field of SECRET_FIELDS) {
        expect(merchant).not.toHaveProperty(field);
      }
    });

    it('asks the database not to read those columns at all', async () => {
      await service.listMerchants();

      const select = merchantFindOptions?.select as
        | Record<string, unknown>
        | undefined;
      expect(select).toBeDefined();
      for (const field of SECRET_FIELDS) {
        expect(select?.[field]).toBeFalsy();
      }
    });

    it('still returns every field the store list renders', async () => {
      const [merchant] = await service.listMerchants();

      for (const field of CUSTOMER_VISIBLE) {
        expect(merchant).toHaveProperty(field);
      }
      expect(merchant.storeName).toBe('مطعم الشرقاوي');
      expect(merchant.isAcceptingOrders).toBe(true);
    });

    it('applies the same projection when narrowed by store type', async () => {
      const [merchant] = await service.listMerchants('مطاعم');

      for (const field of SECRET_FIELDS) {
        expect(merchant).not.toHaveProperty(field);
      }
    });

    it('still filters to approved stores only', async () => {
      await service.listMerchants();

      expect(merchantFindOptions?.where).toMatchObject({
        status: MerchantStatus.APPROVED,
      });
    });
  });

  describe('GET /merchants/:id/menu', () => {
    it('does not expose adminNotes or ownerId on the merchant', async () => {
      const menu = await service.getMenu(3);

      for (const field of SECRET_FIELDS) {
        expect(menu.merchant).not.toHaveProperty(field);
      }
    });

    it('asks the database not to read those columns at all', async () => {
      await service.getMenu(3);

      const select = merchantFindOneOptions?.select as
        | Record<string, unknown>
        | undefined;
      expect(select).toBeDefined();
      for (const field of SECRET_FIELDS) {
        expect(select?.[field]).toBeFalsy();
      }
    });

    it('no longer returns the merchant a second time as `restaurant`', async () => {
      const menu = await service.getMenu(3);

      expect(menu).not.toHaveProperty('restaurant');
    });

    it('still returns the merchant, categories and products', async () => {
      const menu = await service.getMenu(3);

      expect(menu.merchant).toBeDefined();
      expect(menu.merchant.storeName).toBe('مطعم الشرقاوي');
      expect(menu.categories).toHaveLength(1);
      expect(menu.products).toHaveLength(1);
      expect(menu.products[0]).toMatchObject({ id: 10, name: 'ساندويتش' });
    });

    it('still exposes the fields the menu header renders', async () => {
      const menu = await service.getMenu(3);

      for (const field of CUSTOMER_VISIBLE) {
        expect(menu.merchant).toHaveProperty(field);
      }
    });
  });

  /**
   * The other half of the fix: it must not have over-reached.
   *
   * `adminNotes` exists for administrators, and the admin catalog read is
   * guarded by `JwtAuthGuard + RolesGuard + @Roles(ADMIN)`. If a future tidy-up
   * points the admin menu at the customer projection, the panel silently loses
   * the note it was written to show.
   */
  describe('the admin read is deliberately unchanged', () => {
    it('still returns the whole merchant row, adminNotes included', async () => {
      const menu = await service.getMenuForAdmin(3);

      expect(menu.merchant).toHaveProperty('adminNotes');
      expect(menu.merchant).toHaveProperty('ownerId');
    });

    it('does not restrict the admin query with a customer projection', async () => {
      await service.getMenuForAdmin(3);

      expect(merchantFindOneOptions?.select).toBeUndefined();
    });
  });
});
