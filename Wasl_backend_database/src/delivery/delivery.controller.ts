import {
  Controller,
  Patch,
  Get,
  Param,
  Body,
  Query,
  ParseIntPipe,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { DeliveryService } from './delivery.service';
import { UpdateLocationDto } from './dto/update-location.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

/**
 * Driver location + nearby-driver endpoints. All routes require a valid JWT
 * (the previous order/driver endpoints had no auth at all).
 */
@Controller('drivers')
@UseGuards(JwtAuthGuard)
export class DeliveryController {
  constructor(private readonly deliveryService: DeliveryService) {}

  /** Driver app pushes its live GPS location here while online. */
  @Patch(':id/location')
  updateLocation(
    @Param('id', ParseIntPipe) driverId: number,
    @Body() dto: UpdateLocationDto,
  ) {
    return this.deliveryService.updateLocation(
      driverId,
      dto.latitude,
      dto.longitude,
      dto.availabilityRadiusKm,
    );
  }

  /**
   * Customer app: list available drivers near a point, nearest-first.
   * Uses expanding radius so a slightly-far driver is still surfaced.
   */
  @Get('nearby')
  findNearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius') radius?: string,
  ) {
    const latitude = Number(lat);
    const longitude = Number(lng);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw new BadRequestException('يجب إرسال إحداثيات الموقع (lat, lng)');
    }
    if (radius) {
      return this.deliveryService
        .findNearbyOnlineDrivers(latitude, longitude, Number(radius))
        .then((drivers) => ({
          radiusKm: Number(radius),
          count: drivers.length,
          drivers,
        }));
    }
    return this.deliveryService
      .findNearbyWithExpansion(latitude, longitude)
      .then((r) => ({ ...r, count: r.drivers.length }));
  }
}
