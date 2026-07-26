import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { User, UserRole, AccountStatus } from '../users/entities/user.entity';

/**
 * Ensures a platform admin account exists on boot so the web panel can log in.
 *
 * Credentials come from ADMIN_PHONE / ADMIN_PASSWORD and there are **no
 * defaults**. This used to fall back to `01000000000` / `WaslAdmin@2026` —
 * values that were also printed on the admin panel's own login page and
 * committed to the repo, so any deployment that forgot to set the env vars had
 * a publicly-known admin login. Admin can approve partners and read every
 * uploaded national ID, so a guessable admin is the worst credential on the
 * platform to leave lying around.
 *
 * The password is only ever set when the account is first created; rotating it
 * later is done through account management, not by editing env.
 */
@Injectable()
export class AdminSeederService implements OnModuleInit {
  private readonly logger = new Logger(AdminSeederService.name);

  /** Leaked in git history and on the old login page — refuse it outright. */
  private static readonly BURNED_PASSWORDS = ['WaslAdmin@2026'];
  private static readonly MIN_PASSWORD_LENGTH = 12;

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    const rawPhone = this.config.get<string>('ADMIN_PHONE')?.trim();
    const password = this.config.get<string>('ADMIN_PASSWORD');
    const phone = rawPhone?.replace(/[^0-9]/g, '');

    if (!phone || !password) {
      // An admin that already exists is this service's whole goal, so a
      // configured deployment that has one stays up. What we will not do is
      // invent an account we have no credentials for.
      await this.assertAnAdminExists();
      return;
    }

    this.assertPasswordIsUsable(password);
    await this.rotateBurnedAdminPasswords(password);

    const existing = await this.userRepository.findOne({ where: { phone } });
    if (existing) {
      if (existing.role !== UserRole.ADMIN) {
        // The operator pointed ADMIN_PHONE at a number that already belongs to
        // someone. That is presumably deliberate, but it hands that person
        // every partner's documents — so say so loudly rather than silently.
        this.logger.warn(
          `⚠️ Promoting the existing account on ${phone} to ADMIN because ADMIN_PHONE points at it. If that number belongs to a customer, this grants them full admin access.`,
        );
        existing.role = UserRole.ADMIN;
        existing.status = AccountStatus.ACTIVE;
        await this.userRepository.save(existing);
      }
      return;
    }

    const admin = this.userRepository.create({
      name: 'Wasl Admin',
      phone,
      passwordHash: await bcrypt.hash(password, 10),
      role: UserRole.ADMIN,
      status: AccountStatus.ACTIVE,
    });
    await this.userRepository.save(admin);
    this.logger.log(`👑 Admin account created for ${phone}.`);
  }

  private assertPasswordIsUsable(password: string): void {
    if (AdminSeederService.BURNED_PASSWORDS.includes(password)) {
      throw new Error(
        'ADMIN_PASSWORD is set to the old default, which is public in this repository’s history and was displayed on the admin login page. Choose a new password.',
      );
    }
    if (password.length < AdminSeederService.MIN_PASSWORD_LENGTH) {
      throw new Error(
        `ADMIN_PASSWORD must be at least ${AdminSeederService.MIN_PASSWORD_LENGTH} characters — this account can read every uploaded identity document.`,
      );
    }
  }

  /**
   * Removing the fallback stops *new* deployments getting a known password, but
   * it does nothing for one that already booted with the old default and still
   * has that account. So on every boot, any admin still holding a burned
   * password is re-hashed to the configured one.
   *
   * This is the one case where the password is written outside account
   * creation: the alternative is leaving a publicly-known credential on an
   * account that can read every uploaded identity document, and the panel it
   * logs into is where that rotation would otherwise have to happen.
   */
  private async rotateBurnedAdminPasswords(newPassword: string): Promise<void> {
    const admins = await this.userRepository.find({
      where: { role: UserRole.ADMIN },
    });

    for (const admin of admins) {
      const isBurned = await this.matchesBurnedPassword(admin.passwordHash);
      if (!isBurned) continue;

      admin.passwordHash = await bcrypt.hash(newPassword, 10);
      await this.userRepository.save(admin);
      this.logger.warn(
        `🔑 Admin ${admin.phone} was still using the leaked default password; rotated it to the configured ADMIN_PASSWORD.`,
      );
    }
  }

  private async matchesBurnedPassword(passwordHash: string): Promise<boolean> {
    for (const burned of AdminSeederService.BURNED_PASSWORDS) {
      if (await bcrypt.compare(burned, passwordHash)) return true;
    }
    return false;
  }

  /**
   * Nothing to seed with. Boot only if the platform already has an admin;
   * otherwise refuse, because the alternative is a silently unmanageable
   * deployment (or, as before, a default-credential one).
   */
  private async assertAnAdminExists(): Promise<void> {
    const admins = await this.userRepository.find({
      where: { role: UserRole.ADMIN },
    });

    if (admins.length === 0) {
      throw new Error(
        'No admin account exists and ADMIN_PHONE / ADMIN_PASSWORD are not set. Set both and restart — the seeder no longer falls back to built-in credentials.',
      );
    }

    // Can't rotate without a replacement password, so refuse to run rather
    // than serve a platform whose admin login is public knowledge.
    for (const admin of admins) {
      if (await this.matchesBurnedPassword(admin.passwordHash)) {
        throw new Error(
          `Admin ${admin.phone} is still using the leaked default password. Set ADMIN_PASSWORD (12+ characters) and restart — the seeder will rotate it on boot.`,
        );
      }
    }

    this.logger.warn(
      '⚠️ ADMIN_PHONE / ADMIN_PASSWORD are not set; skipping admin seeding because an admin already exists.',
    );
  }
}
