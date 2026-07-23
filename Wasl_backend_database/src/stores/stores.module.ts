import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios'; // 👈 استيراد موديل الاتصال الخارجي (Axios)
import { StoresService } from './stores.service';
import { StoresController } from './stores.controller';

@Module({
  imports: [
    HttpModule.register({
      timeout: 10000, // وقت انتظار أقصى 10 ثوانٍ لرد الخريطة
      maxRedirects: 5,
    }),
  ],
  controllers: [StoresController],
  providers: [StoresService],
})
export class StoresModule {}
