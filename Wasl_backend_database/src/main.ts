// import { ValidationPipe } from '@nestjs/common'; // 🎯 استيراد الـ ValidationPipe
// import { NestFactory } from '@nestjs/core';
// import { AppModule } from './app.module';
// import 'dotenv/config'; // 👈 أضف هذا السطر في أول السطر رقم 1 في main.ts

// async function bootstrap() {
//   const app = await NestFactory.create(AppModule);

//   // 🌐 [تم الإضافة]: تفعيل الـ CORS لتأمين قنوات الاتصال وفك حظر المحاكي والأجهزة الخارجية
//   app.enableCors();

//   // 🛡️ Behind Render/Railway the app sees the proxy's IP unless we trust the
//   // X-Forwarded-For header. Without this the rate limiter would count every
//   // request as coming from one address.
//   app.getHttpAdapter().getInstance().set('trust proxy', 1);

//   // 🎯 تفعيل الفحص البرمجي الشامل والتحويل التلقائي للبيانات بداخل السيرفر
//   app.useGlobalPipes(
//     new ValidationPipe({
//       whitelist: true, // يتجاهل تلقائياً أي حقول زائدة مرسلة ليست معرفة في الـ DTO لحماية قاعدة البيانات
//       transform: true, // تحويل أنواع البيانات المرسلة تلقائياً لتطابق الأنواع المعرفة (مثل تحويل النص إلى رقم)
//     }),
//   );

//   // 🔐 uploads/ is NOT served statically any more. National IDs, selfies and
//   // payment-proof screenshots live there; they now go through FilesController,
//   // which requires a token and checks that the caller owns the document.

//   // 🚀 [تم التحديث]: تشغيل السيرفر ليستقبل الاتصالات اللوجستية الحية من الموبايل والمحاكي بسلاسة
//   const port = process.env.PORT ?? 3000;
//   await app.listen(port, '0.0.0.0');

//   console.log(
//     `🚀 [WASL BACKEND] السيرفر شغال لايف على بورت: http://localhost:${port}`,
//   );
// }
// // eslint-disable-next-line @typescript-eslint/no-floating-promises
// bootstrap();

import 'dotenv/config'; // 🎯 حاسم جداً: يجب أن يكون السطر رقم 1 لضمان قراءة .env قبل تحميل أي Module أو Seeder
import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import type { Request, Response, NextFunction } from 'express';

async function bootstrap() {
  // 🎯 تحديد نوع التطبيق كـ NestExpressApplication لإزالة أخطاء Unsafe Member Access
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const logger = new Logger('Bootstrap');

  const allowedOrigins = (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (process.env.NODE_ENV === 'production' && allowedOrigins.length === 0) {
    throw new Error('CORS_ORIGINS is required in production.');
  }
  app.enableCors({
    origin: allowedOrigins.length === 0 ? true : allowedOrigins,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE'],
    allowedHeaders: ['Authorization', 'Content-Type'],
  });

  // 🛡️ Behind Render/Railway the app sees the proxy's IP unless we trust the
  // X-Forwarded-For header. Without this the rate limiter would count every
  // request as coming from one address.
  if (process.env.TRUST_PROXY === 'true') app.set('trust proxy', 1);

  app.use((_request: Request, response: Response, next: NextFunction) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('X-Frame-Options', 'DENY');
    response.setHeader('Referrer-Policy', 'no-referrer');
    next();
  });

  // 🎯 تفعيل الفحص البرمجي الشامل والتحويل التلقائي للبيانات بداخل السيرفر
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // يتجاهل تلقائياً أي حقول زائدة مرسلة ليست معرفة في الـ DTO لحماية قاعدة البيانات
      forbidNonWhitelisted: true,
      transform: true, // تحويل أنواع البيانات المرسلة تلقائياً لتطابق الأنواع المعرفة (مثل تحويل النص إلى رقم)
    }),
  );

  // 🔐 uploads/ is NOT served statically any more. National IDs, selfies and
  // payment-proof screenshots live there; they now go through FilesController,
  // which requires a token and checks that the caller owns the document.

  // 🚀 تشغيل السيرفر ليستقبل الاتصالات اللوجستية الحية من الموبايل والمحاكي بسلاسة
  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');

  logger.log(
    `🚀 [WASL BACKEND] السيرفر شغال لايف على بورت: http://localhost:${port}`,
  );
}

// eslint-disable-next-line @typescript-eslint/no-floating-promises
bootstrap();
