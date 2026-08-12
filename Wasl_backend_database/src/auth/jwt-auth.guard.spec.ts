import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

import { JwtAuthGuard } from './jwt-auth.guard';
import { JWT_SECRET } from './jwt.constants';
import { AccountAccessService } from './account-access.service';
import { UserRole } from '../users/entities/user.entity';

/**
 * The guard is the one place that decides whether a token still buys access.
 *
 * Closing an account keeps its row — the orders on it reference a driver who
 * was paid — so the JWT issued beforehand stays cryptographically valid until
 * it expires. Signature checking alone therefore cannot tell a live session
 * from a closed one, and every protected route would keep answering a deleted
 * account for the rest of the token's lifetime. Checking it here covers
 * profile, pricing, orders, driver and wallet routes at once, rather than
 * relying on each controller to remember.
 */
describe('JwtAuthGuard', () => {
  const jwt = new JwtService({ secret: JWT_SECRET });

  const contextWith = (token?: string): ExecutionContext => {
    const request: { headers: Record<string, string>; user?: unknown } = {
      headers: token ? { authorization: `Bearer ${token}` } : {},
    };
    return {
      switchToHttp: () => ({ getRequest: () => request }),
    } as unknown as ExecutionContext;
  };

  const guardWith = (isClosed: boolean | (() => Promise<boolean>)) =>
    new JwtAuthGuard(jwt, {
      isClosed:
        typeof isClosed === 'function'
          ? isClosed
          : () => Promise.resolve(isClosed),
    } as unknown as AccountAccessService);

  const tokenFor = (sub: number, role = UserRole.CUSTOMER) =>
    jwt.sign({ sub, role }, { secret: JWT_SECRET });

  it('admits a live account', async () => {
    await expect(
      guardWith(false).canActivate(contextWith(tokenFor(10))),
    ).resolves.toBe(true);
  });

  it('attaches the verified identity to the request', async () => {
    const context = contextWith(tokenFor(10, UserRole.DELIVERY));
    await guardWith(false).canActivate(context);

    const request = context.switchToHttp().getRequest<{
      user?: { sub: number; role: UserRole };
    }>();
    expect(request.user).toMatchObject({ sub: 10, role: UserRole.DELIVERY });
  });

  describe('a closed account', () => {
    it('is rejected even though its token is perfectly valid', async () => {
      const token = tokenFor(10);
      // Same token, same signature — only the account state differs.
      await expect(
        guardWith(false).canActivate(contextWith(token)),
      ).resolves.toBe(true);
      await expect(
        guardWith(true).canActivate(contextWith(token)),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('is rejected for a driver token too, not just a customer one', async () => {
      await expect(
        guardWith(true).canActivate(
          contextWith(tokenFor(20, UserRole.DELIVERY)),
        ),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('says the account was deleted rather than blaming the session', async () => {
      await expect(
        guardWith(true).canActivate(contextWith(tokenFor(10))),
      ).rejects.toThrow('تم حذف هذا الحساب');
    });

    it('never reaches the handler, so no route can serve it', async () => {
      const context = contextWith(tokenFor(10));
      await expect(guardWith(true).canActivate(context)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      const request = context.switchToHttp().getRequest<{ user?: unknown }>();
      expect(request.user).toBeUndefined();
    });
  });

  describe('token problems', () => {
    it('rejects a missing token', async () => {
      await expect(
        guardWith(false).canActivate(contextWith()),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects a token signed with the wrong secret', async () => {
      const forged = new JwtService({ secret: 'not-our-secret' }).sign({
        sub: 10,
        role: UserRole.ADMIN,
      });
      await expect(
        guardWith(false).canActivate(contextWith(forged)),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('does not consult the database for a token that never verified', async () => {
      const isClosed = jest.fn().mockResolvedValue(false);
      await expect(
        guardWith(isClosed).canActivate(contextWith('garbage')),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(isClosed).not.toHaveBeenCalled();
    });
  });

  it('surfaces a database failure instead of calling it an expired session', async () => {
    // Failing open here would let a closed account back in the moment the
    // database hiccupped; mislabelling it would send the user to re-login for
    // a problem that is ours.
    const guard = guardWith(() => Promise.reject(new Error('db down')));
    await expect(guard.canActivate(contextWith(tokenFor(10)))).rejects.toThrow(
      'db down',
    );
  });
});
