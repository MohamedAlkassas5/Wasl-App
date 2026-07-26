import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { FilesController } from './files.controller';
import { FilesService } from './files.service';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { Order } from '../orders/entities/order.entity';
import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      DeliveryPartner,
      Merchant,
      Order,
      WalletTopUpRequest,
    ]),
  ],
  controllers: [FilesController],
  providers: [FilesService],
})
export class FilesModule {}
