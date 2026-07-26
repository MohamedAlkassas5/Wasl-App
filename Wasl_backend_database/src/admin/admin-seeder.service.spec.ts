import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';

import { AdminSeederService } from './admin-seeder.service';
import { User, UserRole, AccountStatus } from '../users/entities/user.entity';

/**
 * The seeder used to fall back to `01000000000` / `WaslAdmin@2026` when the
 * env vars were missing — credentials that were simultaneously printed on the
 * admin panel's login page. Admin can approve partners and read every uploaded
 * national ID, so these tests pin that no built-in credential can come back.
 */
describe('AdminSeederService (no default credentials)', () => {
  const PHONE = '201009998877';
  const STRONG_PASSWORD = 'a-long-enough-admin-secret';

  let users: User[];
  let env: Record<string, string | undefined>;

  const userRepository = {
    findOne: ({ where }: { where: { phone?: string; role?: UserRole } }) =>
      Promise.resolve(
        users.find(
          (u) =>
            (where.phone !== undefined && u.phone === where.phone) ||
            (where.role !== undefined && u.role === where.role),
        ) ?? null,
      ),
    find: ({ where }: { where: { role?: UserRole } }) =>
      Promise.resolve(users.filter((u) => u.role === where.role)),
    create: (data: Partial<User>) => ({ id: users.length + 1, ...data }) as User,
    save: (user: User) => {
      if (!users.some((u) => u.id === user.id)) users.push(user);
      return Promise.resolve(user);
    },
  };

  const build = async (): Promise<AdminSeederService> => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        AdminSeederService,
        { provide: getRepositoryToken(User), useValue: userRepository },
        { provide: ConfigService, useValue: { get: (k: string) => env[k] } },
      ],
    }).compile();
    return moduleRef.get(AdminSeederService);
  };

  const existingAdmin = (): User =>
    ({
      id: 1,
      name: 'Wasl Admin',
      phone: '201000000001',
      passwordHash: 'hashed',
      role: UserRole.ADMIN,
      status: AccountStatus.ACTIVE,
    }) as User;

  beforeEach(() => {
    users = [];
    env = {};
  });

  it('refuses to boot when nothing is configured and no admin exists', async () => {
    const seeder = await build();

    await expect(seeder.onModuleInit()).rejects.toThrow(
      /ADMIN_PHONE \/ ADMIN_PASSWORD are not set/,
    );
    expect(users).toHaveLength(0);
  });

  it('never creates the old built-in account as a fallback', async () => {
    const seeder = await build();

    await seeder.onModuleInit().catch(() => undefined);

    expect(users.find((u) => u.phone === '01000000000')).toBeUndefined();
  });

  it('stays up when unconfigured but an admin already exists', async () => {
    users.push(existingAdmin());
    const seeder = await build();

    await expect(seeder.onModuleInit()).resolves.toBeUndefined();
    expect(users).toHaveLength(1);
  });

  it('rejects the password that leaked into git history', async () => {
    env = { ADMIN_PHONE: PHONE, ADMIN_PASSWORD: 'WaslAdmin@2026' };
    const seeder = await build();

    await expect(seeder.onModuleInit()).rejects.toThrow(/old default/);
    expect(users).toHaveLength(0);
  });

  it('rejects a short admin password', async () => {
    env = { ADMIN_PHONE: PHONE, ADMIN_PASSWORD: 'short1!' };
    const seeder = await build();

    await expect(seeder.onModuleInit()).rejects.toThrow(/at least 12/);
    expect(users).toHaveLength(0);
  });

  it('creates the admin from the environment when properly configured', async () => {
    env = { ADMIN_PHONE: PHONE, ADMIN_PASSWORD: STRONG_PASSWORD };
    const seeder = await build();

    await seeder.onModuleInit();

    expect(users).toHaveLength(1);
    expect(users[0].role).toBe(UserRole.ADMIN);
    // Stored hashed, never in the clear.
    expect(users[0].passwordHash).not.toBe(STRONG_PASSWORD);
    await expect(
      bcrypt.compare(STRONG_PASSWORD, users[0].passwordHash),
    ).resolves.toBe(true);
  });

  it('does not re-hash or reset the password of an admin that already exists', async () => {
    users.push({ ...existingAdmin(), phone: PHONE });
    env = { ADMIN_PHONE: PHONE, ADMIN_PASSWORD: STRONG_PASSWORD };
    const seeder = await build();

    await seeder.onModuleInit();

    expect(users[0].passwordHash).toBe('hashed');
  });

  /**
   * Dropping the fallback only protects deployments that have not booted yet.
   * These cover the one that already did — where the leaked account is live.
   */
  describe('an existing admin still holding the leaked password', () => {
    const seedBurnedAdmin = async () => {
      users.push({
        ...existingAdmin(),
        phone: PHONE,
        passwordHash: await bcrypt.hash('WaslAdmin@2026', 10),
      } as User);
    };

    it('rotates it to the configured password on boot', async () => {
      await seedBurnedAdmin();
      env = { ADMIN_PHONE: PHONE, ADMIN_PASSWORD: STRONG_PASSWORD };
      const seeder = await build();

      await seeder.onModuleInit();

      await expect(
        bcrypt.compare('WaslAdmin@2026', users[0].passwordHash),
      ).resolves.toBe(false);
      await expect(
        bcrypt.compare(STRONG_PASSWORD, users[0].passwordHash),
      ).resolves.toBe(true);
    });

    it('rotates it even when ADMIN_PHONE points at a different account', async () => {
      await seedBurnedAdmin();
      env = { ADMIN_PHONE: '201005554443', ADMIN_PASSWORD: STRONG_PASSWORD };
      const seeder = await build();

      await seeder.onModuleInit();

      await expect(
        bcrypt.compare('WaslAdmin@2026', users[0].passwordHash),
      ).resolves.toBe(false);
    });

    it('refuses to boot when there is no replacement password to rotate to', async () => {
      await seedBurnedAdmin();
      const seeder = await build();

      await expect(seeder.onModuleInit()).rejects.toThrow(
        /leaked default password/,
      );
    });
  });
});
