import {
  Controller,
  Post,
  Body,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { OtpService } from './otp.service';
import { AuthService } from '../auth/auth.service';
import { SendOtpDto, VerifyOtpDto, ResetPasswordDto } from './dto/otp.dto';

/**
 * WhatsApp OTP endpoints. This is the production-ready, provider-agnostic
 * replacement for client-side Firebase phone auth. Verification happens on the
 * server; a JWT is issued only after a code is proven correct.
 */
@Controller('auth/otp')
export class OtpController {
  constructor(
    private readonly otpService: OtpService,
    @Inject(forwardRef(() => AuthService))
    private readonly authService: AuthService,
  ) {}

  /**
   * OtpService already caps sends per *phone*. This caps them per *IP* as well,
   * so an attacker can't rotate through phone numbers to burn our WhatsApp
   * quota or spam strangers: 5 sends per 10 minutes from one address.
   */
  @Throttle({ default: { limit: 5, ttl: 600_000 } })
  @Post('send')
  send(@Body() dto: SendOtpDto) {
    return this.otpService.sendOtp(dto.phone);
  }

  // Per-phone attempts are capped at 5; this stops an IP from spraying codes
  // across many phone numbers at once.
  @Throttle({ default: { limit: 15, ttl: 600_000 } })
  @Post('verify')
  async verify(@Body() dto: VerifyOtpDto) {
    const ok = await this.otpService.verifyOtp(dto.phone, dto.code);
    if (!ok) {
      throw new BadRequestException('رمز التحقق غير صحيح');
    }

    // If an account already exists for this phone, hand back a session token.
    // Otherwise the client proceeds to registration with a verified phone.
    const session = await this.authService.loginWithVerifiedPhone(dto.phone);
    if (session) {
      return { verified: true, registered: true, ...session };
    }
    return { verified: true, registered: false };
  }

  /**
   * Forgot-password completion: proves the code again, then sets the new
   * password and burns the verification so it can't be replayed.
   */
  @Throttle({ default: { limit: 10, ttl: 600_000 } })
  @Post('reset-password')
  async resetPassword(@Body() dto: ResetPasswordDto) {
    const ok = await this.otpService.verifyOtp(dto.phone, dto.code);
    if (!ok) {
      throw new BadRequestException('رمز التحقق غير صحيح');
    }

    const result = await this.authService.resetPasswordWithVerifiedPhone(
      dto.phone,
      dto.newPassword,
    );
    await this.otpService.consumeVerification(dto.phone);
    return result;
  }
}
