import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { Repository } from 'typeorm';

import { AccountStatus, User, UserRole } from '../users/entities/user.entity';

/** Creates the first administrator only from explicitly supplied credentials. */
@Injectable()
export class AdminSeederService implements OnModuleInit {
  private static readonly minPasswordLength = 12;
  private static readonly burnedPasswords = [
    'WaslAdmin@2026',
    'WasalAdmin@147',
  ];
  private readonly logger = new Logger(AdminSeederService.name);

  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    const phone = this.config
      .get<string>('ADMIN_PHONE')
      ?.replace(/[^0-9]/g, '');
    const password = this.config.get<string>('ADMIN_PASSWORD');

    if (!phone || !password) {
      await this.assertSafeAdminExists();
      return;
    }

    if (AdminSeederService.burnedPasswords.includes(password)) {
      throw new Error(
        'ADMIN_PASSWORD is set to an old default password that was exposed in repository history.',
      );
    }
    if (password.length < AdminSeederService.minPasswordLength) {
      throw new Error(
        `ADMIN_PASSWORD must be at least ${AdminSeederService.minPasswordLength} characters.`,
      );
    }

    await this.rotateBurnedPasswords(password);
    const user = await this.users.findOne({ where: { phone } });
    if (user) {
      if (user.role !== UserRole.ADMIN) {
        throw new Error(
          'ADMIN_PHONE belongs to a non-administrator. Promote it explicitly through the administration workflow instead.',
        );
      }
      return;
    }

    await this.users.save(
      this.users.create({
        name: 'Wasl Admin',
        phone,
        passwordHash: await bcrypt.hash(password, 12),
        role: UserRole.ADMIN,
        status: AccountStatus.ACTIVE,
      }),
    );
    this.logger.log(`Administrator provisioned for ${phone}.`);
  }

  private async rotateBurnedPasswords(password: string): Promise<void> {
    const admins = await this.users.find({ where: { role: UserRole.ADMIN } });
    for (const admin of admins) {
      if (!(await this.matchesBurnedPassword(admin.passwordHash))) continue;
      admin.passwordHash = await bcrypt.hash(password, 12);
      await this.users.save(admin);
      this.logger.warn(
        `Rotated exposed password for administrator ${admin.id}.`,
      );
    }
  }

  private async assertSafeAdminExists(): Promise<void> {
    const admins = await this.users.find({ where: { role: UserRole.ADMIN } });
    if (admins.length === 0) {
      throw new Error(
        'No administrator exists and ADMIN_PHONE / ADMIN_PASSWORD are not set.',
      );
    }
    for (const admin of admins) {
      if (await this.matchesBurnedPassword(admin.passwordHash)) {
        throw new Error(
          'An administrator still uses a leaked default password. Set ADMIN_PASSWORD and restart to rotate it.',
        );
      }
    }
    this.logger.warn(
      'ADMIN_PHONE and ADMIN_PASSWORD are unset; using an already provisioned administrator.',
    );
  }

  private async matchesBurnedPassword(hash: string): Promise<boolean> {
    for (const password of AdminSeederService.burnedPasswords) {
      if (await bcrypt.compare(password, hash)) return true;
    }
    return false;
  }
}
