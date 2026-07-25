import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WalletTopUpRequest } from './entities/wallet-topup-request.entity';
import { WalletTransaction } from './entities/wallet-transaction.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { AdminPaymentsController } from './admin-payments.controller';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      WalletTopUpRequest,
      WalletTransaction,
      DeliveryPartner,
    ]),
    SettingsModule,
  ],
  controllers: [PaymentsController, AdminPaymentsController],
  providers: [PaymentsService],
  // Exported so OrdersService records commission debits through the ledger.
  exports: [PaymentsService],
})
export class PaymentsModule {}
