import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { FilesController } from './files.controller';
import { FilesService } from './files.service';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { Order } from '../orders/entities/order.entity';
import { OrderMessage } from '../orders/entities/order-message.entity';
import { OrderAssignment } from '../orders/entities/order-assignment.entity';
import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';
import { SupportModule } from '../support/support.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      DeliveryPartner,
      Merchant,
      Order,
      WalletTopUpRequest,
      OrderMessage,
      // Who was offered an order decides who may see its photo before it is
      // assigned.
      OrderAssignment,
    ]),
    // Support owns the rule for its own attachments; FilesService asks it.
    SupportModule,
  ],
  controllers: [FilesController],
  providers: [FilesService],
})
export class FilesModule {}
