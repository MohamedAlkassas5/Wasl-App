import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { User } from '../users/entities/user.entity';
import { AccountAccessService } from './account-access.service';

/**
 * Global so `JwtAuthGuard` resolves the same way in every module that guards a
 * route. Without this, each of orders/wallet/pricing/users/files/delivery would
 * have to import the User repository purely to satisfy the guard's dependency —
 * the kind of wiring that gets forgotten in a new module and silently drops the
 * check on exactly the route that needed it.
 */
@Global()
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [AccountAccessService],
  exports: [AccountAccessService],
})
export class AccountAccessModule {}
