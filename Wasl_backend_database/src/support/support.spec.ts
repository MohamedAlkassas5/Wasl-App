import { NotFoundException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { SupportService } from './support.service';
import { SupportController } from './support.controller';
import { AdminSupportController } from './admin-support.controller';
import {
  SupportConversation,
  SupportConversationStatus,
} from './entities/support-conversation.entity';
import {
  SupportMessage,
  SupportMessageKind,
  SupportMessageSender,
} from './entities/support-message.entity';
import { User, UserRole } from '../users/entities/user.entity';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { ROLES_KEY } from '../auth/decorators/roles.decorator';
import type { AuthUser } from '../auth/current-user';
import type { AdminAuditLogService } from '../admin/admin-audit-log.service';
import type { UploadService } from '../storage/upload.service';

/**
 * Driver ↔ admin support chat.
 *
 * The feature is a chat, but almost everything that can go wrong with it is an
 * authorization question, so that is what most of this file is about:
 *
 *   - one driver must never reach another driver's thread;
 *   - a driver must never be able to write a message that *looks* like it came
 *     from the admin team — this is the channel where the platform tells
 *     someone what happened to their money;
 *   - and support must stay separate from the order chat, which has different
 *     participants and a different privacy rule.
 */

type Row = Record<string, unknown>;

/** In-memory support tables with the one constraint that matters. */
class FakeSupportDb {
  conversations: Partial<SupportConversation>[] = [];
  messages: Partial<SupportMessage>[] = [];
  users: Partial<User>[] = [];
  private nextConversationId = 1;
  private nextMessageId = 1;

  seedUser(id: number, name: string, role = UserRole.DELIVERY) {
    this.users.push({ id, name, phone: `0100000${id}`, role });
  }

  get conversationRepository() {
    return {
      findOne: ({ where }: { where: Row }) =>
        Promise.resolve(
          this.conversations.find((c) =>
            Object.entries(where).every(
              ([k, v]) => (c as Row)[k] === v,
            ),
          ) ?? null,
        ),
      find: ({ where }: { where?: Row } = {}) =>
        Promise.resolve(
          this.conversations.filter((c) =>
            Object.entries(where ?? {}).every(
              ([k, v]) => (c as Row)[k] === v,
            ),
          ),
        ),
      create: (row: Row) => ({ ...row }),
      save: (row: Partial<SupportConversation>) => {
        // UNIQUE (user_id) — the database's refusal, not the service's.
        if (
          row.id === undefined &&
          this.conversations.some((c) => c.userId === row.userId)
        ) {
          return Promise.reject(
            new Error(
              'duplicate key value violates unique constraint "idx_support_conversations_user"',
            ),
          );
        }
        const saved = { id: this.nextConversationId++, ...row };
        this.conversations.push(saved);
        return Promise.resolve(saved);
      },
      update: (criteria: Row, patch: Row) => {
        this.conversations
          .filter((c) =>
            Object.entries(criteria).every(([k, v]) => (c as Row)[k] === v),
          )
          .forEach((c) => Object.assign(c, patch));
        return Promise.resolve({ affected: 1 });
      },
    };
  }

  get messageRepository() {
    const matches = (m: Partial<SupportMessage>, where: Row) =>
      Object.entries(where).every(([k, v]) => {
        const actual = (m as Row)[k];
        // `IsNull()` and `MoreThan()` arrive as FindOperator objects.
        if (v && typeof v === 'object') {
          const op = v as { type?: string; value?: unknown };
          if (op.type === 'isNull') return actual === null || actual === undefined;
          if (op.type === 'moreThan') return Number(actual) > Number(op.value);
          return false;
        }
        return actual === v;
      });

    return {
      find: ({ where, order, take }: { where?: Row; order?: Row; take?: number } = {}) => {
        let rows = this.messages.filter((m) => matches(m, where ?? {}));
        if (order && (order as Row).id === 'DESC') {
          rows = [...rows].sort((a, b) => Number(b.id) - Number(a.id));
        } else {
          rows = [...rows].sort((a, b) => Number(a.id) - Number(b.id));
        }
        return Promise.resolve(take ? rows.slice(0, take) : rows);
      },
      findOne: ({ where }: { where: Row }) =>
        Promise.resolve(this.messages.find((m) => matches(m, where)) ?? null),
      count: ({ where }: { where: Row }) =>
        Promise.resolve(this.messages.filter((m) => matches(m, where)).length),
      create: (row: Row) => ({ ...row }),
      save: (row: Partial<SupportMessage>) => {
        const saved = {
          id: this.nextMessageId++,
          createdAt: new Date(),
          readAt: null,
          ...row,
        };
        this.messages.push(saved);
        return Promise.resolve(saved);
      },
      createQueryBuilder: () => {
        const conditions: Row = {};
        let patch: Row = {};
        const builder = {
          update: () => builder,
          set: (p: Row) => {
            patch = p;
            return builder;
          },
          where: (_sql: string, params: Row) => {
            Object.assign(conditions, params);
            return builder;
          },
          andWhere: (_sql: string, params?: Row) => {
            if (params) Object.assign(conditions, params);
            return builder;
          },
          execute: () => {
            this.messages
              .filter(
                (m) =>
                  m.conversationId === conditions.conversationId &&
                  m.senderRole === conditions.from &&
                  (m.readAt === null || m.readAt === undefined),
              )
              .forEach((m) => Object.assign(m, patch));
            return Promise.resolve({ affected: 1 });
          },
        };
        return builder;
      },
    };
  }

  get userRepository() {
    return {
      find: ({ where }: { where: { id: { _value?: number[] } } }) => {
        const wanted = where.id?._value ?? [];
        return Promise.resolve(this.users.filter((u) => wanted.includes(u.id!)));
      },
      findOne: ({ where }: { where: { id: number } }) =>
        Promise.resolve(this.users.find((u) => u.id === where.id) ?? null),
    };
  }
}

function buildService(db: FakeSupportDb) {
  const notified: Array<{ userId: number; title: string; message: string }> = [];
  const upload = {
    persistImage: () => Promise.resolve('uploads/support/support-1.png'),
  } as unknown as UploadService;

  const service = new SupportService(
    db.conversationRepository as never,
    db.messageRepository as never,
    db.userRepository as never,
    upload,
    {
      notify: (userId: number, title: string, message: string) => {
        notified.push({ userId, title, message });
        return Promise.resolve({} as never);
      },
    } as never,
  );

  return { service, notified };
}

const driver = (id: number): AuthUser =>
  ({ sub: id, role: UserRole.DELIVERY }) as AuthUser;
const admin = (id: number): AuthUser =>
  ({ sub: id, role: UserRole.ADMIN }) as AuthUser;

describe('driver support chat', () => {
  // ── the driver's side ───────────────────────────────────────────────────
  describe('the driver writes to support', () => {
    it('opens a thread on the first message and stores it as a user message', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن فلاش');
      const { service } = buildService(db);

      const result = await service.sendMyMessage(driver(7), {
        body: 'حوّلت 100 جنيه والرصيد ما زادش',
      });

      expect(db.conversations).toHaveLength(1);
      expect(db.conversations[0].userId).toBe(7);
      expect(result.data).toMatchObject({
        senderId: 7,
        senderRole: SupportMessageSender.USER,
        kind: SupportMessageKind.TEXT,
        body: 'حوّلت 100 جنيه والرصيد ما زادش',
      });
    });

    it('reuses the same thread for later messages', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);

      await service.sendMyMessage(driver(7), { body: 'أولى' });
      await service.sendMyMessage(driver(7), { body: 'تانية' });

      expect(db.conversations).toHaveLength(1);
      expect(db.messages).toHaveLength(2);
    });

    it('two simultaneous first messages still make one thread', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);

      await Promise.all([
        service.sendMyMessage(driver(7), { body: 'أ' }),
        service.sendMyMessage(driver(7), { body: 'ب' }),
      ]);

      // The unique index rejects the loser's insert; it re-reads the winner's
      // row instead of quietly creating a second thread.
      expect(db.conversations).toHaveLength(1);
      expect(db.messages).toHaveLength(2);
      expect(new Set(db.messages.map((m) => m.conversationId)).size).toBe(1);
    });

    it('opening the screen does not create a thread', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);

      const result = await service.listMyMessages(driver(7), {});

      expect(result.messages).toEqual([]);
      expect(result.conversationId).toBeNull();
      expect(db.conversations).toHaveLength(0);
    });

    it('attaches a screenshot through the shared upload service', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);

      const result = await service.sendMyImage(
        driver(7),
        { buffer: Buffer.from('x') } as Express.Multer.File,
        'ده إيصال التحويل',
      );

      expect(result.data).toMatchObject({
        kind: SupportMessageKind.IMAGE,
        attachmentUrl: 'uploads/support/support-1.png',
        body: 'ده إيصال التحويل',
        senderRole: SupportMessageSender.USER,
      });
    });
  });

  // ── isolation between drivers ───────────────────────────────────────────
  describe('a driver reaches their own thread and no other', () => {
    const twoDrivers = async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن أول');
      db.seedUser(9, 'كابتن تاني');
      const built = buildService(db);
      await built.service.sendMyMessage(driver(7), { body: 'سر الكابتن الأول' });
      await built.service.sendMyMessage(driver(9), { body: 'سر الكابتن التاني' });
      return { db, ...built };
    };

    it('sees only their own messages', async () => {
      const { service } = await twoDrivers();

      // ⚠️ Both drivers are asserted deliberately. Checking only the first
      // one is vacuous: a service that ignored the caller entirely and always
      // returned the earliest thread would still hand driver 7 their own
      // messages and pass. Driver 9 is the one that catches it — verified by
      // dropping the `userId` scoping and watching this fail.
      const first = await service.listMyMessages(driver(7), {});
      expect(first.messages).toHaveLength(1);
      expect(first.messages[0].body).toBe('سر الكابتن الأول');
      expect(JSON.stringify(first)).not.toContain('سر الكابتن التاني');

      const second = await service.listMyMessages(driver(9), {});
      expect(second.messages).toHaveLength(1);
      expect(second.messages[0].body).toBe('سر الكابتن التاني');
      expect(JSON.stringify(second)).not.toContain('سر الكابتن الأول');

      // And the two really are different threads, not one shared row.
      expect(first.conversationId).not.toBe(second.conversationId);
    });

    it('their unread count counts only their own thread', async () => {
      const { db, service } = await twoDrivers();
      const otherThread = db.conversations.find((c) => c.userId === 9)!;

      // An admin replies to driver 9 only.
      await service.replyAsAdmin(otherThread.id!, admin(1), { body: 'رد' });

      expect((await service.myUnreadCount(driver(7))).unread).toBe(0);
      expect((await service.myUnreadCount(driver(9))).unread).toBe(1);
    });

    it('marking read touches only their own thread', async () => {
      const { db, service } = await twoDrivers();
      const mine = db.conversations.find((c) => c.userId === 7)!;
      const theirs = db.conversations.find((c) => c.userId === 9)!;
      await service.replyAsAdmin(mine.id!, admin(1), { body: 'رد ليّا' });
      await service.replyAsAdmin(theirs.id!, admin(1), { body: 'رد ليه' });

      await service.markMyRead(driver(7));

      expect((await service.myUnreadCount(driver(7))).unread).toBe(0);
      expect((await service.myUnreadCount(driver(9))).unread).toBe(1);
    });

    it('cannot read another driver’s attachment', async () => {
      const { db, service } = await twoDrivers();
      await service.sendMyImage(
        driver(9),
        { buffer: Buffer.from('x') } as Express.Multer.File,
        undefined,
      );
      const key = db.messages.find((m) => m.attachmentUrl)!.attachmentUrl!;

      expect(await service.canReadAttachment(driver(7), key)).toBe(false);
      expect(await service.canReadAttachment(driver(9), key)).toBe(true);
      // Admins review complaints — that is the job.
      expect(await service.canReadAttachment(admin(1), key)).toBe(true);
    });

    it('an unknown attachment key is refused, not defaulted open', async () => {
      const { service } = await twoDrivers();
      expect(
        await service.canReadAttachment(driver(7), 'uploads/support/nope.png'),
      ).toBe(false);
    });
  });

  // ── impersonation ───────────────────────────────────────────────────────
  describe('a driver cannot speak as the admin team', () => {
    it('the role on a driver message is USER whatever the body says', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);

      await service.sendMyMessage(driver(7), {
        body: 'تمام',
        // What a tampered client would send. The DTO whitelist drops these
        // before the service sees them; this proves the service would not
        // honour them even if they arrived.
        senderRole: SupportMessageSender.ADMIN,
        senderId: 1,
        conversationId: 999,
      } as never);

      expect(db.messages[0]).toMatchObject({
        senderRole: SupportMessageSender.USER,
        senderId: 7,
        conversationId: db.conversations[0].id,
      });
    });

    it('an admin reply is recorded as ADMIN and notifies the driver', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service, notified } = buildService(db);
      await service.sendMyMessage(driver(7), { body: 'مشكلة' });
      const conversation = db.conversations[0];

      await service.replyAsAdmin(conversation.id!, admin(3), {
        body: 'تم شحن محفظتك',
      });

      expect(db.messages[1]).toMatchObject({
        senderRole: SupportMessageSender.ADMIN,
        senderId: 3,
      });
      expect(notified).toEqual([
        expect.objectContaining({ userId: 7, message: 'تم شحن محفظتك' }),
      ]);
    });
  });

  // ── the admin inbox ─────────────────────────────────────────────────────
  describe('the admin inbox', () => {
    it('lists threads with who is behind them and what is unanswered', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن فلاش');
      const { service } = buildService(db);
      await service.sendMyMessage(driver(7), { body: 'محفظتي ناقصة' });

      const [thread] = await service.listConversations();

      expect(thread).toMatchObject({
        userId: 7,
        userName: 'كابتن فلاش',
        userRole: UserRole.DELIVERY,
        status: SupportConversationStatus.OPEN,
        lastMessagePreview: 'محفظتي ناقصة',
        lastMessageFrom: SupportMessageSender.USER,
        unread: 1,
      });
    });

    it('unread drops to zero once the admin reads the thread', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);
      await service.sendMyMessage(driver(7), { body: 'سؤال' });
      const conversation = db.conversations[0];

      await service.markConversationRead(conversation.id!);

      expect((await service.listConversations())[0].unread).toBe(0);
    });

    it('closing marks it handled, and a reply reopens it', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);
      await service.sendMyMessage(driver(7), { body: 'سؤال' });
      const conversation = db.conversations[0];

      await service.setStatus(
        conversation.id!,
        SupportConversationStatus.CLOSED,
      );
      expect(db.conversations[0].status).toBe(
        SupportConversationStatus.CLOSED,
      );

      await service.replyAsAdmin(conversation.id!, admin(1), { body: 'رد' });
      // Otherwise the driver sees an answer in a thread the panel calls done.
      expect(db.conversations[0].status).toBe(SupportConversationStatus.OPEN);
    });

    it('refuses an unknown conversation rather than inventing one', async () => {
      const db = new FakeSupportDb();
      const { service } = buildService(db);

      await expect(
        service.listConversationMessages(999, {}),
      ).rejects.toThrow(NotFoundException);
      await expect(
        service.replyAsAdmin(999, admin(1), { body: 'رد' }),
      ).rejects.toThrow(NotFoundException);
      await expect(
        service.setStatus(999, SupportConversationStatus.CLOSED),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // ── routing and guards ──────────────────────────────────────────────────
  describe('authorization', () => {
    it('the driver controller is behind the JWT guard', () => {
      const guards = Reflect.getMetadata(
        '__guards__',
        SupportController,
      ) as unknown[];
      const names = guards.map((g: never) =>
        (g as { name?: string }).name
          ? (g as { name: string }).name
          : (g as object).constructor.name,
      );
      expect(names).toContain(JwtAuthGuard.name);
    });

    it('the admin controller requires the ADMIN role', () => {
      const guards = Reflect.getMetadata(
        '__guards__',
        AdminSupportController,
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
        AdminSupportController,
      );
      expect(roles).toEqual([UserRole.ADMIN]);
    });

    it('no driver route accepts a conversation id — the thread is the token', async () => {
      const seen: AuthUser[] = [];
      const service = {
        listMyMessages: (user: AuthUser) => {
          seen.push(user);
          return Promise.resolve({ success: true });
        },
        myUnreadCount: (user: AuthUser) => {
          seen.push(user);
          return Promise.resolve({ success: true });
        },
        markMyRead: (user: AuthUser) => {
          seen.push(user);
          return Promise.resolve({ success: true });
        },
        sendMyMessage: (user: AuthUser) => {
          seen.push(user);
          return Promise.resolve({ success: true });
        },
        sendMyImage: (user: AuthUser) => {
          seen.push(user);
          return Promise.resolve({ success: true });
        },
      } as unknown as SupportService;

      const controller = new SupportController(service);
      const me = driver(7);
      // A body naming another thread — there is no parameter to carry it.
      const body = { body: 'hi', conversationId: 999, userId: 9 } as never;

      await controller.listMine(me, {});
      await controller.unread(me);
      await controller.markRead(me);
      await controller.send(me, body);
      await controller.sendImage(me, {} as Express.Multer.File, body);

      expect(seen).toHaveLength(5);
      expect(seen.every((u) => u.sub === 7)).toBe(true);
    });

    it('logs the admin who answered, and who they answered', async () => {
      const entries: Array<Record<string, unknown>> = [];
      const service = {
        replyAsAdmin: () => Promise.resolve({ success: true }),
      } as unknown as SupportService;
      const auditLog = {
        record: (entry: Record<string, unknown>) => {
          entries.push(entry);
          return Promise.resolve();
        },
      } as unknown as AdminAuditLogService;

      const controller = new AdminSupportController(service, auditLog);
      await controller.reply(12, admin(3), { body: 'رد رسمي' });

      expect(entries).toEqual([
        expect.objectContaining({
          adminId: 3,
          action: 'support.reply',
          targetType: 'support_conversation',
          targetId: 12,
        }),
      ]);
    });
  });

  // ── separation from the order chat ──────────────────────────────────────
  describe('support is not the order chat', () => {
    it('writes to its own table and carries no order', async () => {
      const db = new FakeSupportDb();
      db.seedUser(7, 'كابتن');
      const { service } = buildService(db);

      await service.sendMyMessage(driver(7), { body: 'مشكلة في المحفظة' });

      // A support message has no orderId to leak a delivery into, and lives in
      // support_messages — the customer on some order cannot reach it.
      expect(db.messages[0]).not.toHaveProperty('orderId');
      expect(Object.keys(db.messages[0]).sort()).toEqual([
        'body',
        'conversationId',
        'createdAt',
        'id',
        'kind',
        'readAt',
        'senderId',
        'senderRole',
      ]);
    });

    it('the two controllers own different routes', () => {
      // `support/*` for the platform channel, `orders/:orderId/chat/*` for the
      // delivery one. Nothing here touches the order routes.
      const path = Reflect.getMetadata('path', SupportController) as string;
      expect(path).toBe('support');
      expect(path).not.toContain('orders');
    });
  });
});
