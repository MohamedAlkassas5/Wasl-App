import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { PaymentsService, topUpReference } from './payments.service';
import { PaymentsController } from './payments.controller';
import { AdminPaymentsController } from './admin-payments.controller';
import {
  WalletTopUpRequest,
  TopUpMethod,
  TopUpStatus,
} from './entities/wallet-topup-request.entity';
import {
  WalletTransaction,
  WalletTxType,
} from './entities/wallet-transaction.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { User, UserRole } from '../users/entities/user.entity';
import { SettingKey } from '../settings/settings.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { ROLES_KEY } from '../auth/decorators/roles.decorator';
import type { UploadService } from '../storage/upload.service';
import type { AdminAuditLogService } from '../admin/admin-audit-log.service';

/**
 * Driver wallet top-up: request → admin review → credit.
 *
 * The rule the whole feature exists to enforce is that **filing a request is
 * not money**. A driver types an amount, pays a Vodafone Cash / InstaPay
 * account off-platform and uploads a screenshot; nothing about that has been
 * verified by anyone. The balance moves once, later, when an admin says the
 * transfer really arrived — and never for a request that was rejected.
 *
 * ## What the fake database below models, and why
 *
 * Approval is a money-moving operation, so the interesting failures are races
 * and retries rather than arithmetic. The fake therefore implements the three
 * database behaviours the service actually leans on:
 *
 *   - **`FOR UPDATE` row locks** — a second transaction asking for a row the
 *     first still holds *waits*, and reads what the first one committed.
 *   - **Conditional UPDATE** — `update(entity, criteria, patch)` patches only
 *     rows still matching the criteria, and reports how many.
 *   - **The UNIQUE constraint on `wallet_transactions.reference`** — a second
 *     insert of the same reference throws, and rolls its transaction back.
 *
 * Modelling those rather than scripting an outcome is what makes the
 * concurrency test mean something: a service that dropped the lock, or the
 * conditional update, or the reference, fails here.
 *
 * It does **not** prove PostgreSQL behaves this way. That belongs to
 * `scripts/verify-concurrency.js`, which drives this same service through a
 * real multi-connection server; scenario 8 there is this file's parallel
 * approval, for real.
 */

// ── an in-memory database with locks, conditional updates and constraints ──

interface Tables {
  drivers: Partial<DeliveryPartner>[];
  topups: Partial<WalletTopUpRequest>[];
  txs: Partial<WalletTransaction>[];
  users: Partial<User>[];
}

type Row = Record<string, unknown>;

/** Undo record for a transaction that has to roll back. */
type Journal = Array<() => void>;

function matches(row: Row, criteria: Row) {
  return Object.entries(criteria).every(([k, v]) => row[k] === v);
}

class FakeDb {
  readonly tables: Tables = { drivers: [], topups: [], txs: [], users: [] };
  private nextTxId = 1;
  private nextTopUpId = 1;
  private readonly locks = new Map<string, Promise<void>>();

  tableFor(entity: unknown): Row[] {
    if (entity === DeliveryPartner) return this.tables.drivers as Row[];
    if (entity === WalletTopUpRequest) return this.tables.topups as Row[];
    if (entity === WalletTransaction) return this.tables.txs as Row[];
    if (entity === User) return this.tables.users as Row[];
    throw new Error('unknown entity in fake db');
  }

  private keyFor(entity: unknown, row: Row): string {
    const id = entity === DeliveryPartner ? row.userId : row.id;
    return `${String((entity as { name?: string }).name)}#${String(id)}`;
  }

  /** `SELECT … FOR UPDATE`: wait for whoever holds the row, then take it. */
  private async lock(key: string, journal: Journal): Promise<void> {
    while (this.locks.has(key)) await this.locks.get(key);
    let release!: () => void;
    this.locks.set(
      key,
      new Promise<void>((resolve) => {
        release = resolve;
      }),
    );
    journal.push(() => {
      this.locks.delete(key);
      release();
    });
  }

