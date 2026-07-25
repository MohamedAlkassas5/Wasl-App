import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppSetting } from './entities/app-setting.entity';
import { SettingsService } from './settings.service';
import { SettingsController } from './settings.controller';

@Module({
  imports: [TypeOrmModule.forFeature([AppSetting])],
  controllers: [SettingsController],
  providers: [SettingsService],
  // Exported so PricingService, DeliveryService and OrdersService can read
  // the live configuration cache.
  exports: [SettingsService],
})
export class SettingsModule {}
