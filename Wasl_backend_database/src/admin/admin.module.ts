import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { User } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity'; // 👈 استيراد موديل المناديب
import { Merchant } from '../merchant/entities/merchant.entity'; // 👈 استيراد موديل التجار

@Module({
  imports: [
    // 🎯 شحن الـ Repositories الثلاثة لكي تستطيع الـ AdminService استخدامهم بدون أي عطل
    TypeOrmModule.forFeature([User, DeliveryPartner, Merchant]),
  ],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}
