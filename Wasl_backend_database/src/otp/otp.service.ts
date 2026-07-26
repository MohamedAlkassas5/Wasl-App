import {
  Injectable,
  Inject,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { randomInt } from 'crypto';
import { OtpVerification } from './entities/otp-verification.entity';
import { OtpProvider, OTP_PROVIDER } from './otp-provider.interface';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  // Security constants (kept in code, not the admin-editable business config).
  private static readonly OTP_LENGTH = 6;
  private static readonly TTL_MS = 5 * 60 * 1000; // code valid 5 minutes
  private static readonly MAX_VERIFY_ATTEMPTS = 5; // brute-force cap
  private static readonly RESEND_COOLDOWN_MS = 60 * 1000; // 1 min between sends
  private static readonly SEND_WINDOW_MS = 60 * 60 * 1000; // rolling 1h window
  private static readonly MAX_SENDS_PER_WINDOW = 5; // sends per phone / hour
  // How long a *successful* verification stays usable as proof of phone
  // ownership. Generous enough for a delivery partner to finish uploading
  // documents after verifying, short enough that a stale record is worthless.
  private static readonly VERIFIED_WINDOW_MS = 30 * 60 * 1000;

  constructor(
    @InjectRepository(OtpVerification)
    private readonly otpRepository: Repository<OtpVerification>,
    @Inject(OTP_PROVIDER) private readonly provider: OtpProvider,
  ) {}

  private cleanPhone(phone: string): string {
    return phone.replace(/[^0-9]/g, '');
  }

  private generateCode(): string {
    // Cryptographically-strong numeric code, zero-padded.
    const max = 10 ** OtpService.OTP_LENGTH;
    return randomInt(0, max)
      .toString()
      .padStart(OtpService.OTP_LENGTH, '0');
  }

  /**
   * Generate, hash, persist and deliver a fresh OTP. Enforces a per-phone
   * resend cooldown and an hourly send cap to prevent abuse.
   */
  async sendOtp(rawPhone: string): Promise<{ success: boolean; message: string }> {
    const phone = this.cleanPhone(rawPhone);
    const now = new Date();

    let record = await this.otpRepository.findOne({ where: { phone } });

    // Resend cooldown.
    if (
      record?.lastSentAt &&
      now.getTime() - new Date(record.lastSentAt).getTime() <
        OtpService.RESEND_COOLDOWN_MS
    ) {
      throw new BadRequestException(
        'يرجى الانتظار قليلاً قبل طلب رمز جديد',
      );
    }

    // Rolling send-window cap.
    let sendsInWindow = 1;
    let windowStartedAt = now;
    if (
      record?.windowStartedAt &&
      now.getTime() - new Date(record.windowStartedAt).getTime() <
        OtpService.SEND_WINDOW_MS
    ) {
      sendsInWindow = record.sendsInWindow + 1;
      windowStartedAt = record.windowStartedAt;
      if (sendsInWindow > OtpService.MAX_SENDS_PER_WINDOW) {
        throw new BadRequestException(
          'تجاوزت عدد المحاولات المسموح بها، حاول بعد ساعة',
        );
      }
    }

    const code = this.generateCode();
    const otpHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(now.getTime() + OtpService.TTL_MS);

    if (!record) {
      record = this.otpRepository.create({ phone });
    }
    record.otpHash = otpHash;
    record.expiresAt = expiresAt;
    record.attempts = 0;
    record.verified = false;
    record.verifiedAt = null;
    record.lastSentAt = now;
    record.sendsInWindow = sendsInWindow;
    record.windowStartedAt = windowStartedAt;
    await this.otpRepository.save(record);

    // Delivery is delegated to the provider abstraction.
    await this.provider.sendOtp(phone, code);

    this.logger.log(`🔐 OTP issued for ${phone} via ${this.provider.name}`);
    return { success: true, message: 'تم إرسال رمز التحقق عبر واتساب' };
  }

  /**
   * Verify a submitted code against the stored hash. Increments the attempt
   * counter and locks out after MAX_VERIFY_ATTEMPTS. Returns true on success.
   */
  async verifyOtp(rawPhone: string, code: string): Promise<boolean> {
    const phone = this.cleanPhone(rawPhone);
    const record = await this.otpRepository.findOne({ where: { phone } });

    if (!record) {
      throw new BadRequestException('لم يتم طلب رمز تحقق لهذا الرقم');
    }
    if (record.verified) {
      // Already verified — idempotent so a client can re-submit the same code
      // (e.g. a retried request) without being locked out. Still bounded by the
      // verification window, so a long-stale record is not a free pass.
      if (this.isWithinVerifiedWindow(record)) {
        return true;
      }
      throw new BadRequestException('انتهت صلاحية الرمز، اطلب رمزاً جديداً');
    }
    if (new Date() > new Date(record.expiresAt)) {
      throw new BadRequestException('انتهت صلاحية الرمز، اطلب رمزاً جديداً');
    }
    if (record.attempts >= OtpService.MAX_VERIFY_ATTEMPTS) {
      throw new BadRequestException(
        'تم تجاوز عدد المحاولات، اطلب رمزاً جديداً',
      );
    }

    const matches = await bcrypt.compare(code, record.otpHash);
    if (!matches) {
      record.attempts += 1;
      await this.otpRepository.save(record);
      return false;
    }

    record.verified = true;
    record.verifiedAt = new Date();
    await this.otpRepository.save(record);
    return true;
  }

  private isWithinVerifiedWindow(record: OtpVerification): boolean {
    if (!record.verified || !record.verifiedAt) return false;
    return (
      Date.now() - new Date(record.verifiedAt).getTime() <
      OtpService.VERIFIED_WINDOW_MS
    );
  }

  /**
   * Whether a phone currently holds a fresh, successfully-verified OTP.
   * This is the gate that registration and password reset stand behind — it is
   * the only server-side proof that the caller controls the number.
   */
  async isPhoneVerified(rawPhone: string): Promise<boolean> {
    const phone = this.cleanPhone(rawPhone);
    const record = await this.otpRepository.findOne({ where: { phone } });
    return !!record && this.isWithinVerifiedWindow(record);
  }

  /**
   * Burn the verification once it has been spent (account created, password
   * reset). Without this a single verified code could be replayed for the whole
   * 30-minute window.
   */
  async consumeVerification(rawPhone: string): Promise<void> {
    const phone = this.cleanPhone(rawPhone);
    await this.otpRepository.delete({ phone });
  }
}
