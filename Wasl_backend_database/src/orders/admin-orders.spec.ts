import { NotFoundException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Repository } from 'typeorm';

import { AdminOrdersController } from './admin-orders.controller';
import { AdminOrdersService } from './admin-orders.service';
import { Order, OrderStatus } from './entities/order.entity';
import { OrderItem } from './entities/order-item.entity';
import { OrderCancellationRequest } from './entities/order-cancellation-request.entity';
import { WalletTransaction } from '../payments/entities/wallet-transaction.entity';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { ROLES_KEY } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

/**
 * `GET /admin/orders` — Part 12's ADD, and the backend half of Part 3's
 * "order inspection" admin MUST-HAVE.
 *
 * The endpoint is read-only and paged. These pin the three things that could
 * quietly go wrong: an unbounded dump, a non-admin reading every customer's
 * address and phone, and a detail view that recomputes money instead of
 * reporting what the ledger says.
 */
describe('admin order inspection', () => {
  /** Captures the find options the service passes down. */
  function buildService(overrides: {
    orders?: Partial<Order>[];
    total?: number;
    items?: Partial<OrderItem>[];
    cancellations?: Partial<OrderCancellationRequest>[];
    transactions?: Partial<WalletTransaction>[];
  } = {}) {
    const seen: { findAndCount?: any; finds: any[] } = { finds: [] };

    const orderRepo = {
      findAndCount: (opts: unknown) => {
        seen.findAndCount = opts;
        return Promise.resolve([
          overrides.orders ?? [],
          overrides.total ?? (overrides.orders?.length ?? 0),
        ]);
      },
      findOne: (opts: { where: { id: number } }) =>
        Promise.resolve(
          (overrides.orders ?? []).find((o) => o.id === opts.where.id) ?? null,
        ),
    } as unknown as Repository<Order>;

    /** A repository that only answers `find`, recording what it was asked. */
    const listRepo = (rows: readonly unknown[]) =>
      ({
        find: (opts: unknown) => {
          seen.finds.push(opts);
          return Promise.resolve(rows);
        },
      }) as unknown as Repository<never>;

    const service = new AdminOrdersService(
      orderRepo,
      listRepo(overrides.items ?? []) as unknown as Repository<OrderItem>,
      listRepo(
        overrides.cancellations ?? [],
      ) as unknown as Repository<OrderCancellationRequest>,
      listRepo(
        overrides.transactions ?? [],
      ) as unknown as Repository<WalletTransaction>,
    );

    return { service, seen };
  }

  // ── authorization ───────────────────────────────────────────────────────
  describe('authorization', () => {
    it('is behind JwtAuthGuard and RolesGuard', () => {
      const guards = Reflect.getMetadata(
        '__guards__',
        AdminOrdersController,
      ) as unknown[];
      const names = guards.map((g: any) =>
        g.name ? g.name : g.constructor.name,
      );

      // Orders carry customer names, phones and delivery addresses. Without
      // both guards this is a directory of everyone who ever ordered.
      expect(names).toContain(JwtAuthGuard.name);
      expect(names).toContain(RolesGuard.name);
    });

    it('requires the ADMIN role', () => {
      const roles = new Reflector().get<UserRole[]>(
        ROLES_KEY,
        AdminOrdersController,
      );
      expect(roles).toContain(UserRole.ADMIN);
    });
  });

  // ── paging ──────────────────────────────────────────────────────────────
  describe('paging', () => {
    it('defaults to 50, newest first', async () => {
      const { service, seen } = buildService();

      const result = await service.list({});

      expect(seen.findAndCount.take).toBe(50);
      expect(seen.findAndCount.skip).toBe(0);
      expect(seen.findAndCount.order).toEqual({
        createdAt: 'DESC',
        id: 'DESC',
      });
      expect(result.limit).toBe(50);
    });

    it('caps at 200 however much is asked for', async () => {
      const { service, seen } = buildService();

      await service.list({ limit: 5000 });

      // An unbounded dump of every order is its own outage.
      expect(seen.findAndCount.take).toBe(200);
    });

    it('honours a sensible limit and offset', async () => {
      const { service, seen } = buildService();

      await service.list({ limit: 20, offset: 40 });

      expect(seen.findAndCount.take).toBe(20);
      expect(seen.findAndCount.skip).toBe(40);
    });

    it('falls back to the default on nonsense rather than clamping', async () => {
      const { service, seen } = buildService();

      await service.list({ limit: -5 });
      expect(seen.findAndCount.take).toBe(50);

      await service.list({ limit: Number.NaN });
      expect(seen.findAndCount.take).toBe(50);

      await service.list({ offset: -10 });
      expect(seen.findAndCount.skip).toBe(0);
    });

    it('reports the true total, not the page size', async () => {
      const { service } = buildService({
        orders: [{ id: 1 }, { id: 2 }],
        total: 873,
      });

      const result = await service.list({ limit: 2 });

      expect(result.total).toBe(873);
      expect(result.orders).toHaveLength(2);
    });
  });

  // ── the controller passes only paging ───────────────────────────────────
  describe('the controller surface', () => {
    it('passes only limit and offset through', async () => {
      let seen: unknown = null;
      const stub = {
        list: (q: unknown) => {
          seen = q;
          return Promise.resolve({ total: 0, limit: 50, offset: 0, orders: [] });
        },
      } as unknown as AdminOrdersService;

      await new AdminOrdersController(stub).list('10', '5');

      expect(seen).toEqual({ limit: 10, offset: 5 });
    });

    it('is read-only — no write handlers exist on it', () => {
      const methods = Object.getOwnPropertyNames(
        AdminOrdersController.prototype,
      ).filter((m) => m !== 'constructor');

      // Completion settles a wallet and cancellation charges a penalty; both
      // have their own routes with their own rules. A general admin write here
      // would be a second door into money-moving state that skips them.
      expect(methods.sort()).toEqual(['detail', 'list']);
    });
  });

  // ── detail ──────────────────────────────────────────────────────────────
  describe('one order in full', () => {
    it('joins items, cancellations and the ledger for that order', async () => {
      const { service, seen } = buildService({
        orders: [{ id: 7, status: OrderStatus.COMPLETED }],
        items: [{ id: 1, orderId: 7 }],
        cancellations: [{ id: 3, orderId: 7 }],
        transactions: [{ id: 9, orderId: 7, amount: -8 }],
      });

      const result = await service.detail(7);

      expect(result.order.id).toBe(7);
      expect(result.items).toHaveLength(1);
      expect(result.cancellations).toHaveLength(1);
      expect(result.transactions).toHaveLength(1);

      // Every join is scoped to this order — an admin opening one complaint
      // must not be handed another customer's rows.
      for (const opts of seen.finds) {
        expect(opts.where).toEqual({ orderId: 7 });
      }
    });

    it('reports what the ledger says rather than recomputing it', async () => {
      const { service } = buildService({
        orders: [{ id: 7, finalDeliveryFee: 40 }],
        transactions: [{ id: 9, orderId: 7, amount: -8 }],
      });

      const result = await service.detail(7);

      // 40 × 20% happens to be 8 here, but the point is that the number comes
      // from wallet_transactions. A figure derived a second way could disagree
      // with the money that actually moved.
      expect(result.transactions[0].amount).toBe(-8);
    });

    it('404s an order that does not exist', async () => {
      const { service } = buildService({ orders: [] });

      await expect(service.detail(404)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });
});