  /**
   * One transaction. Locks are held to the end and released together;
   * a throw undoes every write this transaction made — and only those, so a
   * concurrent transaction that already committed is left alone.
   */
  async transaction<T>(work: (manager: unknown) => Promise<T>): Promise<T> {
    const undo: Journal = [];
    const releases: Journal = [];
    const manager = this.manager(undo, releases);
    try {
      const result = await work(manager);
      releases.forEach((r) => r());
      return result;
    } catch (error) {
      undo.reverse().forEach((u) => u());
      releases.forEach((r) => r());
      throw error;
    }
  }

  /** A manager outside any transaction — for plain repository reads. */
  manager(undo: Journal = [], releases: Journal = []) {
    return {
      findOne: async (
        entity: unknown,
        opts: { where: Row; lock?: { mode: string } },
      ) => {
        const table = this.tableFor(entity);
        if (opts.lock?.mode === 'pessimistic_write') {
          const target = table.find((r) => matches(r, opts.where));
          if (target) {
            await this.lock(this.keyFor(entity, target), releases);
          }
        }
        // Re-read after the lock: the holder may have changed the row.
        const found = table.find((r) => matches(r, opts.where));
        return found ? { ...found } : null;
      },

      find: async (entity: unknown, opts?: { where?: Row }) => {
        const table = this.tableFor(entity);
        const where = opts?.where;
        if (!where) return table.map((r) => ({ ...r }));
        const inClause = Object.entries(where).find(
          ([, v]) => v && typeof v === 'object' && '_value' in (v as object),
        );
        if (inClause) {
          const [field, condition] = inClause;
          const wanted = (condition as { _value: unknown[] })._value;
          return table
            .filter((r) => wanted.includes(r[field]))
            .map((r) => ({ ...r }));
        }
        return table.filter((r) => matches(r, where)).map((r) => ({ ...r }));
      },

      update: async (entity: unknown, criteria: Row, patch: Row) => {
        const table = this.tableFor(entity);
        const hit = table.filter((r) => matches(r, criteria));
        hit.forEach((row) => {
          const before = { ...row };
          undo.push(() => {
            Object.keys(row).forEach((k) => delete row[k]);
            Object.assign(row, before);
          });
          Object.assign(row, patch);
        });
        return { affected: hit.length };
      },

      insert: async (entity: unknown, row: Row) => {
        const table = this.tableFor(entity);
        // UQ_wallet_transactions_reference — the database's own refusal to
        // move the same money twice.
        if (entity === WalletTransaction && row.reference != null) {
          if (table.some((r) => r.reference === row.reference)) {
            throw new Error(
              'duplicate key value violates unique constraint "UQ_wallet_transactions_reference"',
            );
          }
        }
        const saved = { id: this.nextTxId++, createdAt: new Date(), ...row };
        table.push(saved);
        undo.push(() => {
          const at = table.indexOf(saved);
          if (at >= 0) table.splice(at, 1);
        });
        return { identifiers: [{ id: saved.id }] };
      },
    };
  }

  seedDriver(userId: number, balance: number, name = `كابتن ${userId}`) {
    this.tables.drivers.push({ userId, balance } as Partial<DeliveryPartner>);
    this.tables.users.push({
      id: userId,
      name,
      phone: `0100000${userId}`,
    } as Partial<User>);
  }

  seedTopUp(row: Partial<WalletTopUpRequest>): WalletTopUpRequest {
    const saved = {
      id: this.nextTopUpId++,
      status: TopUpStatus.PENDING,
      method: TopUpMethod.VODAFONE_CASH,
      proofImageUrl: 'uploads/payments/proof-1.jpg',
      createdAt: new Date(),
      ...row,
    } as WalletTopUpRequest;
    this.tables.topups.push(saved);
    return saved;
  }

  balanceOf(driverId: number): number {
    const driver = this.tables.drivers.find((d) => d.userId === driverId);
    return Number(driver?.balance ?? 0);
  }

  creditsFor(driverId: number) {
    return this.tables.txs.filter(
      (t) => t.driverId === driverId && Number(t.amount) > 0,
    );
  }
}

