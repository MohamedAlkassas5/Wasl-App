import { Module } from '@nestjs/common';
import { SettingsModule } from '../settings/settings.module';
import { PricingService } from './pricing.service';
import { PricingController } from './pricing.controller';
import { ZonesModule } from '../zones/zones.module';

@Module({
  imports: [SettingsModule, ZonesModule],
  controllers: [PricingController],
  providers: [PricingService],
  exports: [PricingService],
})
export class PricingModule {}
