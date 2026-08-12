import { Injectable } from '@nestjs/common';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { haversineKm, roundKm, GeoPoint } from '../common/geo.util';
import { ZonesService } from '../zones/zones.service';

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
 * PricingService — the single source of truth for what a delivery costs.
 *
 * Two rules, in priority order:
 *
 *  1. **Normal orders** (restaurants / pharmacy / stores) — a flat fee set by
 *     the **destination area alone**. See {@link quoteForDestinationZone}.
 *  2. **Waslly** (area → area courier runs) — a fixed fee per route, read from
 *     the pickup×drop-off rate matrix. See {@link quoteForZones}.
 *
 * Distance tiers ({@link quoteForDistance}) are the legacy rule and are now a
 * fallback only: they apply to an order that carries no areas at all. Every
 * number is data — zone rows and admin-editable settings — so tariffs change
 * without a redeploy.
 *
 * A price is never accepted from a client. Callers pass areas; this service
 * decides the money.
 */
@Injectable()
export class PricingService {
  constructor(
    private readonly settings: SettingsService,
    private readonly zones: ZonesService,
  ) {}

  /**
   * Normal order: fee for delivering into `dropoffZoneId`.
   * Throws when the area is unknown, inactive, or has no approved fee.
   */
  async quoteForDestinationZone(dropoffZoneId: number) {
    const zoneQuote = await this.zones.quoteByDestination(dropoffZoneId);
    return { ...zoneQuote, ...this.split(zoneQuote.deliveryFee) };
  }

  /** Waslly: fixed fee for the pickup-area → drop-off-area route. */
  async quoteForZones(pickupZoneId: number, dropoffZoneId: number) {
    const zoneQuote = await this.zones.quoteByZones(
      pickupZoneId,
      dropoffZoneId,
    );
    return { ...zoneQuote, ...this.split(zoneQuote.deliveryFee) };
  }

  /** How a delivery fee divides between the platform and the driver. */
  private split(deliveryFee: number) {
    const commission = this.commissionForFee(deliveryFee);
    return {
      commissionPercent: this.settings.getNumber(
        SettingKey.COMMISSION_PERCENT,
        20,
      ),
      commission,
      driverEarnings: this.round2(deliveryFee - commission),
    };
  }

  /**
   * Legacy distance-tier quote.
   *
   * @deprecated Superseded by area pricing. Reachable only for an order with
   * no pickup/drop-off area on it — an older client, or a record created
   * before areas existed. Kept so those still resolve to a real number rather
   * than failing; do not build new flows on it.
   */
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
   * Platform commission for a delivery fee:
   *
   *     commission = max(deliveryFee × 20%, 5 EGP)
   *
   * The floor matters because the percentage alone under-charges the cheap
   * trips that dominate a small town: a 20 EGP delivery would otherwise yield
   * 4 EGP. Both numbers are admin-editable settings, not constants.
   *
   * Commission is a share of the **delivery fee only**. What the customer paid
   * for the goods never enters this — the driver buys those with their own
   * money and is repaid in cash on delivery, so that amount is not the
   * platform's to take a cut of.
   */
  commissionForFee(deliveryFee: number): number {
    const commissionPercent = this.settings.getNumber(
      SettingKey.COMMISSION_PERCENT,
      20,
    );
    const minCommission = this.settings.getNumber(SettingKey.MIN_COMMISSION, 5);
    const fee = Math.max(0, Number(deliveryFee) || 0);
    const percentage = this.round2((fee * commissionPercent) / 100);

    // A zero-fee order (a pickup the customer collects themselves) owes
    // nothing; the floor applies to deliveries that were actually charged for.
    if (fee <= 0) return 0;

    return this.round2(Math.max(percentage, minCommission));
  }

  /** Minimum driver wallet balance (EGP) required to go online. */
  minWalletToGoOnline(): number {
    return this.settings.getNumber(SettingKey.MIN_WALLET_TO_GO_ONLINE, 5);
  }

  private round2(n: number): number {
    return Math.round(n * 100) / 100;
  }
}