// ── the service, wired to the fake ────────────────────────────────────────

function buildService(db: FakeDb, overrides: Record<string, number> = {}) {
  const notified: Array<{ userId: number; title: string; message: string }> = [];

  const repoFor = (entity: unknown) => ({
    manager: {
      ...db.manager(),
      transaction: (work: (m: unknown) => Promise<unknown>) =>
        db.transaction(work),
    },
    create: (row: Row) => ({ ...row }),
    save: async (row: Row) => {
      const table = db.tableFor(entity);
      const saved = { id: table.length + 1, createdAt: new Date(), ...row };
      table.push(saved);
      return saved;
    },
    find: (opts?: { where?: Row }) => db.manager().find(entity, opts),
    findOne: (opts: { where: Row }) => db.manager().findOne(entity, opts),
  });

  const settings = {
    getString: (key: string, fallback = '') =>
      ({
        [SettingKey.PAY_VODAFONE_NUMBER]: '01000000000',
        [SettingKey.PAY_INSTAPAY_HANDLE]: 'wasl@instapay',
      })[key] ?? fallback,
    getNumber: (key: string, fallback = 0) => overrides[key] ?? fallback,
  };

  const notifications = {
    notify: async (userId: number, title: string, message: string) => {
      notified.push({ userId, title, message });
      return {} as never;
    },
  };

  const service = new PaymentsService(
    repoFor(WalletTopUpRequest) as never,
    repoFor(WalletTransaction) as never,
    repoFor(DeliveryPartner) as never,
    settings as never,
    notifications as never,
  );

  return { service, notified };
}

const proof = { amount: 100, method: TopUpMethod.VODAFONE_CASH } as const;

