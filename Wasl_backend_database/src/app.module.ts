import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule'; // 🎯 استيراد موديل الجدولة الزمني الحركي
import { ConfigModule } from '@nestjs/config'; // 🎯 استيراد موديل الإعدادات للبيئة السحابية لاحقاً
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

// استيراد الـ Entities
import { User } from './users/entities/user.entity';
import { DeliveryPartner } from './delivery/entities/delivery-partner.entity';
import { Merchant } from './merchant/entities/merchant.entity';
import { Order, OrderOffer } from './orders/entities/order.entity';
import { InAppNotification } from './orders/entities/notification.entity'; // 1️⃣ أولاً: استدعاء الـ Entity الجديد هنا 🎯
import { AppSetting } from './settings/entities/app-setting.entity';
import { OtpVerification } from './otp/entities/otp-verification.entity';
import { WalletTopUpRequest } from './payments/entities/wallet-topup-request.entity';
import { WalletTransaction } from './payments/entities/wallet-transaction.entity';

// استيراد الموديلات (Modules)
import { AuthModule } from './auth/auth.module';
import { AdminModule } from './admin/admin.module';
import { OrdersModule } from './orders/orders.module';
import { CategoriesModule } from './categories/categories.module';
import { StoresModule } from './stores/stores.module';
import { UsersModule } from './users/users.module';
import { SettingsModule } from './settings/settings.module';
import { PricingModule } from './pricing/pricing.module';
import { DeliveryModule } from './delivery/delivery.module';
import { OtpModule } from './otp/otp.module';
import { PaymentsModule } from './payments/payments.module';
import { FilesModule } from './files/files.module';

@Module({
  imports: [
    // ⏱️ تفعيل الجدولة في كامل التطبيق لتشغيل الـ Cron Jobs وتنظيف الطلبات
    ScheduleModule.forRoot(),

    // 🎯 تفعيل الـ ConfigModule ليقوم بقراءة ملف الـ .env (جاهز للاستخدام السحابي)
    ConfigModule.forRoot({
      isGlobal: true,
    }),

    // 🛡️ Baseline per-IP rate limit for every route. Abuse-prone endpoints
    // (OTP send, login, register) tighten this further with @Throttle().
    // ttl is in milliseconds.
    ThrottlerModule.forRoot({
      throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
    }),

    // 💻 Database connection.
    // - Cloud (Render/Railway/Neon): set DATABASE_URL → connects over SSL.
    // - Local dev: falls back to localhost Postgres (override via env vars).
    // No secrets are hardcoded; the local fallback password is dev-only.
    TypeOrmModule.forRoot({
      type: 'postgres',
      ...(process.env.DATABASE_URL
        ? {
            url: process.env.DATABASE_URL,
            ssl: { rejectUnauthorized: false },
          }
        : {
            host: process.env.DB_HOST || 'localhost',
            port: Number(process.env.DB_PORT || 5432),
            username: process.env.DB_USERNAME || 'postgres',
            password: process.env.DB_PASSWORD || '147258369',
            database: process.env.DB_NAME || 'wasl_delivery_db',
          }),
      entities: [
        User,
        DeliveryPartner,
        Merchant,
        Order,
        OrderOffer,
        InAppNotification,
        AppSetting,
        OtpVerification,
        WalletTopUpRequest,
        WalletTransaction,
      ],
      autoLoadEntities: true,
      synchronize: true, // auto-creates tables; fine for MVP. Move to migrations before scale.
    }),

    AuthModule,
    AdminModule,
    SettingsModule,
    PricingModule,
    DeliveryModule,
    OtpModule,
    PaymentsModule,
    OrdersModule,
    CategoriesModule,
    StoresModule,
    UsersModule,
    FilesModule,
  ],
  providers: [
    // Applies the rate limiter globally; individual routes opt out with
    // @SkipThrottle() or tighten it with @Throttle().
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}

// =========================================================================================
// 🌐 [نسخة الاحتياط السحابية]: عند الانتقال إلى Neon Cloud، يمكنك إغلاق الاتصال بالأعلى وتفعيل هذا:
// =========================================================================================
// @Module({
//   imports: [
//     ScheduleModule.forRoot(),
//     ConfigModule.forRoot({
//       isGlobal: true,
//     }),
//     TypeOrmModule.forRoot({
//       type: 'postgres',
//       url: process.env.DATABASE_URL, // 👈 قراءة الرابط السحابي من الـ .env تلقائياً
//       entities: [User, DeliveryPartner, Merchant, Order, OrderOffer, InAppNotification], // 🎯 مضاف هنا أيضاً
//       autoLoadEntities: true,
//       synchronize: true,
//       ssl: {
//         rejectUnauthorized: false, // 👈 إجبارية لتأمين وتشغيل الاتصال مع خوادم Neon السحابية
//       },
//     }),
//     AuthModule,
//     AdminModule,
//     OrdersModule,
//     CategoriesModule,
//     StoresModule,
//   ],
// })
// export class AppModule {}
