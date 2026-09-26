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
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser, assertSelfOrAdmin } from '../auth/current-user';

/**
 * Driver location + nearby-driver endpoints. All routes require a valid JWT
 * (the previous order/driver endpoints had no auth at all).
 */
@Controller('drivers')
@UseGuards(JwtAuthGuard)
export class DeliveryController {
  constructor(private readonly deliveryService: DeliveryService) {}

  /**
   * The signed-in driver's own vehicle record.
   *
   * There is no id in the path on purpose: the vehicle is whoever the token
   * says it is, so there is nothing to tamper with. (`:id/location` above
   * takes one for historical reasons and guards it with `assertSelfOrAdmin`.)
   */
  @Get('me/vehicle')
  getMyVehicle(@CurrentUser() user: AuthUser) {
    return this.deliveryService.getMyVehicle(user.sub);
  }

  /** Edit own vehicle type / plate number. Documents and verification status
   * are not editable here — those stay with the admin. */
  @Patch('me/vehicle')
  updateMyVehicle(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateVehicleDto,
  ) {
    return this.deliveryService.updateMyVehicle(user.sub, dto);
  }

  /**
   * Driver app pushes its live GPS location here while online.
   * 🔐 A driver may only move their own pin — spoofing another captain's
   * location would let an attacker steal or sabotage nearby-order matching.
   */
  @Patch(':id/location')
  updateLocation(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) driverId: number,
    @Body() dto: UpdateLocationDto,
  ) {
    assertSelfOrAdmin(user, driverId);
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
