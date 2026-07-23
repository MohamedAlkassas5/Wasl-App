import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { HttpModule } from '@nestjs/axios'; // 🎯 1. استيراد موديول الـ HTTP الخاص بـ Axios لحل الأزمة
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
      secret: 'WASL_SUPER_SECRET_KEY_2026',
      signOptions: { expiresIn: '30d' },
    }),
    HttpModule, // 🎯 2. تسجيل الـ HttpModule هنا لكي يستطيع الـ AuthService استخدام الـ HttpService بدون أي عطل
  ],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService],
})
export class AuthModule {}
