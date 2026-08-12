import {
  Injectable,
  Inject,
  forwardRef,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { OtpService } from '../otp/otp.service';
import { User, UserRole, AccountStatus } from '../users/entities/user.entity';
import {
  DeliveryPartner,
  VehicleType,
} from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { InAppNotification } from '../orders/entities/notification.entity';
import { OtpVerification } from '../otp/entities/otp-verification.entity';
import { RegisterDto } from './register.dto';
import { LoginDto } from './login.dto';
import { ZonesService } from '../zones/zones.service';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,
    @InjectRepository(Merchant)
    private readonly merchantRepository: Repository<Merchant>,
    private readonly jwtService: JwtService,
    // forwardRef: OtpController needs AuthService to issue a session after a
    // code checks out, and AuthService needs OtpService to refuse a
    // registration whose phone was never verified. Genuinely mutual.
    @Inject(forwardRef(() => OtpService))
    private readonly otpService: OtpService,
    private readonly zonesService: ZonesService,
  ) {}

  // 🎯 1️⃣ دالة تسجيل الحسابات الشاملة (تستقبل طلب الـ Multipart المباشر من الفلاتر)
  async register(
    registerDto: RegisterDto,
    idFront?: string,
    idBack?: string,
    storeLogo?: string,
    vehicleImage?: string,
  ) {
    const {
      name,
      phone,
      password,
      role,
      storeName,
      storeType,
      vehicleType,
      email,
      firebaseUid,
      customerZoneId,
    } = registerDto;

    const cleanPhone = phone.replace(/[^0-9]/g, '');

    // 🔐 The phone must have passed a server-side OTP challenge first. Without
    // this the OTP screen is decorative — anyone could POST straight to
    // /auth/register with someone else's number and own that identity.
    const phoneVerified = await this.otpService.isPhoneVerified(cleanPhone);
    if (!phoneVerified) {
      throw new BadRequestException(
        'يجب التحقق من رقم الهاتف عبر رمز واتساب قبل إنشاء الحساب',
      );
    }

    const existingUser = await this.userRepository.findOne({
      where: { phone: cleanPhone },
    });
    if (existingUser) {
      throw new BadRequestException('رقم الهاتف مستخدم بالفعل بالمنظومة');
    }

    // 📍 A supplied area is only meaningful for a customer, and is checked
    // against the live zone list before anything is written — an unsupported
    // area fails registration outright rather than creating an account that
    // can never be quoted a delivery.
    let resolvedZoneId: number | undefined;
    if (customerZoneId !== undefined && role === UserRole.CUSTOMER) {
      const zone = await this.zonesService.getActiveZone(customerZoneId);
      resolvedZoneId = zone.id;
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const status =
      role === UserRole.DELIVERY || role === UserRole.MERCHANT
        ? AccountStatus.PENDING
        : AccountStatus.ACTIVE;

    const user = this.userRepository.create({
      name: name.trim(),
      phone: cleanPhone,
      passwordHash,
      role,
      status,
      email: email ? email.trim() : undefined,
      firebaseUid,
      customerZoneId: resolvedZoneId,
    });
    const savedUser = await this.userRepository.save(user);

    if (role === UserRole.DELIVERY) {
      const deliveryRecord = this.deliveryRepository.create({
        userId: savedUser.id,
        nationalIdFront: idFront || 'pending_front.jpg',
        nationalIdBack: idBack || 'pending_back.jpg',
        selfie: 'pending_selfie.jpg',
        vehicleImage: vehicleImage || 'pending_vehicle.jpg',
        vehicleType: (vehicleType as VehicleType) || VehicleType.MOTORCYCLE,
      });
      await this.deliveryRepository.save(deliveryRecord);
    } else if (role === UserRole.MERCHANT) {
      const merchantRecord = this.merchantRepository.create({
        ownerId: savedUser.id,
        storeName: storeName ? storeName.trim() : `${name.trim()} Store`,
        storeType: storeType || 'مطاعم',
        logo: storeLogo || 'pending_logo.jpg',
      });
      await this.merchantRepository.save(merchantRecord);
    }

    // The verification has now been spent — burn it so the same code can't be
    // replayed for anything else inside its window.
    await this.otpService.consumeVerification(cleanPhone);

    const token = this.generateToken(savedUser);
    return {
      message: 'تم التحقق من رقم الهاتف وإنشاء الحساب في النظام بنجاح 🎉',
      token,
      user: {
        id: savedUser.id,
        name: savedUser.name,
        phone: savedUser.phone,
        role: savedUser.role,
        status: savedUser.status,
        email: savedUser.email || '',
        firebaseUid: savedUser.firebaseUid || '',
        adminNotes: savedUser.admin_notes || '',
        customerZoneId: savedUser.customerZoneId ?? null,
      },
    };
  }

  // 🎯 2️⃣ دالة تسجيل الدخول المباشر الموثق
  async login(loginDto: LoginDto) {
    const { phone, password } = loginDto;
    const cleanPhone = phone.replace(/[^0-9]/g, '');

    const user = await this.userRepository.findOne({
      where: { phone: cleanPhone },
    });

    if (!user) {
      throw new UnauthorizedException('رقم الهاتف أو كلمة المرور غير صحيحة');
    }

    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      throw new UnauthorizedException('رقم الهاتف أو كلمة المرور غير صحيحة');
    }

    if (user.status === AccountStatus.SUSPENDED) {
      throw new BadRequestException(
        'عفواً، الحساب محظور حالياً، يرجى مراجعة الإدارة',
      );
    }

    const token = this.generateToken(user);

    return {
      message: 'تم تسجيل الدخول بنجاح 🚀',
      token,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        status: user.status,
        email: user.email || '',
        firebaseUid: user.firebaseUid || '',
        adminNotes: user.admin_notes || '',
        customerZoneId: user.customerZoneId ?? null,
      },
    };
  }

  // 🗑️ Removed with the social-check route: `findOneByEmailOrUid` +
  // `generateJwtToken` existed only to mint a session from an unverified email
  // address. See the comment on AuthController.socialCheck before reviving them.

  // 🎯 دالة حذف الحساب بكل متعلقاته اللوجستية من السيرفر
  //
  // Deletion is keyed on the **id from the verified JWT**, never on a phone
  // number taken from the URL. The old suffix match (`LIKE '%1234567 89'`) could
  // also resolve to a different account whose number merely ended the same way.
  async deleteAccountById(
    userId: number,
  ): Promise<{ success: boolean; message: string }> {
    const user = await this.userRepository.findOne({ where: { id: userId } });

    if (!user) {
      throw new NotFoundException('عفواً، الحساب غير موجود في المنظومة');
    }

    return this.deleteUserRecord(user);
  }

  /** Admin-only lookup path: exact phone match, no fuzzy suffix matching. */
  async deleteAccountByPhone(
    phone: string,
  ): Promise<{ success: boolean; message: string }> {
    const cleanPhone = phone.replace(/[^0-9]/g, '');

    const user = await this.userRepository.findOne({
      where: { phone: cleanPhone },
    });

    if (!user) {
      throw new NotFoundException('عفواً، الحساب غير موجود في المنظومة');
    }

    return this.deleteUserRecord(user);
  }

  /**
   * Closes an account.
   *
   * This used to be `userRepository.delete()`, which **could not succeed** for
   * any customer who had ever placed an order: `orders.customerId` is
   * `ON DELETE NO ACTION`, so Postgres raised a foreign-key violation and the
   * app showed "فشلت عملية حذف الحساب". Verified against a real database.
   *
   * Cascading the delete down through orders would have worked mechanically and
   * been wrong: an order carries the assigned driver's delivery record and the
   * commission charged against their wallet. Erasing it destroys a *different*
   * person's financial history to satisfy this one's deletion request.
   *
   * So the row survives and everything personal on it is scrubbed:
   *
   *  - name / email / firebase uid cleared, password replaced with a value no
   *    input can hash to, so the account can never be signed into again;
   *  - phone rewritten to a unique placeholder, which **releases the real
   *    number** for a fresh signup;
   *  - notifications (purely personal, no financial meaning) deleted, along
   *    with any outstanding OTP for the number;
   *  - driver/merchant profiles deleted as before — those cascade cleanly and
   *    hold identity documents that must not be retained;
   *  - orders, offers and wallet ledger rows deliberately kept.
   *
   * Everything runs in one transaction, so a partial scrub can't leave an
   * account half-closed and still reachable.
   */
  private async deleteUserRecord(
    user: User,
  ): Promise<{ success: boolean; message: string }> {
    await this.userRepository.manager.transaction(async (manager) => {
      if (user.role === UserRole.DELIVERY) {
        await manager.delete(DeliveryPartner, { userId: user.id });
      } else if (user.role === UserRole.MERCHANT) {
        await manager.delete(Merchant, { ownerId: user.id });
      }

      await manager.delete(InAppNotification, { userId: user.id });
      await manager.delete(OtpVerification, { phone: user.phone });

      // Unique, obviously-not-a-number, and short enough for varchar(20).
      const releasedPhone =
        `deleted_${user.id}_${Date.now().toString(36)}`.slice(0, 20);

      await manager.update(
        User,
        { id: user.id },
        {
          name: 'حساب محذوف',
          phone: releasedPhone,
          // bcrypt never produces this, so no password can ever match it.
          passwordHash: 'account-deleted',
          email: null,
          firebaseUid: null,
          customerZoneId: null,
          status: AccountStatus.SUSPENDED,
          deletedAt: new Date(),
        },
      );
    });

    return {
      success: true,
      message:
        'تم حذف حسابك وبياناتك الشخصية نهائياً، ورقم هاتفك بقى متاح للتسجيل من جديد.',
    };
  }

  /**
   * Issue a session for a phone that has already passed OTP verification
   * (WhatsApp OTP flow). Returns null when no account exists yet, so the
   * caller can route the user to registration. No password is involved —
   * identity is proven by the verified OTP, keeping auth decoupled from
   * Firebase.
   */
  async loginWithVerifiedPhone(phone: string) {
    const cleanPhone = phone.replace(/[^0-9]/g, '');
    const user = await this.userRepository.findOne({
      where: { phone: cleanPhone },
    });
    if (!user) return null;

    if (user.status === AccountStatus.SUSPENDED) {
      throw new BadRequestException(
        'عفواً، الحساب محظور حالياً، يرجى مراجعة الإدارة',
      );
    }

    return {
      token: this.generateToken(user),
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        status: user.status,
        email: user.email || '',
        firebaseUid: user.firebaseUid || '',
        adminNotes: user.admin_notes || '',
        customerZoneId: user.customerZoneId ?? null,
      },
    };
  }

  /**
   * Set a new password for a phone whose ownership was just proven by OTP.
   * Called only from OtpController *after* the code has been checked, which is
   * why no current password is required — possession of the WhatsApp code is
   * the credential here.
   *
   * A non-existent phone is not reported as such: the caller gets the same
   * generic failure either way, so this can't be used to test which numbers
   * have accounts.
   */
  async resetPasswordWithVerifiedPhone(phone: string, newPassword: string) {
    const cleanPhone = phone.replace(/[^0-9]/g, '');
    const user = await this.userRepository.findOne({
      where: { phone: cleanPhone },
    });

    if (user) {
      user.passwordHash = await bcrypt.hash(newPassword, 10);
      await this.userRepository.save(user);
    }

    return {
      success: true,
      message: 'تم تحديث كلمة المرور بنجاح، يمكنك تسجيل الدخول الآن',
    };
  }

  private generateToken(user: User): string {
    return this.jwtService.sign({ sub: user.id, role: user.role });
  }
}
