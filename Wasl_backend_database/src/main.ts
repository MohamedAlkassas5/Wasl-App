import { ValidationPipe } from '@nestjs/common'; // 🎯 استيراد الـ ValidationPipe
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import * as express from 'express';
import { join } from 'path'; // 👈 استيراد دالة join لإدارة مسارات الفولدرات بداخل السيرفر

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // 🌐 [تم الإضافة]: تفعيل الـ CORS لتأمين قنوات الاتصال وفك حظر المحاكي والأجهزة الخارجية
  app.enableCors();

  // 🎯 تفعيل الفحص البرمجي الشامل والتحويل التلقائي للبيانات بداخل السيرفر
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // يتجاهل تلقائياً أي حقول زائدة مرسلة ليست معرفة في الـ DTO لحماية قاعدة البيانات
      transform: true, // تحويل أنواع البيانات المرسلة تلقائياً لتطابق الأنواع المعرفة (مثل تحويل النص إلى رقم)
    }),
  );

  // 🎯 السطر السحري: يفتح منفذ عام لرؤية وتحميل الصور والمستندات من فولدر uploads
  app.use('/uploads', express.static(join(__dirname, '..', 'uploads')));

  // 🚀 [تم التحديث]: تشغيل السيرفر ليستقبل الاتصالات اللوجستية الحية من الموبايل والمحاكي بسلاسة
  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');

  console.log(
    `🚀 [WASL BACKEND] السيرفر شغال لايف على بورت: http://localhost:${port}`,
  );
}
// eslint-disable-next-line @typescript-eslint/no-floating-promises
bootstrap();
