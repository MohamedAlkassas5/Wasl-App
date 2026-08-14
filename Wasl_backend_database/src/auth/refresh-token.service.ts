import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, IsNull, Repository } from 'typeorm';
import { createHash, randomBytes, randomUUID } from 'crypto';

import { RefreshToken } from './entities/refresh-token.entity';

/** How long a refresh token stays usable. */
export const REFRESH_TOKEN_TTL_DAYS = 30;

/**
 * Issues, rotates and revokes refresh tokens.
 *
 * The access token stays what it always was — a short, stateless, signed JWT
 * that `JwtAuthGuard` verifies without touching the database. What changes is
 * that it now expires in fifteen minutes instead of thirty days, and this
 * service is what keeps a signed-in user signed in across that.
 *
 * Nothing here weakens the existing model: `deletedAt` is still enforced
 * centrally on every guarded request, and refresh checks it again before
 * handing out a new access token, so a closed account cannot refresh its way
 * back in even inside a still-valid window.
 */
@Injectable()
export class RefreshTokenService {
  private readonly logger = new Logger(RefreshTokenService.name);

  constructor(
    @InjectRepository(RefreshToken)
    private readonly tokens: Repository<RefreshToken>,
  ) {}

  /** The stored form of a token. Never reversible back to the token. */
  private hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private expiryFromNow(): Date {
    return new Date(
      Date.now() + REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
    );
  }

  /**
   * A fresh token for a new sign-in, starting its own family.
   *
   * Returns the plaintext exactly once — the caller hands it to the client and
   * then it is unrecoverable.
   */
  async issue(userId: number, manager?: EntityManager): Promise<string> {
    return this.mint(userId, randomUUID(), manager);
  }

  /**
   * Spends a refresh token and issues its replacement.
   *
   * Throws for anything that is not a live, unexpired, unspent token belonging
   * to this user. The one case worth calling out is a token that was already
   * spent: that is replay, and it revokes the whole family rather than just the
   * row, because whoever replayed it may already hold the successor.
   */
  async rotate(
    presented: string,
  ): Promise<{ userId: number; refreshToken: string }> {
    const tokenHash = this.hash(presented);
    const record = await this.tokens.findOne({ where: { tokenHash } });

    if (!record) {
      throw new UnauthorizedException('جلسة الدخول غير صالحة، سجّل دخولك مجدداً');
    }

    if (record.usedAt) {
      // 🚨 Replay. Either the token was stolen, or a client is repeating
      // itself; both end the session rather than being guessed at.
      await this.revokeFamily(record.familyId);
      this.logger.warn(
        `Refresh token reuse detected for user ${record.userId}; family revoked.`,
      );
      throw new UnauthorizedException(
        'تم استخدام جلسة الدخول من مكان آخر، سجّل دخولك مجدداً',
      );
    }

    if (record.revokedAt || new Date(record.expiresAt) <= new Date()) {
      throw new UnauthorizedException('انتهت صلاحية الجلسة، سجّل دخولك مجدداً');
    }

    // Spending the old token and minting its replacement is one transaction on
    // purpose. Split across two statements, a failure between them leaves the
    // presented token spent with no successor issued: the user is silently
    // signed out, and their retry with the only token they still hold looks
    // exactly like replay, so the whole family gets revoked for what was really
    // a server-side error.
    return this.tokens.manager.transaction(async (manager) => {
      const repo = manager.getRepository(RefreshToken);

      // Conditional — two refreshes racing on the same token means only the one
      // that flips `used_at` may continue, and the loser is rejected here rather
      // than quietly getting a second token. Note the loser is *not* treated as
      // replay: it never observed a spent token, it simply lost the race.
      const spent = await repo.update(
        { id: record.id, usedAt: IsNull() },
        { usedAt: new Date() },
      );
      if (!spent.affected) {
        throw new UnauthorizedException(
          'جلسة الدخول غير صالحة، سجّل دخولك مجدداً',
        );
      }

      const refreshToken = await this.mint(
        record.userId,
        record.familyId,
        manager,
      );
      return { userId: record.userId, refreshToken };
    });
  }

  /** Ends one session — the sign-out path. */
  async revoke(presented: string): Promise<void> {
    await this.tokens.update(
      { tokenHash: this.hash(presented), revokedAt: IsNull() },
      { revokedAt: new Date() },
    );
  }

  /**
   * Ends every session a user has.
   *
   * Called when an account is closed, so a still-valid refresh token cannot
   * outlive the account that owns it.
   */
  async revokeAllForUser(
    userId: number,
    manager?: EntityManager,
  ): Promise<void> {
    const repo = manager ? manager.getRepository(RefreshToken) : this.tokens;
    await repo.update(
      { userId, revokedAt: IsNull() },
      { revokedAt: new Date() },
    );
  }

  private async revokeFamily(familyId: string): Promise<void> {
    await this.tokens.update(
      { familyId, revokedAt: IsNull() },
      { revokedAt: new Date() },
    );
  }

  private async mint(
    userId: number,
    familyId: string,
    manager?: EntityManager,
  ): Promise<string> {
    const token = randomBytes(48).toString('base64url');
    const repo = manager ? manager.getRepository(RefreshToken) : this.tokens;

    await repo.insert({
      userId,
      tokenHash: this.hash(token),
      familyId,
      expiresAt: this.expiryFromNow(),
    });

    return token;
  }
}
