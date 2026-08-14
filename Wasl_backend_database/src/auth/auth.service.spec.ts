import {
  BadRequestException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
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
import { ZonesService } from '../zones/zones.service';
import { DeliveryZone } from '../zones/entities/delivery-zone.entity';
import { RefreshTokenService } from './refresh-token.service';

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

  /** Rows the closure path deletes outright, recorded so a test can assert it. */
  let deletedFrom: { entity: string; criteria: unknown }[];

  /**
   * Stands in for the EntityManager the closure runs inside. `update` mutates
   * the in-memory user the same way a real UPDATE would, which is what lets
   * the scrub be asserted field by field.
   */
  const entityManager = {
    delete: (entity: { name: string }, criteria: unknown) => {
      deletedFrom.push({ entity: entity.name, criteria });
      return Promise.resolve({ affected: 1 });
    },
    update: (
      _entity: unknown,
      criteria: { id: number },
      patch: Partial<User>,
    ) => {
      const index = users.findIndex((u) => u.id === criteria.id);
      if (index >= 0) users[index] = { ...users[index], ...patch };
      return Promise.resolve({ affected: 1 });
    },
  };

  const userRepository = {
    manager: {
      transaction: (run: (m: typeof entityManager) => Promise<unknown>) =>
        run(entityManager),
    },
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

  /** Only `kom_hamada` (id 1) is an approved area in these tests. */
  const zonesService = {
    getActiveZone: (id: number) =>
      id === 1
        ? Promise.resolve({
            id: 1,
            code: 'kom_hamada',
            name: 'كوم حمادة',
          } as DeliveryZone)
        : Promise.reject(
            new BadRequestException('المنطقة المختارة غير مدعومة'),
          ),
  };

  const otpService = {
    isPhoneVerified: (phone: string) =>
      Promise.resolve(verifiedPhones.has(phone)),
    consumeVerification: (phone: string) => {
      verifiedPhones.delete(phone);
      return Promise.resolve();
    },
  };

  /**
   * Stands in for RefreshTokenService. The rotation rules themselves are pinned
   * in refresh-token.service.spec.ts; what matters here is only what AuthService
   * asks it to do — issue on sign-in, rotate on refresh, and revoke everything
   * when an account is closed.
   */
  const refreshTokens = {
    issuedFor: [] as number[],
    revokedAllFor: [] as number[],
    revokedTokens: [] as string[],
    /** Set per-test to control what the presented token rotates into. */
    rotatesTo: { userId: 0, refreshToken: 'rotated-token' },

    issue: (userId: number) => {
      refreshTokens.issuedFor.push(userId);
      return Promise.resolve(`refresh-for-${userId}`);
    },
    rotate: (_presented: string) => Promise.resolve(refreshTokens.rotatesTo),
    revoke: (presented: string) => {
      refreshTokens.revokedTokens.push(presented);
      return Promise.resolve();
    },
    revokeAllForUser: (userId: number) => {
      refreshTokens.revokedAllFor.push(userId);
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
    deletedFrom = [];
    refreshTokens.issuedFor = [];
    refreshTokens.revokedAllFor = [];
    refreshTokens.revokedTokens = [];
    refreshTokens.rotatesTo = { userId: 0, refreshToken: 'rotated-token' };

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
        { provide: ZonesService, useValue: zonesService },
        { provide: RefreshTokenService, useValue: refreshTokens },
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

  /**
   * Closing an account used to be `DELETE FROM users`, which threw a foreign
   * key violation for anyone who had ever ordered — the button simply never
   * worked. It now scrubs the row instead, which is also what stops a customer
   * erasing the delivery and commission records that belong to their driver.
   */
  describe('account closure', () => {
    const seedCustomer = (overrides: Partial<User> = {}) => {
      users.push({
        id: 1,
        name: 'أحمد',
        phone: PHONE,
        passwordHash: 'realhash',
        email: 'ahmed@example.com',
        firebaseUid: 'uid-123',
        customerZoneId: 1,
        role: UserRole.CUSTOMER,
        status: AccountStatus.ACTIVE,
        ...overrides,
      } as User);
    };

    it('succeeds instead of failing on the orders foreign key', async () => {
      seedCustomer();
      await expect(service.deleteAccountById(1)).resolves.toMatchObject({
        success: true,
      });
    });

    it('keeps the row so the orders on it stay readable', async () => {
      seedCustomer();
      await service.deleteAccountById(1);
      expect(users).toHaveLength(1);
    });

    it('scrubs every piece of personal data', async () => {
      seedCustomer();
      await service.deleteAccountById(1);

      expect(users[0].name).toBe('حساب محذوف');
      expect(users[0].email).toBeNull();
      expect(users[0].firebaseUid).toBeNull();
      expect(users[0].customerZoneId).toBeNull();
      expect(users[0].deletedAt).toBeInstanceOf(Date);
    });

    it('leaves a password no input can match', async () => {
      seedCustomer();
      await service.deleteAccountById(1);

      expect(users[0].passwordHash).not.toBe('realhash');
      await expect(
        bcrypt.compare('realhash', users[0].passwordHash),
      ).resolves.toBe(false);
    });

    it('releases the phone number for a fresh signup', async () => {
      seedCustomer();
      await service.deleteAccountById(1);

      expect(users[0].phone).not.toBe(PHONE);
      expect(users[0].phone.length).toBeLessThanOrEqual(20);
    });

    it('removes notifications and any outstanding OTP', async () => {
      seedCustomer();
      await service.deleteAccountById(1);

      const entities = deletedFrom.map((d) => d.entity);
      expect(entities).toContain('InAppNotification');
      expect(entities).toContain('OtpVerification');
    });

    it('removes the identity documents on a driver profile', async () => {
      seedCustomer({ role: UserRole.DELIVERY });
      await service.deleteAccountById(1);

      expect(deletedFrom.map((d) => d.entity)).toContain('DeliveryPartner');
    });

    it('does not touch a driver profile when closing a customer', async () => {
      seedCustomer();
      await service.deleteAccountById(1);

      expect(deletedFrom.map((d) => d.entity)).not.toContain('DeliveryPartner');
    });

    it('404s rather than silently succeeding on an unknown account', async () => {
      await expect(service.deleteAccountById(404)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('resolves an admin-initiated closure by exact phone', async () => {
      seedCustomer();
      await expect(
        service.deleteAccountByPhone('+20 100 123 4567'),
      ).resolves.toMatchObject({ success: true });
      expect(users[0].deletedAt).toBeInstanceOf(Date);
    });

    it('ends every session the account had', async () => {
      seedCustomer();
      await service.deleteAccountById(1);

      // Without this, a closed account keeps a refresh token that mints fresh
      // access tokens for thirty days — the scrub would be cosmetic.
      expect(refreshTokens.revokedAllFor).toContain(1);
    });
  });

  /**
   * The access token is fifteen minutes long, so every signed-in user hits the
   * refresh path several times an hour. These pin the two things that must not
   * drift: a refresh is a full re-check of the account, not a rubber stamp on
   * whatever was true at sign-in, and signing out ends one session rather than
   * all of them.
   */
  describe('session refresh', () => {
    const seedUser = (overrides: Partial<User> = {}) => {
      users.push({
        id: 1,
        name: 'أحمد',
        phone: PHONE,
        passwordHash: 'realhash',
        role: UserRole.CUSTOMER,
        status: AccountStatus.ACTIVE,
        ...overrides,
      } as User);
    };

    it('hands back a new access token and a rotated refresh token', async () => {
      seedUser();
      refreshTokens.rotatesTo = { userId: 1, refreshToken: 'the-next-one' };

      const result = await service.refreshSession('the-current-one');

      expect(result.token).toBeTruthy();
      expect(result.refreshToken).toBe('the-next-one');
      // The client needs to know how long it has before doing this again.
      expect(result.expiresIn).toBe('15m');
    });

    it('refuses a closed account and revokes what it still holds', async () => {
      seedUser({ deletedAt: new Date() } as Partial<User>);
      refreshTokens.rotatesTo = { userId: 1, refreshToken: 'the-next-one' };

      await expect(
        service.refreshSession('the-current-one'),
      ).rejects.toBeInstanceOf(UnauthorizedException);

      // Closure already revoked these; re-checking here is what stops a token
      // issued seconds before closure from outliving it.
      expect(refreshTokens.revokedAllFor).toContain(1);
    });

    it('refuses a suspended account', async () => {
      seedUser({ status: AccountStatus.SUSPENDED });
      refreshTokens.rotatesTo = { userId: 1, refreshToken: 'the-next-one' };

      await expect(
        service.refreshSession('the-current-one'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('refuses a user that no longer exists', async () => {
      refreshTokens.rotatesTo = { userId: 404, refreshToken: 'the-next-one' };

      await expect(
        service.refreshSession('the-current-one'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('issues a refresh token alongside the access token at sign-in', async () => {
      verifiedPhones.add(PHONE);

      const result = await service.register(registerDto());

      expect(result.refreshToken).toBeTruthy();
      expect(refreshTokens.issuedFor).toHaveLength(1);
    });

    it('signs out of this session only', async () => {
      await expect(service.logout('this-device')).resolves.toMatchObject({
        success: true,
      });

      expect(refreshTokens.revokedTokens).toEqual(['this-device']);
      // Signing out on the phone must not sign the tablet out too.
      expect(refreshTokens.revokedAllFor).toHaveLength(0);
    });
  });
});
