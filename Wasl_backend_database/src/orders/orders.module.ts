import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OrdersService } from './orders.service';
import { OrdersController } from './orders.controller';
import { OrderChatService } from './order-chat.service';
import { OrderChatController } from './order-chat.controller';
import { OrderMessage } from './entities/order-message.entity';
import { OrderPriceProposal } from './entities/order-price-proposal.entity';
import { OrderCancellationRequest } from './entities/order-cancellation-request.entity';
import { OrderCancellationService } from './order-cancellation.service';
import { OrderCancellationController } from './order-cancellation.controller';
import { AdminCancellationsController } from './admin-cancellations.controller';
import { SettingsModule } from '../settings/settings.module';
import { Order } from './entities/order.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { InAppNotification } from './entities/notification.entity'; // 🎯 استيراد الـ Entity الجديد المصلح
import { PricingModule } from '../pricing/pricing.module';
import { DeliveryModule } from '../delivery/delivery.module';
import { PaymentsModule } from '../payments/payments.module';
import { ZonesModule } from '../zones/zones.module';
import { User } from '../users/entities/user.entity';
import { OrderItem } from './entities/order-item.entity';
import { CatalogModule } from '../catalog/catalog.module';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [
    // 🎯 تسجيل الـ InAppNotification وجميع الـ Entities المطلوبة داخل الـ TypeOrmModule لإنشاء الجداول لايف
    // `User` is here so a normal order can price itself from the customer's
    // saved area without the app having to send it.
    TypeOrmModule.forFeature([
      Order,
      OrderItem,
      DeliveryPartner,
      InAppNotification,
      User,
      // 💬 CP5: one conversation per order, plus the price changes decided in it.
      OrderMessage,
      OrderPriceProposal,
      // 🚫 CP6: cancellations, their penalties, and the appeals against them.
      OrderCancellationRequest,
    ]),
    // The cancellation penalty percentage is an admin-editable setting.
    SettingsModule,
    // Uploads (order photos, chat attachments) go through the storage backend.
    // StorageModule is @Global, but importing it explicitly keeps the
    // dependency real for anyone who builds this module on its own.
    StorageModule,
    // Itemised orders are priced from the merchant's catalog, server-side.
    CatalogModule,
    PricingModule,
    DeliveryModule,
    PaymentsModule,
    ZonesModule,
  ],
  controllers: [
    OrdersController,
    OrderChatController,
    OrderCancellationController,
    AdminCancellationsController,
  ],
  providers: [OrdersService, OrderChatService, OrderCancellationService],
  exports: [OrdersService], // 🎯 تم التفعيل لكي تتمكن من استخدام الخدمة في الـ Modules الأخرى لو احتجت مستقبلاً
})
export class OrdersModule {}
