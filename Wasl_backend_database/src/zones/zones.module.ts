import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DeliveryZone } from './entities/delivery-zone.entity';
import { DeliveryZoneRate } from './entities/delivery-zone-rate.entity';
import { ZonesController } from './zones.controller';
import { ZonesService } from './zones.service';

@Module({
  imports: [TypeOrmModule.forFeature([DeliveryZone, DeliveryZoneRate])],
  controllers: [ZonesController],
  providers: [ZonesService],
  exports: [ZonesService],
})
export class ZonesModule {}
