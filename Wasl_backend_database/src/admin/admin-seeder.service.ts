import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { User, UserRole, AccountStatus } from '../users/entities/user.entity';

/**
 * Ensures a platform admin account exists on boot so the web panel can log in.
 * Credentials come from the environment (ADMIN_PHONE / ADMIN_PASSWORD) with
 * safe local defaults. The password is only set on first creation — changing
 * it later is done through normal account management, not by editing env.
 */
@Injectable()
export class AdminSeederService implements OnModuleInit {
  private readonly logger = new Logger(AdminSeederService.name);

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    const phone = (
      this.config.get<string>('ADMIN_PHONE') || '01000000000'
    ).replace(/[^0-9]/g, '');
    const password =
      this.config.get<string>('ADMIN_PASSWORD') || 'WaslAdmin@2026';

    const existing = await this.userRepository.findOne({ where: { phone } });
    if (existing) {
      // Make sure the account is a usable admin even if it pre-existed.
      if (existing.role !== UserRole.ADMIN) {
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
    this.logger.log(
      `👑 Admin account ready (phone ${phone}). Change the default password after first login.`,
    );
  }
}
