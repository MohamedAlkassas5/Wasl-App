import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, IsNull } from 'typeorm';
import { DeliveryPartner } from './entities/delivery-partner.entity';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
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

  /**
   * The driver's own vehicle record.
   *
   * Deliberately a narrow projection, not the row. `delivery_partners` also
   * carries the wallet balance, the live GPS fix and the admin's private
   * notes; none of that belongs in a "my vehicle" screen, and returning the
   * whole entity is how such a field ends up on a client by accident.
   *
   * The document keys ARE included: `FilesService.canRead` already lets a
   * partner read their own documents, so this only tells them the name of a
   * file they are entitled to fetch.
   */
  async getMyVehicle(driverId: number) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('حساب الكابتن غير موجود');

    return {
      success: true,
      vehicleType: driver.vehicleType,
      licenseNumber: driver.licenseNumber ?? '',
      vehicleImage: driver.vehicleImage,
      // Read-only here — an admin decides it, and the screen shows it so the
      // driver understands why they can or cannot work.
      verificationStatus: driver.verificationStatus,
    };
  }

  /**
   * Edit the vehicle type and/or plate number.
   *
   * 🔐 `driverId` comes from the token, never from the request, so a driver
   * can only ever edit their own row.
   *
   * Changing these does **not** re-open verification. `vehicleType` is
   * recorded at registration and is not read by pricing, assignment or the
   * eligibility gate (checked before this was allowed), so a correction here
   * moves no money and grants no access. The approved *documents* are what
   * verification rests on, and those are untouched by this route.
   */
  async updateMyVehicle(driverId: number, dto: UpdateVehicleDto) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('حساب الكابتن غير موجود');

    if (dto.vehicleType === undefined && dto.licenseNumber === undefined) {
      throw new BadRequestException('لا يوجد أي تعديل لحفظه');
    }

    if (dto.vehicleType !== undefined) {
      driver.vehicleType = dto.vehicleType;
    }
    if (dto.licenseNumber !== undefined) {
      const trimmed = dto.licenseNumber.trim();
      driver.licenseNumber = trimmed === '' ? undefined : trimmed;
    }

    await this.deliveryRepository.save(driver);

    return {
      ...(await this.getMyVehicle(driverId)),
      message: 'تم حفظ بيانات المركبة بنجاح',
    };
  }

  /**
   * Whether a driver's GPS fix is recent enough for them to be matched.
   *
   * The same `driver_location_ttl_min` that {@link findNearbyOnlineDrivers}
   * applies, exposed so callers can *report* reachability instead of
   * re-deriving the rule. Being `is_online` is not the same as being
   * reachable, and the difference is invisible to the driver unless something
   * says so.
   */
  locationFreshness(lastLocationUpdate?: Date | null): {
    fresh: boolean;
    ttlMinutes: number;
  } {
    const ttlMinutes = this.settings.getNumber(
      SettingKey.DRIVER_LOCATION_TTL_MIN,
      10,
    );
    if (!lastLocationUpdate) return { fresh: false, ttlMinutes };

    const age = Date.now() - new Date(lastLocationUpdate).getTime();
    return { fresh: age <= ttlMinutes * 60 * 1000, ttlMinutes };
  }

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
