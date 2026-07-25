import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, IsNull } from 'typeorm';
import { DeliveryPartner } from './entities/delivery-partner.entity';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { haversineKm, roundKm, isValidCoordinate } from '../common/geo.util';

export interface NearbyDriver {
  driverId: number;
  latitude: number;
  longitude: number;
  distanceKm: number;
  rating: number;
  lastLocationUpdate?: Date;
}

/**
 * DeliveryService owns the driver's real-time location and the
 * nearest-driver matching used by the marketplace. This logic previously did
 * not exist (drivers had no coordinates at all).
 */
@Injectable()
export class DeliveryService {
  constructor(
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,
    private readonly settings: SettingsService,
  ) {}

  /** Persist a fresh GPS fix for a driver. */
  async updateLocation(
    driverId: number,
    latitude: number,
    longitude: number,
    availabilityRadiusKm?: number,
  ): Promise<{ success: boolean; lastLocationUpdate: Date }> {
    if (!isValidCoordinate(latitude, longitude)) {
      throw new BadRequestException('إحداثيات الموقع غير صالحة');
    }

    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });
    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود');
    }

    driver.currentLatitude = latitude;
    driver.currentLongitude = longitude;
    driver.lastLocationUpdate = new Date();
    if (typeof availabilityRadiusKm === 'number') {
      driver.availabilityRadiusKm = availabilityRadiusKm;
    }
    await this.deliveryRepository.save(driver);

    return { success: true, lastLocationUpdate: driver.lastLocationUpdate };
  }

  /**
   * Online drivers with a fresh GPS fix, whose location is within `radiusKm`
   * of the given point, sorted nearest-first.
   */
  async findNearbyOnlineDrivers(
    latitude: number,
    longitude: number,
    radiusKm?: number,
  ): Promise<NearbyDriver[]> {
    if (!isValidCoordinate(latitude, longitude)) {
      throw new BadRequestException('إحداثيات البحث غير صالحة');
    }

    const radius =
      radiusKm ??
      this.settings.getNumber(SettingKey.DRIVER_SEARCH_RADIUS_KM, 5);
    const ttlMin = this.settings.getNumber(
      SettingKey.DRIVER_LOCATION_TTL_MIN,
      10,
    );
    const freshAfter = new Date(Date.now() - ttlMin * 60 * 1000);

    const candidates = await this.deliveryRepository.find({
      where: {
        isOnline: true,
        currentLatitude: Not(IsNull()),
        currentLongitude: Not(IsNull()),
      },
    });

    const origin = { latitude, longitude };

    return candidates
      .filter(
        (d) =>
          d.lastLocationUpdate != null &&
          new Date(d.lastLocationUpdate) >= freshAfter,
      )
      .map((d) => {
        const distanceKm = roundKm(
          haversineKm(origin, {
            latitude: Number(d.currentLatitude),
            longitude: Number(d.currentLongitude),
          }),
        );
        return {
          driverId: d.userId,
          latitude: Number(d.currentLatitude),
          longitude: Number(d.currentLongitude),
          distanceKm,
          rating: Number(d.rating ?? 5),
          lastLocationUpdate: d.lastLocationUpdate,
        };
      })
      .filter((d) => d.distanceKm <= radius)
      .sort((a, b) => a.distanceKm - b.distanceKm);
  }

  /**
   * Expanding-radius search: start at the configured radius and grow until at
   * least one driver is found or the max is reached. Prevents "no drivers"
   * when someone is just outside the initial ring.
   */
  async findNearbyWithExpansion(
    latitude: number,
    longitude: number,
    maxRadiusKm = 25,
  ): Promise<{ radiusKm: number; drivers: NearbyDriver[] }> {
    const start = this.settings.getNumber(
      SettingKey.DRIVER_SEARCH_RADIUS_KM,
      5,
    );
    for (let radius = start; radius <= maxRadiusKm; radius += start) {
      const drivers = await this.findNearbyOnlineDrivers(
        latitude,
        longitude,
        radius,
      );
      if (drivers.length > 0) {
        return { radiusKm: radius, drivers };
      }
    }
    return { radiusKm: maxRadiusKm, drivers: [] };
  }
}
