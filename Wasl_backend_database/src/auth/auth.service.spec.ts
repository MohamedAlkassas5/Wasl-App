import { BadRequestException } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';

import { AuthService } from './auth.service';
import { JWT_SECRET } from './jwt.constants';
import { RegisterDto } from './register.dto';
import { OtpService } from '../otp/otp.service';
import { User, UserRole, AccountStatus } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';

/**
 * Registration used to accept any phone number the client typed — the OTP
 * screen was decorative, because nothing on the server checked it. These tests
 * pin the gate: no account without a fresh WhatsApp verification, and the
 * verification is spent once used.
 */
describe('AuthService (phone-verified registration)', () => {
  const PHONE = '201001234567';

  let service: AuthService;
  let users: User[];
  let verifiedPhones: Set<string>;

  const userRepository = {
    findOne: ({ where }: { where: { phone?: string; id?: number } }) =>
      Promise.resolve(
        users.find(
          (u) =>
            (where.phone !== undefined && u.phone === where.phone) ||
            (where.id !== undefined && u.id === where.id),
        ) ?? null,
      ),
    create: (data: Partial<User>) =>
      ({ id: users.length + 1, ...data }) as User,
    save: (user: User) => {
      const existing = users.findIndex((u) => u.id === user.id);
      if (existing >= 0) users[existing] = user;
      else users.push(user);
      return Promise.resolve(user);
    },
    delete: () => Promise.resolve({ affected: 1 }),
  };

  const emptyRepository = {
    create: (data: unknown) => data,
    save: (data: unknown) => Promise.resolve(data),
    delete: () => Promise.resolve({ affected: 1 }),
  };

  const otpService = {
    isPhoneVerified: (phone: string) =>
      Promise.resolve(verifiedPhones.has(phone)),
    consumeVerification: (phone: string) => {
      verifiedPhones.delete(phone);
      return Promise.resolve();
    },
  };

  const registerDto = (overrides: Partial<RegisterDto> = {}): RegisterDto => ({
    name: 'أحمد',
    phone: PHONE,
    password: 'secret123',
    role: UserRole.CUSTOMER,
    ...overrides,
  });

  beforeEach(async () => {
    users = [];
    verifiedPhones = new Set();

    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [JwtModule.register({ secret: JWT_SECRET })],
      providers: [
        AuthService,
        { provide: getRepositoryToken(User), useValue: userRepository },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: emptyRepository,
        },
        { provide: getRepositoryToken(Merchant), useValue: emptyRepository },
        { provide: OtpService, useValue: otpService },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('refuses to create an account for a phone that was never verified', async () => {
    await expect(service.register(registerDto())).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(users).toHaveLength(0);
  });

  it('creates the account once the phone holds a fresh verification', async () => {
    verifiedPhones.add(PHONE);

    const result = await service.register(registerDto());

    expect(result.user.phone).toBe(PHONE);
    expect(result.token).toBeTruthy();
    expect(users).toHaveLength(1);
  });

  it('spends the verification, so a second account cannot ride the same code', async () => {
    verifiedPhones.add(PHONE);
    await service.register(registerDto());

    await expect(
      service.register(registerDto({ phone: '201009999999' })),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('treats +20 100 123 4567 and 201001234567 as the same number', async () => {
    verifiedPhones.add(PHONE);

    const result = await service.register(
      registerDto({ phone: '+20 100 123 4567' }),
    );

    expect(result.user.phone).toBe(PHONE);
  });

  describe('password reset', () => {
    const seedUser = async (password: string) => {
      users.push({
        id: 1,
        name: 'أحمد',
        phone: PHONE,
        passwordHash: await bcrypt.hash(password, 10),
        role: UserRole.CUSTOMER,
        status: AccountStatus.ACTIVE,
      } as User);
    };

    it('replaces the stored hash so the old password stops working', async () => {
      await seedUser('oldpassword');

      await service.resetPasswordWithVerifiedPhone(PHONE, 'newpassword');

      await expect(
        bcrypt.compare('newpassword', users[0].passwordHash),
      ).resolves.toBe(true);
      await expect(
        bcrypt.compare('oldpassword', users[0].passwordHash),
      ).resolves.toBe(false);
    });

    it('answers the same for an unknown phone, so accounts cannot be enumerated', async () => {
      const known = await service.resetPasswordWithVerifiedPhone(
        PHONE,
        'newpassword',
      );
      const unknown = await service.resetPasswordWithVerifiedPhone(
        '201005555555',
        'newpassword',
      );

      expect(unknown).toEqual(known);
    });
  });
});
