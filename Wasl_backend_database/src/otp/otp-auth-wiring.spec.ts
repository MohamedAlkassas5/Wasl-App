import { ConfigModule } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { getDataSourceToken, getRepositoryToken } from '@nestjs/typeorm';

import { AuthModule } from '../auth/auth.module';
import { AuthService } from '../auth/auth.service';
import { OtpModule } from './otp.module';
import { OtpService } from './otp.service';
import { OtpVerification } from './entities/otp-verification.entity';
import { User } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { DeliveryZone } from '../zones/entities/delivery-zone.entity';
import { DeliveryZoneRate } from '../zones/entities/delivery-zone-rate.entity';
import { RefreshToken } from '../auth/entities/refresh-token.entity';
import { AccountAccessModule } from '../auth/account-access.module';

/**
 * AuthModule and OtpModule import each other through `forwardRef`. That kind of
 * wiring compiles fine and then fails at boot with "Nest can't resolve
 * dependencies" — and boot here needs a live Postgres, so nothing else in the
 * suite would catch it. This compiles both modules with the repositories
 * stubbed out, which exercises the container without a database.
 */
describe('Auth ↔ Otp module wiring', () => {
  let moduleRef: TestingModule;

  const stubRepository = {
    findOne: () => Promise.resolve(null),
    create: (data: unknown) => data,
    save: (data: unknown) => Promise.resolve(data),
    delete: () => Promise.resolve({ affected: 0 }),
  };

  beforeAll(async () => {
    const builder = Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({ isGlobal: true }),
        // Global in the running app; imported explicitly here because a test
        // module gets only what it asks for. JwtAuthGuard needs it to reject
        // closed accounts.
        AccountAccessModule,
        AuthModule,
        OtpModule,
      ],
    });

    // Stand in for everything TypeORM would otherwise need a connection for.
    // AuthModule pulls in ZonesModule so registration can validate the
    // customer's chosen area, which is why the zone repositories are here.
    for (const entity of [
      User,
      DeliveryPartner,
      Merchant,
      OtpVerification,
      DeliveryZone,
      DeliveryZoneRate,
      // Sessions are stored now, so AuthModule needs this one too.
      RefreshToken,
    ]) {
      builder
        .overrideProvider(getRepositoryToken(entity))
        .useValue(stubRepository);
    }
    builder.overrideProvider(getDataSourceToken()).useValue({});

    moduleRef = await builder.compile();
  });

  afterAll(async () => {
    await moduleRef?.close();
  });

  it('resolves AuthService with OtpService injected into it', () => {
    const authService = moduleRef.get(AuthService);
    expect(authService).toBeInstanceOf(AuthService);
    // The gate on registration is the whole reason for the circular import.
    expect(moduleRef.get(OtpService)).toBeInstanceOf(OtpService);
  });

  it('refuses registration for an unverified phone through the real wiring', async () => {
    const authService = moduleRef.get(AuthService);

    // No OTP was ever issued, so the stub repository has nothing verified.
    await expect(
      authService.register({
        name: 'أحمد',
        phone: '201001234567',
        password: 'secret123',
        role: 'customer',
      } as Parameters<AuthService['register']>[0]),
    ).rejects.toThrow(/التحقق من رقم الهاتف/);
  });
});
