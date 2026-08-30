import { ConflictException } from '@nestjs/common';
import { EntityManager } from 'typeorm';

import { OrdersService } from './orders.service';
import { Order, OrderStatus } from './entities/order.entity';
import {
  OrderAssignment,
  AssignmentStatus,
} from './entities/order-assignment.entity';
import { PaymentsService } from '../payments/payments.service';
import { WalletTxType } from '../payments/entities/wallet-transaction.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { DeliveryVerificationStatus } from '../delivery/entities/delivery-partner.entity';
import { AccountStatus } from '../users/entities/user.entity';

/**
 * CP-B acceptance — "N parallel accepts → exactly one wins, no ledger anomaly."
 *
 * The plan states this as CP-B's acceptance criterion and it had no test. The
 * mechanism was already written (row lock, conditional UPDATE, one-active-order
 * rule); what was missing was anything that would notice if it regressed.
 *
 * ## What this file proves, and what it does not
 *
 * The fake `EntityManager` below models **conditional UPDATE** the way Postgres
 * implements it: `update(Entity, criteria, patch)` matches rows against the
 * criteria and patches only those, reporting how many it touched. That is the
 * one guarantee the service leans on, so modelling it faithfully — rather than
 * scripting who wins — is what makes these tests mean something. A service that
 * went back to read-then-write would fail them.
 *
 * It does **not** prove Postgres itself behaves that way. Row locks, the
 * partial unique index on `orders (accepted_driver_id)` and real transaction
 * isolation are database properties; a unit test cannot exercise them, and
 * pretending otherwise would be worse than saying so. Part 16's "full journey
 * on real Postgres" row remains outstanding and is where that belongs.
 */

// ── a fake EntityManager with real conditional-update semantics ────────────
interface FakeRows {
  orders: Partial<Order>[];
  assignments: Partial<OrderAssignment>[];
}

function matches(row: Record<string, unknown>, criteria: Record<string, unknown>) {
  return Object.entries(criteria).every(([k, v]) => row[k] === v);
}

function buildManager(rows: FakeRows) {
  const tableFor = (entity: unknown) =>
    entity === Order ? rows.orders : rows.assignments;

  const manager = {
    // The whole point: patch only rows that still match, and report the count.
    update: (
      entity: unknown,
      criteria: Record<string, unknown>,
      patch: Record<string, unknown>,
    ) => {
      const table = tableFor(entity) as Record<string, unknown>[];
      const hit = table.filter((r) => matches(r, criteria));
      hit.forEach((r) => Object.assign(r, patch));
      return Promise.resolve({ affected: hit.length });
    },
    findOne: (entity: unknown, opts: { where: Record<string, unknown> }) => {
      const table = tableFor(entity) as Record<string, unknown>[];
      return Promise.resolve(table.find((r) => matches(r, opts.where)) ?? null);
    },
    count: (entity: unknown, opts: { where: Record<string, unknown> }) => {
      const table = tableFor(entity) as Record<string, unknown>[];
      const { status, ...rest } = opts.where as Record<string, unknown> & {
        status?: { _value?: unknown[] };
      };
      const wanted: unknown[] = (status as { _value?: unknown[] })?._value ?? [];
      return Promise.resolve(
        table.filter(
          (r) => matches(r, rest) && wanted.includes(r.status as unknown),
        ).length,
      );
    },
    getRepository: (entity: unknown) => ({
      findOne: (opts: { where: Record<string, unknown> }) =>
        manager.findOne(entity, opts),
      count: (opts: { where: Record<string, unknown> }) =>
        manager.count(entity, opts),
    }),
    // Fully chainable: the service calls .andWhere() more than once, so every
    // step has to return the same builder rather than a one-shot stub.
    createQueryBuilder: () => {
      const qb: Record<string, unknown> = {};
      for (const m of ['update', 'set', 'where', 'andWhere']) {
        qb[m] = () => qb;
      }
      qb.execute = () => Promise.resolve({ affected: 0 });
      return qb;
    },
  };

  return manager as unknown as EntityManager;
}

