import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Reflector } from '@nestjs/core';

import {
  AdminAuditLogService,
  redactAuditPayload,
} from './admin-audit-log.service';
import { AdminAuditLog } from './entities/admin-audit-log.entity';
import { AdminController } from './admin.controller';
import { AdminManagementController } from './admin-management.controller';
import { AdminService } from './admin.service';
import { SettingsController } from '../settings/settings.controller';
import { SettingsService } from '../settings/settings.service';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { ROLES_KEY } from '../auth/decorators/roles.decorator';

/**
 * CP-E / S10 — the administrator action trail.
 *
 * Admin actions used to leave nothing behind unless the action happened to
 * write its own decision onto a row (cancellation reviews did; approvals,
 * wallet credits and settings edits did not). These tests pin the three things
 * that make the log worth having: it records who actually acted, it never
 * stores a secret, and it never takes down the operation it is describing.
 */
describe('admin audit log (CP-E / S10)', () => {
  const admin: AuthUser = { sub: 42, role: UserRole.ADMIN };

  // ── the redactor ────────────────────────────────────────────────────────
  describe('payload redaction', () => {
    it('keeps ordinary fields', () => {
      expect(redactAuditPayload({ status: 'active', amount: 50 })).toEqual({
        status: 'active',
        amount: 50,
      });
    });

    it('redacts passwords, tokens, OTPs and secrets', () => {
      const out = redactAuditPayload({
        password: 'hunter2',
        newPassword: 'hunter3',
        refreshToken: 'eyJhbGciOi...',
        otp: '123456',
        code: '999999',
        apiKey: 'sk_live_x',
        note: 'مقبول',
      })!;

      expect(out.password).toBe('[redacted]');
      expect(out.newPassword).toBe('[redacted]');
      expect(out.refreshToken).toBe('[redacted]');
      expect(out.otp).toBe('[redacted]');
      expect(out.code).toBe('[redacted]');
      expect(out.apiKey).toBe('[redacted]');
      // The one field a reviewer actually needs survives.
      expect(out.note).toBe('مقبول');
    });

    it('redacts document paths', () => {
      // Part 14: never log document paths. A national-ID path in a log read by
      // support staff widens who goes looking, even though /uploads still
      // checks ownership.
      const out = redactAuditPayload({
        nationalIdFront: 'uploads/id-front-9.jpg',
        selfie: 'uploads/selfie-9.jpg',
        proofImageUrl: 'uploads/payments/p-3.png',
        logo: 'uploads/logo-2.png',
      })!;

      expect(Object.values(out)).toEqual([
        '[redacted]',
        '[redacted]',
        '[redacted]',
        '[redacted]',
      ]);
    });

    it('matches case-insensitively and as a substring', () => {
      const out = redactAuditPayload({
        PASSWORD: 'x',
        password_confirmation: 'y',
        userToken: 'z',
      })!;
      expect(Object.values(out)).toEqual([
        '[redacted]',
        '[redacted]',
        '[redacted]',
      ]);
    });

    it('reaches into nested objects and arrays', () => {
      const out = redactAuditPayload({
        outer: { inner: { password: 'p', keep: 1 } },
        list: [{ token: 't' }, { fine: true }],
      })!;

      expect((out.outer as any).inner.password).toBe('[redacted]');
      expect((out.outer as any).inner.keep).toBe(1);
      expect((out.list as any[])[0].token).toBe('[redacted]');
      expect((out.list as any[])[1].fine).toBe(true);
    });

    it('stops at a depth cap rather than walking forever', () => {
      const deep: Record<string, unknown> = {};
      let node = deep;
      for (let i = 0; i < 30; i++) {
        node.next = {};
        node = node.next as Record<string, unknown>;
      }
      expect(() => redactAuditPayload(deep)).not.toThrow();
    });

    it('returns null for a non-object payload', () => {
      expect(redactAuditPayload(undefined)).toBeNull();
      expect(redactAuditPayload('a string')).toBeNull();
    });
  });

  // ── the service ─────────────────────────────────────────────────────────
  describe('writing and reading', () => {
    let service: AdminAuditLogService;
    let inserted: Partial<AdminAuditLog>[];
    let findArgs: Record<string, unknown> | null;
    let saveImpl: (row: Partial<AdminAuditLog>) => Promise<unknown>;

    beforeEach(async () => {
      inserted = [];
      findArgs = null;
      saveImpl = (row) => {
        inserted.push(row);
        return Promise.resolve(row);
      };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          AdminAuditLogService,
          {
            provide: getRepositoryToken(AdminAuditLog),
            useValue: {
              save: (row: Partial<AdminAuditLog>) => saveImpl(row),
              findAndCount: (args: Record<string, unknown>) => {
                findArgs = args;
                return Promise.resolve([[], 0]);
              },
            },
          },
        ],
      }).compile();

      service = module.get(AdminAuditLogService);
    });

    it('writes a row with the actor, action and target', async () => {
      await service.record({
        adminId: 42,
        action: 'wallet.credit',
        targetType: 'driver',
        targetId: 9,
        payload: { amount: 100 },
      });

      expect(inserted).toHaveLength(1);
      expect(inserted[0]).toMatchObject({
        adminId: 42,
        action: 'wallet.credit',
        targetType: 'driver',
        targetId: '9',
        payload: { amount: 100 },
      });
    });

    it('stores targetId as a string, so non-numeric targets fit', async () => {
      await service.record({
        adminId: 42,
        action: 'setting.update',
        targetType: 'setting',
        targetId: 'commission_percent',
      });
      expect(inserted[0].targetId).toBe('commission_percent');
    });

    it('redacts before it stores', async () => {
      await service.record({
        adminId: 42,
        action: 'approval.review',
        targetType: 'user',
        targetId: 7,
        payload: { adminNotes: 'ok', password: 'hunter2' },
      });

      expect(inserted[0].payload).toEqual({
        adminNotes: 'ok',
        password: '[redacted]',
      });
    });

    it('never throws when the write fails', async () => {
      // The credit already happened. Turning a failed *log* into a 500 would
      // have the admin retry a completed money movement, which is far worse
      // than a missing line.
      saveImpl = () => Promise.reject(new Error('db down'));

      await expect(
        service.record({
          adminId: 42,
          action: 'wallet.credit',
          targetType: 'driver',
          targetId: 9,
        }),
      ).resolves.toBeUndefined();
    });

    it('lists newest first with a default bound', async () => {
      await service.list();
      expect(findArgs).toMatchObject({
        order: { createdAt: 'DESC', id: 'DESC' },
        take: 50,
        skip: 0,
      });
    });

    it('caps an oversized limit instead of dumping the table', async () => {
      await service.list({ limit: 100000 });
      expect((findArgs as any).take).toBe(200);
    });

    it('rejects nonsense paging values', async () => {
      await service.list({ limit: -5, offset: -10 });
      expect((findArgs as any).take).toBe(50);
      expect((findArgs as any).skip).toBe(0);
    });

    it('does not filter at all — the contract is the whole trail, paged', async () => {
      // The Master Plan specifies `GET /admin/audit-log` and nothing else.
      // Filtering by action/target/actor was removed deliberately: query
      // parameters are API surface that has to be supported once shipped, and
      // none of it was asked for. Paging stays because it is what prevents an
      // unbounded response, not because it is a feature.
      await service.list();
      expect((findArgs as any).where).toBeUndefined();
      expect(Object.keys(findArgs as object).sort()).toEqual([
        'order',
        'skip',
        'take',
      ]);
    });
  });

  // ── the write sites ─────────────────────────────────────────────────────
  describe('actions are recorded by their handlers', () => {
    const recorded: any[] = [];
    const auditStub = {
      record: (e: unknown) => {
        recorded.push(e);
        return Promise.resolve();
      },
    } as unknown as AdminAuditLogService;

    beforeEach(() => (recorded.length = 0));

    it('approval review records the reviewed user and the acting admin', async () => {
      const adminService = {
        reviewRegistration: () => Promise.resolve({ ok: true }),
      } as unknown as AdminService;

      const controller = new AdminController(adminService, auditStub);
      await controller.reviewRequest(
        7,
        { status: 'active' } as never,
        admin,
      );

      expect(recorded).toHaveLength(1);
      expect(recorded[0]).toMatchObject({
        adminId: 42, // from the token, not the body
        action: 'approval.review',
        targetType: 'user',
        targetId: 7,
      });
    });

    it('a settings edit records the setting key as the target', async () => {
      const settingsService = {
        set: () => Promise.resolve({ ok: true }),
      } as unknown as SettingsService;

      const controller = new SettingsController(settingsService, auditStub);
      await controller.update(
        'commission_percent',
        { value: '25' } as never,
        admin,
      );

      expect(recorded[0]).toMatchObject({
        adminId: 42,
        action: 'setting.update',
        targetType: 'setting',
        targetId: 'commission_percent',
        payload: { value: '25' },
      });
    });

    it('does not record when the underlying action threw', async () => {
      const adminService = {
        reviewRegistration: () => Promise.reject(new Error('nope')),
      } as unknown as AdminService;

      const controller = new AdminController(adminService, auditStub);
      await expect(
        controller.reviewRequest(7, { status: 'active' } as never, admin),
      ).rejects.toThrow('nope');

      // An entry claiming something happened that did not is worse than none.
      expect(recorded).toHaveLength(0);
    });
  });

  // ── authorization ───────────────────────────────────────────────────────
  describe('reading the log is admin-only', () => {
    it('the controller is behind JwtAuthGuard and RolesGuard', () => {
      const guards = Reflect.getMetadata(
        '__guards__',
        AdminManagementController,
      ) as unknown[];
      const names = guards.map((g: any) => (g.name ? g.name : g.constructor.name));
      expect(names).toContain(JwtAuthGuard.name);
      expect(names).toContain(RolesGuard.name);
    });

    it('and requires the ADMIN role', () => {
      const roles = new Reflector().get<UserRole[]>(
        ROLES_KEY,
        AdminManagementController,
      );
      expect(roles).toContain(UserRole.ADMIN);
    });

    it('passes only paging through to the service', async () => {
      let seen: unknown = null;
      const auditStub = {
        list: (q: unknown) => {
          seen = q;
          return Promise.resolve({ total: 0, limit: 50, offset: 0, entries: [] });
        },
      } as unknown as AdminAuditLogService;

      const controller = new AdminManagementController(
        {} as unknown as AdminService,
        auditStub,
      );
      await controller.auditTrail('10', '20');

      expect(seen).toEqual({ limit: 10, offset: 20 });
    });

    it('asks for the default page when given nothing', async () => {
      let seen: unknown = null;
      const auditStub = {
        list: (q: unknown) => {
          seen = q;
          return Promise.resolve({ total: 0, limit: 50, offset: 0, entries: [] });
        },
      } as unknown as AdminAuditLogService;

      const controller = new AdminManagementController(
        {} as unknown as AdminService,
        auditStub,
      );
      await controller.auditTrail();

      expect(seen).toEqual({ limit: undefined, offset: undefined });
    });
  });
});
