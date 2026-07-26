import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Merchant } from '../merchant/entities/merchant.entity';
import { SettingsModule } from '../settings/settings.module';
import { StoresService } from './stores.service';
import { StoresController } from './stores.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Merchant]), SettingsModule],
  controllers: [StoresController],
  providers: [StoresService],
})
export class StoresModule {}
