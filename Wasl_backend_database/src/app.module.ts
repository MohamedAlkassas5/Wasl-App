import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule'; // 🎯 استيراد موديل الجدولة الزمني الحركي
import { ConfigModule } from '@nestjs/config'; // 🎯 استيراد موديل الإعدادات للبيئة السحابية لاحقاً
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

// الـ Entities وإعدادات الاتصال مصدرها ملف واحد يشاركه الـ migration CLI
import { buildDataSourceOptions } from './database/data-source';

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

    // 💻 Database connection — settings come from `database/data-source.ts`,
    // the same file the migration CLI uses, so the app and the migrations can
    // never disagree about which database or entities are in play.
    //
    // `synchronize` is OFF (see the note in data-source.ts). The schema is now
    // owned by migrations, which run automatically on boot so a deploy brings
    // the database up to date before the app starts serving.
    TypeOrmModule.forRoot({
      ...buildDataSourceOptions(),
      autoLoadEntities: true,
      migrationsRun: true,
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
