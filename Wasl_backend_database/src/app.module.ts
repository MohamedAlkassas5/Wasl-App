import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule'; // 🎯 استيراد موديل الجدولة الزمني الحركي
import { ConfigModule } from '@nestjs/config'; // 🎯 استيراد موديل الإعدادات للبيئة السحابية لاحقاً

// استيراد الـ Entities
import { User } from './users/entities/user.entity';
import { DeliveryPartner } from './delivery/entities/delivery-partner.entity';
import { Merchant } from './merchant/entities/merchant.entity';
import { Order, OrderOffer } from './orders/entities/order.entity';
import { InAppNotification } from './orders/entities/notification.entity'; // 1️⃣ أولاً: استدعاء الـ Entity الجديد هنا 🎯

// استيراد الموديلات (Modules)
import { AuthModule } from './auth/auth.module';
import { AdminModule } from './admin/admin.module';
import { OrdersModule } from './orders/orders.module';
import { CategoriesModule } from './categories/categories.module';
import { StoresModule } from './stores/stores.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    // ⏱️ تفعيل الجدولة في كامل التطبيق لتشغيل الـ Cron Jobs وتنظيف الطلبات
    ScheduleModule.forRoot(),

    // 🎯 تفعيل الـ ConfigModule ليقوم بقراءة ملف الـ .env (جاهز للاستخدام السحابي)
    ConfigModule.forRoot({
      isGlobal: true,
    }),

    // 💻 [الاتصال الحالي]: الاتصال بـ Local Postgres
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'postgres',
      password: '147258369', // 🔐 باسورد الـ Localhost الخاص بك
      database: 'wasl_delivery_db',
      // 🎯 تسجيل الـ Entity الجديد داخل المصفوفة لإنشائه تلقائياً
      entities: [
        User,
        DeliveryPartner,
        Merchant,
        Order,
        OrderOffer,
        InAppNotification,
      ],
      autoLoadEntities: true, // يضمن التحميل التلقائي للـ Entities المرتبطة بالموديلات الفرعية
      synchronize: true, // تلقائياً هيولد الجداول الجديدة والـ WalletBalance والـ Notifications
    }),

    AuthModule,
    AdminModule,
    OrdersModule,
    CategoriesModule,
    StoresModule,
    UsersModule,
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