describe('driver wallet top-up', () => {
  // ── 1–4: filing a request ───────────────────────────────────────────────
  describe('the driver files a request', () => {
    it('creates it PENDING and moves no money', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const { service } = buildService(db);

      const result = await service.createTopUpRequest(7, {
        ...proof,
        proofImageUrl: 'uploads/payments/proof-abc.jpg',
      });

      expect(result.success).toBe(true);
      expect(result.request.status).toBe(TopUpStatus.PENDING);
      // 💰 The whole point of the feature.
      expect(db.balanceOf(7)).toBe(0);
      expect(db.tables.txs).toHaveLength(0);
    });

    it('tells the driver it is under review, not that it was credited', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const { service } = buildService(db);

      const result = await service.createTopUpRequest(7, {
        ...proof,
        proofImageUrl: 'uploads/payments/proof-abc.jpg',
      });

      expect(result.message).toContain('للمراجعة');
      expect(result.message).not.toContain('تم شحن');
    });

    it('stores the screenshot key and the sender reference on the request', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const { service } = buildService(db);

      const { request } = await service.createTopUpRequest(7, {
        ...proof,
        method: TopUpMethod.INSTAPAY,
        senderReference: '01098765432',
        proofImageUrl: 'uploads/payments/proof-abc.jpg',
      });

      expect(request.proofImageUrl).toBe('uploads/payments/proof-abc.jpg');
      expect(request.senderReference).toBe('01098765432');
      expect(request.method).toBe(TopUpMethod.INSTAPAY);
    });

    it('files it against the authenticated driver, whoever the body names', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      db.seedDriver(9, 0);
      const { service } = buildService(db);

      const { request } = await service.createTopUpRequest(7, {
        ...proof,
        // A tampered client could add anything here; the id is an argument,
        // and the controller takes it from the JWT.
        proofImageUrl: 'uploads/payments/proof-abc.jpg',
      } as never);

      expect(request.driverId).toBe(7);
    });

    it('refuses a request with no transfer screenshot', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const { service } = buildService(db);

      await expect(service.createTopUpRequest(7, { ...proof })).rejects.toThrow(
        BadRequestException,
      );
      expect(db.tables.topups).toHaveLength(0);
    });

    it('refuses an amount outside the configured range, whatever the client says', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const { service } = buildService(db, {
        [SettingKey.TOPUP_MIN_AMOUNT]: 10,
        [SettingKey.TOPUP_MAX_AMOUNT]: 5000,
      });
      const withProof = { proofImageUrl: 'uploads/payments/p.jpg' };

      await expect(
        service.createTopUpRequest(7, { ...proof, amount: 0, ...withProof }),
      ).rejects.toThrow(BadRequestException);
      await expect(
        service.createTopUpRequest(7, { ...proof, amount: -100, ...withProof }),
      ).rejects.toThrow(BadRequestException);
      await expect(
        service.createTopUpRequest(7, { ...proof, amount: 5, ...withProof }),
      ).rejects.toThrow(BadRequestException);
      await expect(
        service.createTopUpRequest(7, { ...proof, amount: 9999, ...withProof }),
      ).rejects.toThrow(BadRequestException);
      await expect(
        service.createTopUpRequest(7, {
          ...proof,
          amount: Number.NaN,
          ...withProof,
        }),
      ).rejects.toThrow(BadRequestException);

      expect(db.tables.topups).toHaveLength(0);
      expect(db.balanceOf(7)).toBe(0);
    });

    it('rounds the stored amount to piastres', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const { service } = buildService(db);

      const { request } = await service.createTopUpRequest(7, {
        ...proof,
        amount: 100.129,
        proofImageUrl: 'uploads/payments/p.jpg',
      });

      expect(request.amount).toBe(100.13);
    });

    it('refuses a request from someone who is not a driver', async () => {
      const db = new FakeDb();
      const { service } = buildService(db);

      await expect(
        service.createTopUpRequest(404, {
          ...proof,
          proofImageUrl: 'uploads/payments/p.jpg',
        }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // ── 5–6: reading requests back ──────────────────────────────────────────
  describe('the driver reads their own requests', () => {
    it('sees only their own', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      db.seedDriver(9, 0);
      db.seedTopUp({ driverId: 7, amount: 100 });
      db.seedTopUp({ driverId: 9, amount: 250 });
      const { service } = buildService(db);

      const mine = await service.getMyRequests(7);

      expect(mine).toHaveLength(1);
      expect(mine[0].driverId).toBe(7);
      expect(mine.some((r) => r.driverId === 9)).toBe(false);
    });

    it('sees the rejection reason on a rejected request', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      await service.rejectRequest(filed.id, 1, 'صورة التحويل غير واضحة');
      const [mine] = await service.getMyRequests(7);

      expect(mine.status).toBe(TopUpStatus.REJECTED);
      expect(mine.adminNote).toBe('صورة التحويل غير واضحة');
    });
  });

  // ── 8–12: approval ──────────────────────────────────────────────────────
  describe('an admin approves', () => {
    const approvable = async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      return { db, filed, ...buildService(db) };
    };

    it('credits exactly the requested amount', async () => {
      const { db, filed, service } = await approvable();

      const result = await service.approveRequest(filed.id, 1);

      expect(result.newBalance).toBe(100);
      expect(db.balanceOf(7)).toBe(100);
    });

    it('adds to an existing balance rather than replacing it', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 42.5);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      const result = await service.approveRequest(filed.id, 1);

      expect(result.newBalance).toBe(142.5);
    });

    it('writes one credit entry to the ledger, referenced to the request', async () => {
      const { db, filed, service } = await approvable();

      await service.approveRequest(filed.id, 1);

      const credits = db.creditsFor(7);
      expect(credits).toHaveLength(1);
      expect(credits[0]).toMatchObject({
        amount: 100,
        type: WalletTxType.TOPUP,
        balanceAfter: 100,
        // 🔗 The audit trail between request and money.
        reference: topUpReference(filed.id),
      });
      expect(String(credits[0].note)).toContain(`#${filed.id}`);
    });

    it('marks the request APPROVED with who reviewed it and when', async () => {
      const { db, filed, service } = await approvable();

      await service.approveRequest(filed.id, 55, 'تم التأكد من التحويل');

      const stored = db.tables.topups.find((r) => r.id === filed.id)!;
      expect(stored.status).toBe(TopUpStatus.APPROVED);
      expect(stored.reviewedByAdminId).toBe(55);
      expect(stored.reviewedAt).toBeInstanceOf(Date);
      expect(stored.adminNote).toBe('تم التأكد من التحويل');
    });

    it('tells the driver the money landed', async () => {
      const { filed, service, notified } = await approvable();

      await service.approveRequest(filed.id, 1);

      expect(notified).toHaveLength(1);
      expect(notified[0].userId).toBe(7);
      expect(notified[0].message).toContain('100');
    });

    it('refuses an unknown request', async () => {
      const { service } = await approvable();
      await expect(service.approveRequest(9999, 1)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  // ── 13–15: rejection ────────────────────────────────────────────────────
  describe('an admin rejects', () => {
    it('marks it REJECTED and leaves the wallet exactly as it was', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 60);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service, notified } = buildService(db);

      const result = await service.rejectRequest(filed.id, 1, 'تحويل غير مطابق');

      expect(result.request.status).toBe(TopUpStatus.REJECTED);
      expect(db.balanceOf(7)).toBe(60);
      // No credit — not a zero-value one, none at all.
      expect(db.tables.txs).toHaveLength(0);
      expect(notified[0].message).toContain('تحويل غير مطابق');
    });

    it('refuses an unknown request', async () => {
      const db = new FakeDb();
      const { service } = buildService(db);
      await expect(service.rejectRequest(9999, 1)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  // ── 16–18: the state machine holds under retries and races ──────────────
  describe('a decision is final', () => {
    it('a rejected request can never be approved afterwards', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      await service.rejectRequest(filed.id, 1, 'مرفوض');
      await expect(service.approveRequest(filed.id, 1)).rejects.toThrow(
        BadRequestException,
      );

      expect(db.balanceOf(7)).toBe(0);
      expect(db.tables.txs).toHaveLength(0);
    });

    it('an approved request cannot be rejected afterwards', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      await service.approveRequest(filed.id, 1);
      await expect(service.rejectRequest(filed.id, 1)).rejects.toThrow(
        BadRequestException,
      );

      expect(db.balanceOf(7)).toBe(100);
    });

    it('approving twice credits once and answers the retry with the same balance', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service, notified } = buildService(db);

      const first = await service.approveRequest(filed.id, 1);
      const second = await service.approveRequest(filed.id, 1);

      expect(first.repeated).toBe(false);
      expect(second.repeated).toBe(true);
      expect(second.newBalance).toBe(100);
      expect(db.balanceOf(7)).toBe(100);
      expect(db.creditsFor(7)).toHaveLength(1);
      // A retry is not a second piece of news for the driver.
      expect(notified).toHaveLength(1);
    });

    it('two simultaneous approvals credit exactly once', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      const [a, b] = await Promise.all([
        service.approveRequest(filed.id, 1),
        service.approveRequest(filed.id, 2),
      ]);

      // 💰 100, not 200. This is the test the feature exists for.
      expect(db.balanceOf(7)).toBe(100);
      expect(db.creditsFor(7)).toHaveLength(1);
      expect([a.repeated, b.repeated].sort()).toEqual([false, true]);
    });

    it('five simultaneous approvals still credit exactly once', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      const results = await Promise.allSettled(
        Array.from({ length: 5 }, (_, i) =>
          service.approveRequest(filed.id, i + 1),
        ),
      );

      expect(db.balanceOf(7)).toBe(100);
      expect(db.creditsFor(7)).toHaveLength(1);
      const credited = results.filter(
        (r) => r.status === 'fulfilled' && r.value.repeated === false,
      );
      expect(credited).toHaveLength(1);
    });

    it('an approval racing a rejection resolves to one outcome, not both', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      const [approve, reject] = await Promise.allSettled([
        service.approveRequest(filed.id, 1),
        service.rejectRequest(filed.id, 2),
      ]);

      const stored = db.tables.topups.find((r) => r.id === filed.id)!;
      const winners = [approve, reject].filter((r) => r.status === 'fulfilled');
      expect(winners).toHaveLength(1);

      if (stored.status === TopUpStatus.APPROVED) {
        expect(db.balanceOf(7)).toBe(100);
        expect(db.creditsFor(7)).toHaveLength(1);
      } else {
        expect(stored.status).toBe(TopUpStatus.REJECTED);
        expect(db.balanceOf(7)).toBe(0);
        expect(db.tables.txs).toHaveLength(0);
      }
    });

    it('a failed credit leaves the request PENDING — the two move together', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      // The database refuses the ledger insert (a duplicate reference is the
      // real-world shape of this: a retry that got past every in-code check).
      db.tables.txs.push({
        id: 999,
        driverId: 7,
        amount: 100,
        reference: topUpReference(filed.id),
      } as Partial<WalletTransaction>);

      await expect(service.approveRequest(filed.id, 1)).rejects.toThrow(
        /UQ_wallet_transactions_reference/,
      );

      const stored = db.tables.topups.find((r) => r.id === filed.id)!;
      expect(stored.status).toBe(TopUpStatus.PENDING);
      expect(db.balanceOf(7)).toBe(0);
    });
  });

  // ── the balance every screen must agree on ──────────────────────────────
  describe('one authoritative balance', () => {
    it('the wallet summary matches the driver row the ledger wrote', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      const filed = db.seedTopUp({ driverId: 7, amount: 100 });
      const { service } = buildService(db);

      const before = await service.getWalletSummary(7);
      expect(before.balance).toBe(0);
      expect(before.ledgerBalance).toBeNull();
      expect(before.pendingTopUpCount).toBe(1);
      expect(before.pendingTopUpAmount).toBe(100);

      const approved = await service.approveRequest(filed.id, 1);
      const after = await service.getWalletSummary(7);

      // Every figure the app can read comes out the same: the driver row, the
      // ledger's running balance, and what approval returned.
      expect(after.balance).toBe(100);
      expect(after.ledgerBalance).toBe(100);
      expect(approved.newBalance).toBe(100);
      expect(after.pendingTopUpCount).toBe(0);
      expect(db.balanceOf(7)).toBe(100);
    });

    it('reports the balance of the authenticated driver only', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 100);
      db.seedDriver(9, 0);
      const { service } = buildService(db);

      expect((await service.getWalletSummary(9)).balance).toBe(0);
      expect((await service.getWalletSummary(7)).balance).toBe(100);
    });

    it('refuses a summary for an account that is not a driver', async () => {
      const db = new FakeDb();
      const { service } = buildService(db);
      await expect(service.getWalletSummary(404)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  // ── what the admin queue shows ──────────────────────────────────────────
  describe('the admin review queue', () => {
    it('lists pending requests with the driver behind them', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0, 'طلعت حرفوش');
      db.seedTopUp({
        driverId: 7,
        amount: 100,
        method: TopUpMethod.VODAFONE_CASH,
        proofImageUrl: 'uploads/payments/proof-7.jpg',
      });
      const { service } = buildService(db);

      const [row] = await service.getRequests(TopUpStatus.PENDING);

      expect(row).toMatchObject({
        driverId: 7,
        driverName: 'طلعت حرفوش',
        amount: 100,
        method: TopUpMethod.VODAFONE_CASH,
        proofImageUrl: 'uploads/payments/proof-7.jpg',
        status: TopUpStatus.PENDING,
      });
      expect(row.createdAt).toBeInstanceOf(Date);
    });

    it('filters by status', async () => {
      const db = new FakeDb();
      db.seedDriver(7, 0);
      db.seedTopUp({ driverId: 7, amount: 100 });
      db.seedTopUp({
        driverId: 7,
        amount: 50,
        status: TopUpStatus.REJECTED,
      });
      const { service } = buildService(db);

      expect(await service.getRequests(TopUpStatus.PENDING)).toHaveLength(1);
      expect(await service.getRequests(TopUpStatus.REJECTED)).toHaveLength(1);
      expect(await service.getRequests()).toHaveLength(2);
    });
  });
});

