import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { UsersService } from './users.service';
import { User, UserRole, AccountStatus } from './entities/user.entity';
import { ZonesService } from '../zones/zones.service';
import { DeliveryZone } from '../zones/entities/delivery-zone.entity';

/**
 * The customer's own profile: reading it, editing it, and moving between the
 * approved areas.
 *
 * Every method here resolves the account from the JWT id — there is no
 * lookup-by-phone or id-in-the-body variant — so "can I read someone else's
 * profile?" is answered by construction. What these tests pin is the rest:
 * that an unsupported area is refused, that a closed account stops resolving,
 * and that an email can't be moved onto an address another account holds.
 */
describe('UsersService (customer profile & settings)', () => {
  const KOM_HAMADA = {
    id: 1,
    code: 'kom_hamada',
    name: 'كوم حمادة',
    city: 'البحيرة',
  } as DeliveryZone;
  const BIBAN = {
    id: 2,
    code: 'biban',
    name: 'بيبان',
    city: 'البحيرة',
  } as DeliveryZone;

  let service: UsersService;
  let users: User[];

  const customer = (overrides: Partial<User> = {}): User =>
    ({
      id: 10,
      name: 'أحمد',
      phone: '201001234567',
      passwordHash: 'hash',
      role: UserRole.CUSTOMER,
      status: AccountStatus.ACTIVE,
      email: 'ahmed@example.com',
      customerZoneId: 1,
      customerZone: KOM_HAMADA,
      deletedAt: null,
      ...overrides,
    }) as User;

  const build = async (seed: User[]): Promise<UsersService> => {
    users = seed;

    const userRepository = {
      findOne: ({ where }: { where: Record<string, unknown> }) => {
        const found = users.find((u) => {
          if (where.id !== undefined) {
            // `Not(userId)` arrives as a FindOperator; the email-uniqueness
            // lookup is the only caller, so "some other row" is the intent.
            const id = where.id as { value?: number; type?: string };
            if (id?.type === 'not') {
              if (u.id === id.value) return false;
            } else if (u.id !== where.id) {
              return false;
            }
          }
          if (where.email !== undefined && u.email !== where.email) {
            return false;
          }
          return true;
        });
        return Promise.resolve(found ?? null);
      },
      save: (user: User) => {
        const index = users.findIndex((u) => u.id === user.id);
        if (index >= 0) users[index] = user;
        else users.push(user);
        return Promise.resolve(user);
      },
    };

    const zones = {
      getActiveZone: (id: number) => {
        const zone = [KOM_HAMADA, BIBAN].find((z) => z.id === id);
        return zone
          ? Promise.resolve(zone)
          : Promise.reject(
              new BadRequestException('المنطقة المختارة غير مدعومة حالياً'),
            );
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: userRepository },
        { provide: ZonesService, useValue: zones },
      ],
    }).compile();

    return module.get(UsersService);
  };

  beforeEach(async () => {
    service = await build([customer()]);
  });

  describe('retrieval', () => {
    it('returns the profile with its saved area', async () => {
      const profile = await service.getProfile(10);

      expect(profile).toMatchObject({
        id: 10,
        name: 'أحمد',
        phone: '201001234567',
        email: 'ahmed@example.com',
      });
      expect(profile.customerZone).toMatchObject({
        id: 1,
        code: 'kom_hamada',
        name: 'كوم حمادة',
      });
    });

    it('reports no area for a customer who has not chosen one', async () => {
      service = await build([
        customer({ customerZoneId: null, customerZone: undefined }),
      ]);
      await expect(service.getProfile(10)).resolves.toMatchObject({
        customerZone: null,
      });
    });

    it('never leaks the password hash', async () => {
      const profile = await service.getProfile(10);
      expect(profile).not.toHaveProperty('passwordHash');
    });

    it('404s for an id with no account behind it', async () => {
      await expect(service.getProfile(999)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('profile update', () => {
    it('saves a new name', async () => {
      const result = await service.updateProfile(10, { name: 'أحمد محمد' });

      expect(result.success).toBe(true);
      expect(users[0].name).toBe('أحمد محمد');
    });

    it('leaves the email alone when only the name is sent', async () => {
      await service.updateProfile(10, { name: 'اسم جديد' });
      expect(users[0].email).toBe('ahmed@example.com');
    });

    it('stores the email lowercased', async () => {
      await service.updateProfile(10, { email: 'NEW@Example.COM' });
      expect(users[0].email).toBe('new@example.com');
    });

    it('clears the email when sent empty, rather than storing ""', async () => {
      await service.updateProfile(10, { email: '' });
      expect(users[0].email).toBeNull();
    });

    it('refuses an email another account already holds', async () => {
      service = await build([
        customer(),
        customer({ id: 11, email: 'taken@example.com', phone: '201009999999' }),
      ]);

      await expect(
        service.updateProfile(10, { email: 'taken@example.com' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('lets an account keep its own email', async () => {
      await expect(
        service.updateProfile(10, { email: 'ahmed@example.com' }),
      ).resolves.toMatchObject({ success: true });
    });

    it('rejects an empty update instead of pretending it saved', async () => {
      await expect(service.updateProfile(10, {})).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('cannot change the phone number, role or status', async () => {
      await service.updateProfile(10, { name: 'اسم' });

      expect(users[0].phone).toBe('201001234567');
      expect(users[0].role).toBe(UserRole.CUSTOMER);
      expect(users[0].status).toBe(AccountStatus.ACTIVE);
    });
  });

  describe('area update', () => {
    it('moves the customer to another approved area', async () => {
      const result = await service.updateCustomerZone(10, 2);

      expect(result).toMatchObject({
        success: true,
        customerZone: { id: 2, code: 'biban' },
      });
      expect(users[0].customerZoneId).toBe(2);
    });

    it('rejects an area outside the approved three', async () => {
      await expect(service.updateCustomerZone(10, 99)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('leaves the saved area untouched when the new one is rejected', async () => {
      await expect(service.updateCustomerZone(10, 99)).rejects.toThrow();
      expect(users[0].customerZoneId).toBe(1);
    });

    it('exposes the saved area id to the pricing engine', async () => {
      await expect(service.getCustomerZoneId(10)).resolves.toBe(1);
    });

    it('reports null when no area is saved', async () => {
      service = await build([customer({ customerZoneId: null })]);
      await expect(service.getCustomerZoneId(10)).resolves.toBeNull();
    });
  });

  describe('a closed account stops answering', () => {
    // Closing scrubs the row but keeps it, and the token issued beforehand
    // stays cryptographically valid until it expires. Without this the account
    // would keep serving its own data for the rest of that window.
    beforeEach(async () => {
      service = await build([customer({ deletedAt: new Date() })]);
    });

    it('refuses to return the profile', async () => {
      await expect(service.getProfile(10)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('refuses to return the status', async () => {
      await expect(service.getStatusById(10)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('refuses further edits', async () => {
      await expect(
        service.updateProfile(10, { name: 'محاولة' }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('refuses an area change', async () => {
      await expect(service.updateCustomerZone(10, 2)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });
  });
});
