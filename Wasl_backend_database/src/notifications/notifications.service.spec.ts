import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import {
  NotificationsService,
  NotificationKind,
} from './notifications.service';
import { DeviceToken, DevicePlatform } from './entities/device-token.entity';
import { InAppNotification } from '../orders/entities/notification.entity';
import {
  PUSH_PROVIDER,
  PushMessage,
  PushResult,
} from './push-provider.interface';

/**
 * One notification, delivered twice: a row the app can list, and a push the
 * phone can wake up for.
 *
 * The invariant that matters most here is that push is a *courtesy*. The row is
 * the durable record, and nothing about a failing push may propagate back into
 * the operation that triggered it — an order really was offered whether or not
 * Google accepted the message.
 */
describe('NotificationsService', () => {
  let devices: Partial<DeviceToken>[];
  let rows: Partial<InAppNotification>[];
  let sent: PushMessage[];
  let pushResult: PushResult;
  let pushThrows: boolean;
  let service: NotificationsService;
  let nextId: number;

  /** Enough of TypeORM's `In(...)` to drive these tests. */
  const inList = (value: unknown, actual: unknown) => {
    if (value && typeof value === 'object' && '_type' in value) {
      const op = value as unknown as { _value?: unknown[] };
      return (op._value ?? []).includes(actual);
    }
    return actual === value;
  };

  beforeEach(async () => {
    devices = [];
    rows = [];
    sent = [];
    pushResult = { sent: 0, invalidTokens: [] };
    pushThrows = false;
    nextId = 1;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        {
          provide: getRepositoryToken(InAppNotification),
          useValue: {
            create: (v: unknown) => v,
            save: (v: unknown) => {
              const many = Array.isArray(v) ? v : [v];
              many.forEach((row: Partial<InAppNotification>) =>
                rows.push({ id: nextId++, ...row }),
              );
              return Promise.resolve(Array.isArray(v) ? many : many[0]);
            },
          },
        },
        {
          provide: getRepositoryToken(DeviceToken),
          useValue: {
            create: (v: unknown) => v,
            save: (v: Partial<DeviceToken>) => {
              if (!v.id) devices.push({ id: nextId++, ...v });
              return Promise.resolve(v);
            },
            findOne: ({ where }: { where: { token?: string } }) =>
              Promise.resolve(
                devices.find((d) => d.token === where.token) ?? null,
              ),
            find: ({ where }: { where: { userId: unknown } }) =>
              Promise.resolve(
                devices.filter((d) => inList(where.userId, d.userId)),
              ),
            delete: (where: { token?: unknown; userId?: number }) => {
              devices = devices.filter(
                (d) =>
                  !(
                    inList(where.token, d.token) &&
                    (where.userId == null || where.userId === d.userId)
                  ),
              );
              return Promise.resolve({ affected: 1 });
            },
          },
        },
        {
          provide: PUSH_PROVIDER,
          useValue: {
            name: 'test',
            send: (message: PushMessage) => {
              if (pushThrows) return Promise.reject(new Error('provider down'));
              sent.push(message);
              return Promise.resolve(pushResult);
            },
          },
        },
      ],
    }).compile();

    service = module.get(NotificationsService);
  });

  const token = (n: number) => `tok-${'x'.repeat(20)}-${n}`;

  describe('device registration', () => {
    it('stores a token for the caller', async () => {
      await service.registerDevice(10, token(1), DevicePlatform.ANDROID);

      expect(devices).toHaveLength(1);
      expect(devices[0]).toMatchObject({ userId: 10, token: token(1) });
    });

    it('moves an existing token to whoever signed in last', async () => {
      // A shared phone. Without this the previous driver would keep receiving
      // offers on a device they no longer hold.
      await service.registerDevice(10, token(1));
      await service.registerDevice(11, token(1));

      expect(devices).toHaveLength(1);
      expect(devices[0].userId).toBe(11);
    });

    it('forgets a token on sign-out', async () => {
      await service.registerDevice(10, token(1));
      await service.unregisterDevice(10, token(1));

      expect(devices).toHaveLength(0);
    });
  });

  describe('sending', () => {
    it('writes the in-app row and pushes to every device the user has', async () => {
      await service.registerDevice(10, token(1));
      await service.registerDevice(10, token(2));

      await service.notify(10, 'عنوان', 'نص', {
        kind: NotificationKind.ORDER_OFFER,
        orderId: 7,
      });

      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ userId: 10, title: 'عنوان' });
      expect(sent).toHaveLength(1);
      expect(sent[0].tokens.sort()).toEqual([token(1), token(2)].sort());
    });

    it('carries only routing hints in the payload', async () => {
      await service.registerDevice(10, token(1));

      await service.notify(10, 'عنوان', 'نص', {
        kind: NotificationKind.ORDER_OFFER,
        orderId: 7,
      });

      // Anything beyond these would be sitting on Google's servers.
      expect(sent[0].data).toEqual({ kind: 'order_offer', orderId: '7' });
    });

    it('still records the row when the user has no device registered', async () => {
      await service.notify(10, 'عنوان', 'نص');

      expect(rows).toHaveLength(1);
      expect(sent).toHaveLength(0);
    });

    it('writes a row per recipient and pushes once', async () => {
      await service.registerDevice(10, token(1));
      await service.registerDevice(11, token(2));

      await service.notifyMany([10, 11], 'عنوان', 'نص');

      expect(rows).toHaveLength(2);
      expect(sent).toHaveLength(1);
      expect(sent[0].tokens).toHaveLength(2);
    });

    it('does nothing at all for an empty recipient list', async () => {
      await service.notifyMany([], 'عنوان', 'نص');

      expect(rows).toHaveLength(0);
      expect(sent).toHaveLength(0);
    });
  });

  describe('when push misbehaves', () => {
    it('prunes tokens the provider reports as dead', async () => {
      await service.registerDevice(10, token(1));
      await service.registerDevice(10, token(2));
      pushResult = { sent: 1, invalidTokens: [token(1)] };

      await service.notify(10, 'عنوان', 'نص');

      expect(devices.map((d) => d.token)).toEqual([token(2)]);
    });

    it('never lets a provider failure reach the caller', async () => {
      // The order was still offered. A push that did not arrive is a degraded
      // notification, not a failed operation.
      await service.registerDevice(10, token(1));
      pushThrows = true;

      await expect(service.notify(10, 'عنوان', 'نص')).resolves.toBeDefined();
      expect(rows).toHaveLength(1);
    });
  });
});
