import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { OtpVerification } from './entities/otp-verification.entity';
import { OtpService } from './otp.service';
import { OtpController } from './otp.controller';
import { OTP_PROVIDER } from './otp-provider.interface';
import { MetaWhatsAppProvider } from './providers/meta-whatsapp.provider';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([OtpVerification]),
    HttpModule,
    // AuthService gates registration on a verified phone, OtpController issues
    // the session — the two modules need each other.
    forwardRef(() => AuthModule),
  ],
  controllers: [OtpController],
  providers: [
    OtpService,
    // 🔌 Swap this binding to change WhatsApp provider (Twilio, etc.) with no
    // changes to OtpService — it depends only on the OtpProvider interface.
    { provide: OTP_PROVIDER, useClass: MetaWhatsAppProvider },
  ],
  exports: [OtpService],
})
export class OtpModule {}
