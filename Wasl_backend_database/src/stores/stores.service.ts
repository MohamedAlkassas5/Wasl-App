import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, IsNull, Repository } from 'typeorm';

import { Merchant, MerchantStatus } from '../merchant/entities/merchant.entity';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { haversineKm, roundKm, isValidCoordinate } from '../common/geo.util';

/**
 * Shape returned to the customer app. The `merchant_store_*` / `distance` keys
 * are the ones the Flutter store card already reads.
 */
export interface NearbyStore {
  id: number;
  merchant_store_name: string;
  merchant_store_type: string;
  logo?: string;
  addressDetails?: string;
  latitude: number;
  longitude: number;
  distance: number;
  /**
   * Whether the store is open for orders right now.
   *
   * Closed stores are still listed rather than hidden. In a town with a handful
   * of restaurants, a shop that vanishes at closing time reads as "gone" and
   * sends people looking for it; one shown greyed out reads as "come back
   * later", which is the truth. The server still refuses the order either way.
   */
  isAcceptingOrders: boolean;
}

/**
 * Nearby partner stores, from the `merchants` table.
 *
 * This used to fabricate four stores ("مطعم وكافيه الشرقاوي"…) by nudging the
 * customer's own coordinates a few hundred metres and calling the offsets a
 * distance — so the app always looked populated no matter what was in the
 * database. It now returns only real, admin-approved merchants that have
 * coordinates, and an honest empty list when there are none.
 */
@Injectable()
export class StoresService {
  constructor(
    @InjectRepository(Merchant)
    private readonly merchantRepository: Repository<Merchant>,
    private readonly settings: SettingsService,
  ) {}

  async getNearbyStores(
    lat: number,
    lng: number,
    radiusKm?: number,
  ): Promise<NearbyStore[]> {
    if (!isValidCoordinate(lat, lng)) {
      throw new BadRequestException('إحداثيات الموقع غير صالحة');
    }

    const radius =
      radiusKm ??
      this.settings.getNumber(SettingKey.STORE_SEARCH_RADIUS_KM, 10);

    const merchants = await this.merchantRepository.find({
      where: {
        status: MerchantStatus.APPROVED,
        latitude: Not(IsNull()),
        longitude: Not(IsNull()),
      },
    });

    const origin = { latitude: lat, longitude: lng };

    return merchants
      .map((m) => ({
        id: m.id,
        merchant_store_name: m.storeName,
        merchant_store_type: m.storeType,
        logo: m.logo,
        addressDetails: m.addressDetails,
        isAcceptingOrders: m.isAcceptingOrders,
        latitude: Number(m.latitude),
        longitude: Number(m.longitude),
        distance: roundKm(
          haversineKm(origin, {
            latitude: Number(m.latitude),
            longitude: Number(m.longitude),
          }),
        ),
      }))
      .filter((s) => s.distance <= radius)
      .sort((a, b) => a.distance - b.distance);
  }
}
