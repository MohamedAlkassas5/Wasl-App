import { Injectable } from '@nestjs/common';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { haversineKm, roundKm, GeoPoint } from '../common/geo.util';

export interface PriceQuote {
  distanceKm: number;
  tier: 'city' | 'nearby' | 'far';
  deliveryFee: number;
  commissionPercent: number;
  commission: number;
  driverEarnings: number;
  currency: 'EGP';
}

/**
 * DeliveryPricingService — single source of truth for how much a delivery
 * costs and how the fee is split between the driver and the platform.
 *
 * Pricing is a function of trip DISTANCE only (pickup → destination), so it
 * needs no hardcoded city coordinates and scales to any future city. Every
 * number comes from SettingsService and is editable by an admin at runtime.
 */
@Injectable()
export class PricingService {
  constructor(private readonly settings: SettingsService) {}

  /** Quote from an already-computed distance. */
  quoteForDistance(distanceKm: number): PriceQuote {
    const dist = roundKm(Math.max(0, distanceKm));

    const tier1Max = this.settings.getNumber(SettingKey.TIER1_MAX_KM, 5);
    const tier2Max = this.settings.getNumber(SettingKey.TIER2_MAX_KM, 15);
    const cityFee = this.settings.getNumber(SettingKey.BASE_FEE_CITY, 20);
    const nearbyFee = this.settings.getNumber(SettingKey.BASE_FEE_NEARBY, 40);
    const perKmFar = this.settings.getNumber(SettingKey.PER_KM_FAR, 5);
    const commissionPercent = this.settings.getNumber(
      SettingKey.COMMISSION_PERCENT,
      20,
    );

    let tier: PriceQuote['tier'];
    let deliveryFee: number;

    if (dist <= tier1Max) {
      tier = 'city';
      deliveryFee = cityFee;
    } else if (dist <= tier2Max) {
      tier = 'nearby';
      deliveryFee = nearbyFee;
    } else {
      tier = 'far';
      deliveryFee = nearbyFee + Math.ceil(dist - tier2Max) * perKmFar;
    }

    const commission = this.round2((deliveryFee * commissionPercent) / 100);
    const driverEarnings = this.round2(deliveryFee - commission);

    return {
      distanceKm: dist,
      tier,
      deliveryFee: this.round2(deliveryFee),
      commissionPercent,
      commission,
      driverEarnings,
      currency: 'EGP',
    };
  }

  /** Quote from two geographic points. */
  quoteForTrip(pickup: GeoPoint, destination: GeoPoint): PriceQuote {
    return this.quoteForDistance(haversineKm(pickup, destination));
  }

  /**
   * Platform commission for a given final delivery fee. Used when an order
   * completes and the driver bid an arbitrary fee (marketplace/offer model).
   */
  commissionForFee(deliveryFee: number): number {
    const commissionPercent = this.settings.getNumber(
      SettingKey.COMMISSION_PERCENT,
      20,
    );
    return this.round2((Number(deliveryFee) * commissionPercent) / 100);
  }

  /** Minimum driver wallet balance (EGP) required to go online. */
  minWalletToGoOnline(): number {
    return this.settings.getNumber(SettingKey.MIN_WALLET_TO_GO_ONLINE, 5);
  }

  private round2(n: number): number {
    return Math.round(n * 100) / 100;
  }
}