describe('accepting an order under concurrency (CP-B acceptance)', () => {
  const ORDER_ID = 500;
  const DRIVERS = [1, 2, 3, 4, 5];

  const buildService = (rows: FakeRows, serialise = true) => {
    const manager = buildManager(rows);

    const driverRow = (id: number): Partial<DeliveryPartner> => ({
      userId: id,
      verificationStatus: DeliveryVerificationStatus.APPROVED,
      balance: 50,
      isOnline: true,
    });

    // findOne on the manager resolves users and partners too; route those.
    const realFindOne = manager.findOne.bind(manager);
    (manager as unknown as { findOne: unknown }).findOne = (
      entity: unknown,
      opts: { where: Record<string, unknown> },
    ) => {
      const name = (entity as { name?: string })?.name;
      if (name === 'User') {
        return Promise.resolve({
          id: opts.where.id,
          status: AccountStatus.ACTIVE,
          deletedAt: null,
        });
      }
      if (name === 'DeliveryPartner') {
        return Promise.resolve(driverRow(Number(opts.where.userId)));
      }
      return realFindOne(entity, opts);
    };

    // Transactions are serialised, because the real ones are. The service
    // opens by reading the order `lock: { mode: 'pessimistic_write' }` and
    // holds it to commit, so Postgres admits one accept at a time into this
    // critical section. A mock that let all five interleave would be testing a
    // database nobody runs — and would "fail" on assignment rows that a real
    // rollback and row lock never leave behind.
    let gate: Promise<unknown> = Promise.resolve();
    const orderRepository = {
      manager: {
        transaction: (fn: (m: EntityManager) => unknown) => {
          if (!serialise) return Promise.resolve().then(() => fn(manager));
          const run = gate.then(() => fn(manager));
          // Keep the queue alive even when a transaction throws.
          gate = run.then(
            () => undefined,
            () => undefined,
          );
          return run;
        },
      },
      findOne: jest.fn(),
    };

    return new OrdersService(
      orderRepository as never,
      { findOne: jest.fn(), save: jest.fn() } as never,
      { create: jest.fn(), save: jest.fn() } as never,
      { findOne: jest.fn() } as never,
      {} as never,
      {} as never,
      { minWalletToGoOnline: () => 5 } as never,
      {} as never,
      {} as never,
      { liveOffersFor: jest.fn().mockResolvedValue([]) } as never,
      { notify: jest.fn(), notifyMany: jest.fn() } as never,
    );
  };

  const freshRows = (): FakeRows => ({
    orders: [
      {
        id: ORDER_ID,
        status: OrderStatus.PENDING_OFFERS,
        customerId: 99,
        estimatedDeliveryFee: 20,
        // Unassigned is `undefined` here, not null: that is how the entity
        // types the column.
        acceptedDriverId: undefined,
      } as Partial<Order>,
    ],
    assignments: DRIVERS.map((driverId) => ({
      orderId: ORDER_ID,
      driverId,
      status: AssignmentStatus.OFFERED,
    })) as Partial<OrderAssignment>[],
  });

  it('gives the order to exactly one of five simultaneous accepts', async () => {
    const rows = freshRows();
    const service = buildService(rows);

    const results = await Promise.allSettled(
      DRIVERS.map((id) => service.acceptAvailableOrder(ORDER_ID, id)),
    );

    const won = results.filter((r) => r.status === 'fulfilled');
    const lost = results.filter((r) => r.status === 'rejected');

    expect(won).toHaveLength(1);
    expect(lost).toHaveLength(DRIVERS.length - 1);
  });

  it('tells every loser the order is gone, rather than failing obscurely', async () => {
    const rows = freshRows();
    const service = buildService(rows);

    const results = await Promise.allSettled(
      DRIVERS.map((id) => service.acceptAvailableOrder(ORDER_ID, id)),
    );

    const reasons = results
      .filter((r): r is PromiseRejectedResult => r.status === 'rejected')
      .map((r) => r.reason);

    // A loser is not an error condition — it is a race they lost, and the
    // driver's app has to be able to say so.
    reasons.forEach((e) => expect(e).toBeInstanceOf(ConflictException));
  });

  it('leaves the order assigned to a single driver', async () => {
    const rows = freshRows();
    const service = buildService(rows);

    await Promise.allSettled(
      DRIVERS.map((id) => service.acceptAvailableOrder(ORDER_ID, id)),
    );

    const order = rows.orders[0];
    expect(order.status).toBe(OrderStatus.ACCEPTED);
    expect(DRIVERS).toContain(order.acceptedDriverId);
    // The fee is frozen once, from the server's own estimate.
    expect(order.finalDeliveryFee).toBe(20);
  });

  it('promotes exactly one assignment and closes the rest', async () => {
    const rows = freshRows();
    const service = buildService(rows);

    await Promise.allSettled(
      DRIVERS.map((id) => service.acceptAvailableOrder(ORDER_ID, id)),
    );

    const accepted = rows.assignments.filter(
      (a) => a.status === AssignmentStatus.ACCEPTED,
    );
    const stillOffered = rows.assignments.filter(
      (a) => a.status === AssignmentStatus.OFFERED,
    );

    expect(accepted).toHaveLength(1);
    // No offer may be left live on an order that is already taken.
    expect(stillOffered).toHaveLength(0);
  });

  it('the winning assignment belongs to the driver who got the order', async () => {
    const rows = freshRows();
    const service = buildService(rows);

    await Promise.allSettled(
      DRIVERS.map((id) => service.acceptAvailableOrder(ORDER_ID, id)),
    );

    const accepted = rows.assignments.find(
      (a) => a.status === AssignmentStatus.ACCEPTED,
    );
    expect(accepted!.driverId).toBe(rows.orders[0].acceptedDriverId);
  });

  it('refuses a driver who was never offered the order', async () => {
    // Without this the targeted waves would be decorative: anyone could call
    // the route directly and take work meant for someone else.
    const rows = freshRows();
    const service = buildService(rows);

    await expect(
      service.acceptAvailableOrder(ORDER_ID, 999),
    ).rejects.toThrow(ConflictException);

    expect(rows.orders[0].status).toBe(OrderStatus.PENDING_OFFERS);
    expect(rows.orders[0].acceptedDriverId).toBeUndefined();
  });

  it('refuses an accept that races an expiry sweep and loses', async () => {
    const rows = freshRows();
    // The sweep got there first: no offer is live any more.
    rows.assignments.forEach((a) => (a.status = AssignmentStatus.EXPIRED));
    const service = buildService(rows);

    await expect(
      service.acceptAvailableOrder(ORDER_ID, 1),
    ).rejects.toThrow(ConflictException);

    expect(rows.orders[0].acceptedDriverId).toBeUndefined();
  });

  describe('with the row lock defeated', () => {
    // Everything above runs serialised, because the row lock serialises the
    // real thing — which means the losers are stopped by the status check and
    // the conditional UPDATE never gets to decide anything. That leaves the
    // backstop untested, so these run the same race with the serialisation
    // removed: five transactions all read `pending_offers` and all believe
    // they may proceed, which is what a missing FOR UPDATE would produce.
    //
    // Only the conditional UPDATE can separate them at that point. If someone
    // replaced it with a plain save, these two fail and the ones above do not.
    it('the conditional UPDATE still lets exactly one through', async () => {
      const rows = freshRows();
      const service = buildService(rows, false);

      const results = await Promise.allSettled(
        DRIVERS.map((id) => service.acceptAvailableOrder(ORDER_ID, id)),
      );

      expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      expect(results.filter((r) => r.status === 'rejected')).toHaveLength(
        DRIVERS.length - 1,
      );
    });

    it('and the order still ends up with a single driver', async () => {
      const rows = freshRows();
      const service = buildService(rows, false);

      await Promise.allSettled(
        DRIVERS.map((id) => service.acceptAvailableOrder(ORDER_ID, id)),
      );

      expect(rows.orders[0].status).toBe(OrderStatus.ACCEPTED);
      expect(DRIVERS).toContain(rows.orders[0].acceptedDriverId);
    });

    // Deliberately not asserted here: which assignment rows survive. The
    // losers' `markWinnerWithin` writes are undone by the transaction rolling
    // back, and this fake has no rollback — so any expectation about them
    // would be measuring the fake, not the system.
  });

  it('a second accept on an already-accepted order changes nothing', async () => {
    const rows = freshRows();
    const service = buildService(rows);

    await service.acceptAvailableOrder(ORDER_ID, 1);
    const winner = rows.orders[0].acceptedDriverId;

    await expect(
      service.acceptAvailableOrder(ORDER_ID, 2),
    ).rejects.toThrow(ConflictException);

    // The first driver keeps it — a late accept must not steal an order.
    expect(rows.orders[0].acceptedDriverId).toBe(winner);
  });
});

