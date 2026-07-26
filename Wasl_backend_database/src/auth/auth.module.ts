import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { HttpModule } from '@nestjs/axios'; // 🎯 1. استيراد موديول الـ HTTP الخاص بـ Axios لحل الأزمة
import { JWT_SECRET, JWT_EXPIRES_IN } from './jwt.constants';
import { OtpModule } from '../otp/otp.module';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { User } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';

@Module({
  imports: [
    // 🎯 حقن الكيانات الثلاثة معاً لكي يراهم الـ AuthService
    TypeOrmModule.forFeature([User, DeliveryPartner, Merchant]),
    JwtModule.register({
      global: true,
      secret: JWT_SECRET,
      // Cast: jsonwebtoken accepts a duration string ('30d') at runtime, but its
      // types only allow the narrow `ms.StringValue` literal union.
      signOptions: { expiresIn: JWT_EXPIRES_IN as unknown as number },
    }),
    HttpModule, // 🎯 2. تسجيل الـ HttpModule هنا لكي يستطيع الـ AuthService استخدام الـ HttpService بدون أي عطل
    // Registration refuses to create an account for an unverified phone, so
    // AuthService needs OtpService (see the forwardRef note in OtpModule).
    forwardRef(() => OtpModule),
  ],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService],
})
export class AuthModule {}
