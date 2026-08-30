import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Reflector } from '@nestjs/core';

import { CatalogService } from './catalog.service';
import { CatalogController } from './catalog.controller';
import { MenuCategory } from './entities/menu-category.entity';
import { Product } from './entities/product.entity';
import { ProductAddon, ProductSize } from './entities/product-option.entity';
import { Merchant, MerchantStatus } from '../merchant/entities/merchant.entity';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { ROLES_KEY } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

/**
 * The admin catalog read, and the one thing that makes it different.
 *
 * `getMenu` is the **customer** menu and filters to `isAvailable` /
 * `isActive`. Pointing a management screen at it is not a small mistake: the
 * admin switches a product off, it disappears from the list, and the control
 * that would switch it back on disappears with it. That happened — it was
 * caught by clicking the button in a browser, not by reading the code — and
 * these tests exist so it cannot come back quietly.
 *
 * The risk is a tidy-up: the two methods look near-identical, and "reuse
 * getMenu" is an obvious-looking simplification that silently reintroduces
 * the bug. The first test below fails the moment anyone does that.
 */
describe('admin catalog menu', () => {
  /** What each repository was asked for, so the filters can be asserted. */
  let asked: { categories?: unknown; products?: unknown };
  let merchantRow: Partial<Merchant> | null;
  let service: CatalogService;

  const CATEGORIES: Partial<MenuCategory>[] = [
    { id: 1, merchantId: 3, name: 'وجبات', isActive: true },
    { id: 2, merchantId: 3, name: 'قسم موقوف', isActive: false },
  ];

  const PRODUCTS: Partial<Product>[] = [
    { id: 10, merchantId: 3, name: 'ساندويتش', price: 65, isAvailable: true },
    { id: 11, merchantId: 3, name: 'صنف موقوف', price: 40, isAvailable: false },
  ];

  const build = async (row: Partial<Merchant> | null) => {
    merchantRow = row;
    asked = {};

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogService,
        {
          provide: getRepositoryToken(Merchant),
          useValue: {
            findOne: () => Promise.resolve(merchantRow),
            findOneBy: () => Promise.resolve(merchantRow),
            find: () => Promise.resolve([]),
          },
        },
        {
          provide: getRepositoryToken(MenuCategory),
          useValue: {
            find: (opts: unknown) => {
              asked.categories = opts;
              return Promise.resolve(CATEGORIES);
            },
          },
        },
        {
          provide: getRepositoryToken(Product),
          useValue: {
            find: (opts: unknown) => {
              asked.products = opts;
              return Promise.resolve(PRODUCTS);
            },
          },
        },
        { provide: getRepositoryToken(ProductSize), useValue: { find: () => Promise.resolve([]) } },
        { provide: getRepositoryToken(ProductAddon), useValue: { find: () => Promise.resolve([]) } },
      ],
    }).compile();

    service = module.get(CatalogService);
  };

  const approved = (overrides: Partial<Merchant> = {}): Partial<Merchant> => ({
    id: 3,
    storeName: 'مطعم الشرقاوي',
    status: MerchantStatus.APPROVED,
    isAcceptingOrders: true,
    ...overrides,
  });

  describe('it returns what the customer menu hides', () => {
    it('does NOT filter products by availability', async () => {
      await build(approved());

      const menu = await service.getMenuForAdmin(3);

      // The whole point. If this ever narrows to `isAvailable: true`, an admin
      // can switch a product off and never switch it back on.
      expect(
        (asked.products as { where: Record<string, unknown> }).where,
      ).toEqual({ merchantId: 3 });
      expect(menu.products.map((p) => p.id)).toEqual([10, 11]);
    });

    it('does NOT filter categories by isActive', async () => {
      await build(approved());

      const menu = await service.getMenuForAdmin(3);

      expect(
        (asked.categories as { where: Record<string, unknown> }).where,
      ).toEqual({ merchantId: 3 });
      expect(menu.categories.map((c) => c.id)).toEqual([1, 2]);
    });

    it('includes the unavailable product itself, not just a count', async () => {
      await build(approved());

      const menu = await service.getMenuForAdmin(3);
      const off = menu.products.find((p) => p.id === 11);

      expect(off).toBeDefined();
      expect(off!.isAvailable).toBe(false);
    });
  });

  describe('which merchants it will open', () => {
    it('does not require the store to be approved', async () => {
      // Building a menu before a store goes live is exactly when this is
      // needed; the customer route rightly refuses an unapproved store.
      await build(approved({ status: MerchantStatus.PENDING }));

      await expect(service.getMenuForAdmin(3)).resolves.toMatchObject({
        merchant: { id: 3 },
      });
    });

    it('404s a merchant that does not exist', async () => {
      await build(null);

      await expect(service.getMenuForAdmin(404)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('authorization', () => {
    it('the admin menu route is guarded and ADMIN-only', () => {
      const guards = Reflect.getMetadata(
        '__guards__',
        CatalogController.prototype.adminMenu,
      ) as unknown[];
      const names = (guards ?? []).map((g: any) =>
        g.name ? g.name : g.constructor.name,
      );

      expect(names).toContain(JwtAuthGuard.name);
      expect(names).toContain(RolesGuard.name);

      const roles = new Reflector().get<UserRole[]>(
        ROLES_KEY,
        CatalogController.prototype.adminMenu,
      );
      expect(roles).toContain(UserRole.ADMIN);
    });
  });
});
