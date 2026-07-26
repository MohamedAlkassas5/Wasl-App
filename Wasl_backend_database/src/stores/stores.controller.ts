import {
  Controller,
  Get,
  Query,
  ParseFloatPipe,
  UseGuards,
} from '@nestjs/common';
import { StoresService } from './stores.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('stores')
@UseGuards(JwtAuthGuard)
export class StoresController {
  constructor(private readonly storesService: StoresService) {}

  @Get('nearby') // المسار الكامل: /stores/nearby
  async getNearby(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
    @Query('radius') radius?: string,
  ) {
    const radiusKm = radius !== undefined ? Number(radius) : undefined;
    const stores = await this.storesService.getNearbyStores(
      lat,
      lng,
      Number.isFinite(radiusKm) ? radiusKm : undefined,
    );

    return {
      success: true,
      // Empty means "no approved partner stores near you yet" — the app must
      // show that honestly rather than substituting placeholders.
      data: stores,
    };
  }
}
