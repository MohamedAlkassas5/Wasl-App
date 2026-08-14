import { UnauthorizedException } from '@nestjs/common';
import { createHash } from 'crypto';
import { FindOperator } from 'typeorm';

import { RefreshToken } from './entities/refresh-token.entity';
import {
  RefreshTokenService,
  REFRESH_TOKEN_TTL_DAYS,
} from './refresh-token.service';

/**
 * Refresh tokens are the only credential in the system that survives longer
 * than fifteen minutes, so the rules that keep one from becoming a permanent
 * skeleton key are pinned here: it is stored as a hash and never as itself, it
 * is spendable exactly once, presenting a spent one kills every token descended
 * from that sign-in, and closing an account ends all of them at once.
 */
describe('RefreshTokenService', () => {
  const USER_ID = 7;

  let rows: RefreshToken[];
  let nextId: number;
  let service: RefreshTokenService;

  const sha256 = (value: string) =>
    createHash('sha256').update(value).digest('hex');

  const isNullOperator = (value: unknown): boolean =>
    value instanceof FindOperator && value.type === 'isNull';

  /**
   * Matches a row against a TypeORM `where`, understanding the one operator
   * this service uses. `IsNull()` matters more than it looks: the conditional
   * updates are what make spending a token atomic, so a fake that ignored it
   * would make the race tests pass for the wrong reason.
   */
  const matches = (row: RefreshToken, where: Record<string, unknown>): boolean =>
    Object.entries(where).every(([key, expected]) => {
      const actual = (row as unknown as Record<string, unknown>)[key];
      if (isNullOperator(expected)) return actual === null || actual === undefined;
      return actual === expected;
    });

  const repository = {
    findOne: ({ where }: { where: Record<string, unknown> }) =>
      Promise.resolve(rows.find((row) => matches(row, where)) ?? null),

    update: (where: Record<string, unknown>, patch: Partial<RefreshToken>) => {
      const hits = rows.filter((row) => matches(row, where));
      hits.forEach((row) => Object.assign(row, patch));
      return Promise.resolve({ affected: hits.length });
    },

    insert: (row: Partial<RefreshToken>) => {
      rows.push({
        id: nextId++,
        usedAt: null,
        revokedAt: null,
        createdAt: new Date(),
        ...row,
      } as RefreshToken);
      return Promise.resolve({ identifiers: [] });
    },

    // `rotate` spends and mints inside one transaction; the fake runs the body
    // straight through, which is enough to prove both statements are issued
    // against the same repository handle.
    manager: {
      transaction: <T>(run: (m: unknown) => Promise<T>) =>
        run({ getRepository: () => repository }),
    },
  };

  beforeEach(() => {
    rows = [];
    nextId = 1;
    service = new RefreshTokenService(repository as never);
  });

  describe('issue', () => {
    it('stores only a hash — the token itself is never persisted', async () => {
      const token = await service.issue(USER_ID);

      expect(rows).toHaveLength(1);
      expect(rows[0].tokenHash).toBe(sha256(token));
      // The plaintext must not appear in any column, under any name.
      expect(JSON.stringify(rows[0])).not.toContain(token);
    });

    it('issues a token with real entropy, not a guessable one', async () => {
      const first = await service.issue(USER_ID);
      const second = await service.issue(USER_ID);

      expect(first).not.toEqual(second);
      // 48 random bytes in base64url.
      expect(first.length).toBeGreaterThanOrEqual(64);
    });

    it('dates expiry thirty days out', async () => {
      const before = Date.now();
      await service.issue(USER_ID);

      const ttlMs = REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000;
      const expiry = rows[0].expiresAt.getTime();

      expect(REFRESH_TOKEN_TTL_DAYS).toBe(30);
      expect(expiry).toBeGreaterThanOrEqual(before + ttlMs - 1000);
      expect(expiry).toBeLessThanOrEqual(Date.now() + ttlMs + 1000);
    });

    it('starts a new family per sign-in, so one device cannot revoke another', async () => {
      await service.issue(USER_ID);
      await service.issue(USER_ID);

      expect(rows[0].familyId).not.toEqual(rows[1].familyId);
    });
  });

  describe('rotate', () => {
    it('spends the presented token and returns a different one', async () => {
      const first = await service.issue(USER_ID);

      const { userId, refreshToken } = await service.rotate(first);

      expect(userId).toBe(USER_ID);
      expect(refreshToken).not.toEqual(first);
      expect(rows[0].usedAt).toBeInstanceOf(Date);
      expect(rows[1].tokenHash).toBe(sha256(refreshToken));
    });

    it('keeps the replacement in the same family', async () => {
      const first = await service.issue(USER_ID);
      await service.rotate(first);

      expect(rows[1].familyId).toBe(rows[0].familyId);
    });

    it('rotates again and again — a session renews indefinitely', async () => {
      let token = await service.issue(USER_ID);

      for (let i = 0; i < 5; i++) {
        token = (await service.rotate(token)).refreshToken;
      }

      expect(rows).toHaveLength(6);
      expect(rows.filter((r) => r.revokedAt).length).toBe(0);
    });

    it('rejects a token that was never issued', async () => {
      await expect(service.rotate('not-a-real-token')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects an expired token', async () => {
      const token = await service.issue(USER_ID);
      rows[0].expiresAt = new Date(Date.now() - 1000);

      await expect(service.rotate(token)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects a revoked token', async () => {
      const token = await service.issue(USER_ID);
      rows[0].revokedAt = new Date();

      await expect(service.rotate(token)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('reuse detection', () => {
    it('revokes the whole family when a spent token comes back', async () => {
      const first = await service.issue(USER_ID);
      const second = (await service.rotate(first)).refreshToken;
      const third = (await service.rotate(second)).refreshToken;

      // The attacker replays the token they captured two rotations ago.
      await expect(service.rotate(first)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      // Everything from that sign-in is dead, including the token the
      // legitimate client is still holding — that is the point: the server
      // cannot tell victim from thief, so it ends the session for both.
      expect(rows.every((row) => row.revokedAt)).toBe(true);
      await expect(service.rotate(third)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('leaves other sign-ins of the same user alone', async () => {
      const phone = await service.issue(USER_ID);
      const tablet = await service.issue(USER_ID);

      await service.rotate(phone);
      await expect(service.rotate(phone)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      // The tablet was a separate family and is untouched.
      const tabletRow = rows.find((r) => r.tokenHash === sha256(tablet))!;
      expect(tabletRow.revokedAt).toBeFalsy();
      await expect(service.rotate(tablet)).resolves.toBeDefined();
    });

    it('does not punish the loser of a true race as reuse', async () => {
      const token = await service.issue(USER_ID);
      const live = rows[0];

      // The interleaving that matters: this caller read the row while it was
      // still unspent, and a concurrent refresh flipped `used_at` before this
      // one got to its UPDATE. The stale read is the whole point, so it is
      // staged directly rather than hoped for out of a scheduler.
      const freshRead = repository.findOne;
      repository.findOne = () => Promise.resolve({ ...live, usedAt: null });
      live.usedAt = new Date();

      await expect(service.rotate(token)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      repository.findOne = freshRead;

      // The conditional UPDATE caught it. This caller never *observed* a spent
      // token, so it is a lost race and not a replay — the family survives and
      // the winner stays signed in.
      expect(rows.some((row) => row.revokedAt)).toBe(false);
    });

    it('treats a second refresh that arrives after the first committed as reuse', async () => {
      const token = await service.issue(USER_ID);
      await service.rotate(token);

      // Same token, but late enough to read `used_at` already set. The server
      // has no way to tell this from a stolen token being replayed, so it ends
      // the session — which is exactly why the client must serialise its own
      // refreshes rather than firing one per concurrent 401.
      await expect(service.rotate(token)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      expect(rows.every((row) => row.revokedAt)).toBe(true);
    });
  });

  describe('revocation', () => {
    it('revoke ends one session and leaves the others signed in', async () => {
      const phone = await service.issue(USER_ID);
      const tablet = await service.issue(USER_ID);

      await service.revoke(phone);

      await expect(service.rotate(phone)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      await expect(service.rotate(tablet)).resolves.toBeDefined();
    });

    it('revoke on an unknown token is a no-op, not an error', async () => {
      await expect(service.revoke('never-issued')).resolves.toBeUndefined();
    });

    it('revokeAllForUser ends every session — the account-closure path', async () => {
      const phone = await service.issue(USER_ID);
      const tablet = await service.issue(USER_ID);
      const other = await service.issue(99);

      await service.revokeAllForUser(USER_ID);

      await expect(service.rotate(phone)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      await expect(service.rotate(tablet)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      // A different user's session is not collateral damage.
      await expect(service.rotate(other)).resolves.toBeDefined();
    });

    it('revokeAllForUser runs on the caller transaction when given one', async () => {
      const token = await service.issue(USER_ID);
      const used: string[] = [];
      const manager = {
        getRepository: () => {
          used.push('transaction');
          return repository;
        },
      };

      await service.revokeAllForUser(USER_ID, manager as never);

      // Account closure revokes inside the same transaction that scrubs the
      // user, so a rolled-back closure cannot leave sessions dead.
      expect(used).toEqual(['transaction']);
      await expect(service.rotate(token)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });
});