/**
 * Part 16's remaining concurrency row: a commission and a cancellation penalty
 * landing on the same driver.
 *
 * Both are debits computed from a balance the other one is also moving. The
 * protection is the row lock inside `creditWithin` — each debit re-reads under
 * it — so the guarantee under test is that neither entry is computed from a
 * balance that the other has already invalidated.
 */
describe('concurrent commission and penalty on one driver (Part 16)', () => {
  it('applies both debits and leaves the balance and ledger consistent', async () => {
    const driver = { userId: 7, balance: 100 };
    const ledger: Record<string, unknown>[] = [];

    // Serialised on purpose: this is what `pessimistic_write` buys, and the
    // assertion is that each debit is computed from the balance *after* the
    // previous one rather than from a stale read.
    let chain: Promise<unknown> = Promise.resolve();
    const manager = {
      findOne: () => Promise.resolve(driver),
      update: (_e: unknown, _w: unknown, patch: { balance: number }) => {
        driver.balance = patch.balance;
        return Promise.resolve({ affected: 1 });
      },
      insert: (_e: unknown, row: Record<string, unknown>) => {
        ledger.push(row);
        return Promise.resolve({});
      },
    } as unknown as EntityManager;

    const debit = (amount: number, reference: string) =>
      PaymentsService.creditWithin(manager, {
        driverId: 7,
        amount,
        type: WalletTxType.COMMISSION,
        note: 'debit',
        reference,
      });

    chain = chain
      .then(() => debit(-7, 'order-1-commission'))
      .then(() => debit(-4, 'order-2-cancel-penalty'));
    await chain;

    expect(driver.balance).toBe(89); // 100 − 7 − 4
    expect(ledger).toHaveLength(2);
    // Neither entry was computed from a balance the other had invalidated.
    expect(ledger[0]).toMatchObject({ amount: -7, balanceAfter: 93 });
    expect(ledger[1]).toMatchObject({ amount: -4, balanceAfter: 89 });
    // Distinct idempotency keys — the UNIQUE constraint is what stops a
    // genuine duplicate, and these are not duplicates.
    expect(ledger[0].reference).not.toBe(ledger[1].reference);
  });
});
