import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';

/**
 * Answers one question for the authentication layer: is this account still
 * allowed to use the API at all?
 *
 * Closing an account scrubs the row but keeps it, so the JWT handed out before
 * that stays cryptographically valid until it expires. Signature checking alone
 * therefore cannot tell a live session from a closed one, and every protected
 * route — orders, wallet, pricing, driver actions — would keep serving a
 * deleted account for the rest of the token's lifetime.
 *
 * Deliberately its own tiny service rather than reusing `UsersService`: the
 * guard runs on every authenticated request, so this reads two columns by
 * primary key and nothing else. It also keeps the guard free of the zone and
 * profile dependencies `UsersService` carries, which would otherwise have to be
 * resolvable inside every module that guards a route.
 */
@Injectable()
export class AccountAccessService {
  constructor(
    @InjectRepository(User)
    private readonly users: Repository<User>,
  ) {}

  /** True when the account behind this id has been closed by its owner. */
  async isClosed(userId: number): Promise<boolean> {
    const user = await this.users.findOne({
      where: { id: userId },
      select: { id: true, deletedAt: true },
    });

    // A token whose subject no longer exists is treated as closed rather than
    // "fine": the account is gone either way, and failing open here would be
    // the more dangerous mistake.
    return !user || user.deletedAt != null;
  }
}
