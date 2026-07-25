import { Controller, Post, Body, BadRequestException } from '@nestjs/common';
import { OtpService } from './otp.service';
import { AuthService } from '../auth/auth.service';
import { SendOtpDto, VerifyOtpDto } from './dto/otp.dto';

/**
 * WhatsApp OTP endpoints. This is the production-ready, provider-agnostic
 * replacement for client-side Firebase phone auth. Verification happens on the
 * server; a JWT is issued only after a code is proven correct.
 */
@Controller('auth/otp')
export class OtpController {
  constructor(
    private readonly otpService: OtpService,
    private readonly authService: AuthService,
  ) {}

  @Post('send')
  send(@Body() dto: SendOtpDto) {
    return this.otpService.sendOtp(dto.phone);
  }

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
}