// ── 7 + 11: who is allowed to do what ───────────────────────────────────────

describe('top-up authorization', () => {
  it('every driver wallet route is behind the JWT guard', () => {
    const guards = Reflect.getMetadata(
      '__guards__',
      PaymentsController,
    ) as unknown[];
    const names = guards.map((g: never) =>
      (g as { name?: string }).name
        ? (g as { name: string }).name
        : (g as object).constructor.name,
    );
    expect(names).toContain(JwtAuthGuard.name);
  });

  it('a driver can only ever act on their own wallet — the id is the token', async () => {
    const seen: number[] = [];
    const service = {
      createTopUpRequest: (driverId: number) => {
        seen.push(driverId);
        return Promise.resolve({ success: true });
      },
      getMyRequests: (driverId: number) => {
        seen.push(driverId);
        return Promise.resolve([]);
      },
      getDriverTransactions: (driverId: number) => {
        seen.push(driverId);
        return Promise.resolve([]);
      },
      getWalletSummary: (driverId: number) => {
        seen.push(driverId);
        return Promise.resolve({ balance: 0 });
      },
    } as unknown as PaymentsService;
    const upload = {
      persistImage: () => Promise.resolve('uploads/payments/proof-x.jpg'),
    } as unknown as UploadService;

    const controller = new PaymentsController(service, upload);
    // A body naming another driver, which is exactly what an attacker sends.
    const request = { user: { sub: 7, role: 'delivery' } } as never;
    const body = {
      amount: 100,
      method: TopUpMethod.VODAFONE_CASH,
      driverId: 9,
      proofImageUrl: 'uploads/payments/someone-elses.jpg',
    } as never;

    await controller.createTopUp(request, undefined as never, body);
    await controller.myRequests(request);
    await controller.myTransactions(request);
    await controller.summary(request);

    expect(seen).toEqual([7, 7, 7, 7]);
    // The stored key is the one the upload produced, never the body's.
    expect((body as { proofImageUrl: string }).proofImageUrl).toBe(
      'uploads/payments/proof-x.jpg',
    );
  });

  it('the driver controller exposes no approve or reject route', () => {
    const routes = Object.getOwnPropertyNames(PaymentsController.prototype);
    expect(routes).not.toContain('approve');
    expect(routes).not.toContain('reject');
    expect(routes.join(' ')).not.toMatch(/approve|reject|credit/i);
  });

  it('approve and reject live behind the admin role', () => {
    const guards = Reflect.getMetadata(
      '__guards__',
      AdminPaymentsController,
    ) as unknown[];
    const names = guards.map((g: never) =>
      (g as { name?: string }).name
        ? (g as { name: string }).name
        : (g as object).constructor.name,
    );
    expect(names).toContain(JwtAuthGuard.name);
    expect(names).toContain(RolesGuard.name);

    const roles = new Reflector().get<UserRole[]>(
      ROLES_KEY,
      AdminPaymentsController,
    );
    expect(roles).toEqual([UserRole.ADMIN]);
  });

  it('records who approved a request in the admin audit log', async () => {
    const entries: Array<Record<string, unknown>> = [];
    const service = {
      approveRequest: () =>
        Promise.resolve({ success: true, newBalance: 100, repeated: false }),
    } as unknown as PaymentsService;
    const auditLog = {
      record: (entry: Record<string, unknown>) => {
        entries.push(entry);
        return Promise.resolve();
      },
    } as unknown as AdminAuditLogService;

    const controller = new AdminPaymentsController(service, auditLog);
    await controller.approve(12, { user: { sub: 3, role: 'admin' } } as never, {
      adminNote: 'ok',
    });

    expect(entries).toEqual([
      expect.objectContaining({
        adminId: 3,
        action: 'wallet.topup.approve',
        targetType: 'topup_request',
        targetId: 12,
      }),
    ]);
  });
});
