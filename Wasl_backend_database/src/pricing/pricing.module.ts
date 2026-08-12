import { Module } from '@nestjs/common';
import { SettingsModule } from '../settings/settings.module';
import { PricingService } from './pricing.service';
import { PricingController } from './pricing.controller';
import { ZonesModule } from '../zones/zones.module';
import { UsersModule } from '../users/users.module';

@Module({
  // UsersModule: a normal quote with no explicit area falls back to the
  // caller's saved home area.
  imports: [SettingsModule, ZonesModule, UsersModule],
  controllers: [PricingController],
  providers: [PricingService],
  exports: [PricingService],
})
export class PricingModule {}
