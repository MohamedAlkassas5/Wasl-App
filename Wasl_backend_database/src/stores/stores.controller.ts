import { Controller, Get, Query, ParseFloatPipe } from '@nestjs/common';
import { StoresService } from './stores.service';

@Controller('stores')
export class StoresController {
  constructor(private readonly storesService: StoresService) {}

  @Get('nearby') // المسار الكامل: /stores/nearby
  async getNearby(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
  ) {
    const stores = await this.storesService.getNearbyStores(lat, lng);
    return {
      success: true,
      data: stores,
    };
  }
}
