import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OrdersService } from './orders.service';
import { OrdersController } from './orders.controller';
import { Order, OrderOffer } from './entities/order.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { InAppNotification } from './entities/notification.entity'; // 🎯 استيراد الـ Entity الجديد المصلح
import { PricingModule } from '../pricing/pricing.module';
import { DeliveryModule } from '../delivery/delivery.module';
import { PaymentsModule } from '../payments/payments.module';
import { ZonesModule } from '../zones/zones.module';

@Module({
  imports: [
    // 🎯 تسجيل الـ InAppNotification وجميع الـ Entities المطلوبة داخل الـ TypeOrmModule لإنشاء الجداول لايف
    TypeOrmModule.forFeature([
      Order,
      OrderOffer,
      DeliveryPartner,
      InAppNotification,
    ]),
    PricingModule,
    DeliveryModule,
    PaymentsModule,
    ZonesModule,
  ],
  controllers: [OrdersController],
  providers: [OrdersService],
  exports: [OrdersService], // 🎯 تم التفعيل لكي تتمكن من استخدام الخدمة في الـ Modules الأخرى لو احتجت مستقبلاً
})
export class OrdersModule {}
