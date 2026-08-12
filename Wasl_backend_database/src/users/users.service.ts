import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { ZonesService } from '../zones/zones.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly zones: ZonesService,
  ) {}

  /**
   * The caller's own live account, or a refusal.
   *
   * Closing an account scrubs it but keeps the row, and the token issued
   * before that stays cryptographically valid until it expires. Without this
   * check a just-deleted user could keep reading their profile for the rest of
   * the token's lifetime.
   */
  private async getLiveUser(userId: number): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: { customerZone: true },
    });

    if (!user) {
      throw new NotFoundException('المستخدم غير موجود');
    }
    if (user.deletedAt) {
      throw new ForbiddenException('تم حذف هذا الحساب');
    }
    return user;
  }

  /** Status of the caller's own account, keyed on the id carried by the JWT. */
  async getStatusById(userId: number) {
    const user = await this.getLiveUser(userId);

    return {
      success: true,
      status: user.status,
      role: user.role,
      adminNotes: user.admin_notes || '',
      name: user.name,
      id: user.id,
    };
  }

  /**
   * The caller's own profile, including their delivery area.
   *
   * Only ever resolves the id from the token — there is no lookup-by-phone
   * variant on purpose, since that is what previously let anyone enumerate the
   * user base.
   */
  async getProfile(userId: number) {
    return this.toProfile(await this.getLiveUser(userId));
  }

  /**
   * Update the caller's own name and/or email.
   *
   * Phone is not editable here (it is the login identifier, changed only
   * through OTP), and neither is role or status — a client that sends them is
   * rejected by the DTO whitelist rather than silently ignored.
   */
  async updateProfile(userId: number, dto: UpdateProfileDto) {
    if (dto.name === undefined && dto.email === undefined) {
      throw new BadRequestException('لا يوجد أي تعديل لحفظه');
    }

    const user = await this.getLiveUser(userId);

    if (dto.name !== undefined) {
      user.name = dto.name;
    }

    if (dto.email !== undefined) {
      // '' means "remove my address"; the column is unique, and several rows
      // holding '' would collide, so it is stored as NULL.
      const email = dto.email === '' ? null : dto.email.toLowerCase();

      if (email) {
        const taken = await this.userRepository.findOne({
          where: { email, id: Not(userId) },
          select: { id: true },
        });
        if (taken) {
          throw new BadRequestException(
            'هذا البريد الإلكتروني مستخدم بحساب آخر',
          );
        }
      }
      user.email = email;
    }

    await this.userRepository.save(user);

    return {
      success: true,
      message: 'تم حفظ بياناتك بنجاح',
      user: this.toProfile(user),
    };
  }

  /**
   * Move the caller to a different approved area.
   *
   * Validation lives in ZonesService so registration, profile update and order
   * creation all reject an unsupported area the same way.
   */
  async updateCustomerZone(userId: number, zoneId: number) {
    const user = await this.getLiveUser(userId);

    const zone = await this.zones.getActiveZone(zoneId);
    user.customerZoneId = zone.id;
    user.customerZone = zone;
    await this.userRepository.save(user);

    return {
      success: true,
      message: `تم تحديث منطقتك إلى ${zone.name}`,
      customerZone: { id: zone.id, code: zone.code, name: zone.name },
    };
  }

  /** The saved area id, or null. Used by pricing to default the destination. */
  async getCustomerZoneId(userId: number): Promise<number | null> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: { id: true, customerZoneId: true },
    });
    return user?.customerZoneId ?? null;
  }

  /** One shape for the profile, so every endpoint returns the same thing. */
  private toProfile(user: User) {
    return {
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email || '',
      role: user.role,
      status: user.status,
      customerZone: user.customerZone
        ? {
            id: user.customerZone.id,
            code: user.customerZone.code,
            name: user.customerZone.name,
            city: user.customerZone.city,
          }
        : null,
    };
  }
}
