import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeliveryZone } from './entities/delivery-zone.entity';
import { DeliveryZoneRate } from './entities/delivery-zone-rate.entity';
import { CreateZoneDto } from './dto/create-zone.dto';
import { CreateZoneRateDto } from './dto/create-zone-rate.dto';

/** A resolved fee for delivering into one area (normal order). */
export interface DestinationQuote {
  dropoffZone: { id: number; name: string; code?: string };
  deliveryFee: number;
  currency: 'EGP';
}

@Injectable()
export class ZonesService {
  constructor(
    @InjectRepository(DeliveryZone)
    private readonly zones: Repository<DeliveryZone>,
    @InjectRepository(DeliveryZoneRate)
    private readonly rates: Repository<DeliveryZoneRate>,
  ) {}

  list(activeOnly = true): Promise<DeliveryZone[]> {
    return this.zones.find({
      where: activeOnly ? { isActive: true } : undefined,
      order: { city: 'ASC', name: 'ASC' },
    });
  }

  async create(dto: CreateZoneDto): Promise<DeliveryZone> {
    return this.zones.save(this.zones.create(dto));
  }

  async update(id: number, dto: Partial<CreateZoneDto>): Promise<DeliveryZone> {
    const zone = await this.zones.findOne({ where: { id } });
    if (!zone) throw new NotFoundException('Zone not found.');
    Object.assign(zone, dto);
    return this.zones.save(zone);
  }

  async createRate(dto: CreateZoneRateDto): Promise<DeliveryZoneRate> {
    const [pickup, dropoff] = await Promise.all([
      this.zones.findOne({ where: { id: dto.pickupZoneId, isActive: true } }),
      this.zones.findOne({ where: { id: dto.dropoffZoneId, isActive: true } }),
    ]);
    if (!pickup || !dropoff) {
      throw new NotFoundException(
        'Both pricing zones must exist and be active.',
      );
    }
    const existing = await this.rates.findOne({
      where: {
        pickupZoneId: dto.pickupZoneId,
        dropoffZoneId: dto.dropoffZoneId,
      },
    });
    const rate = existing
      ? Object.assign(existing, dto)
      : this.rates.create(dto);
    return this.rates.save(rate);
  }

  listRates(): Promise<DeliveryZoneRate[]> {
    return this.rates.find({
      where: { isActive: true },
      relations: { pickupZone: true, dropoffZone: true },
      order: { pickupZoneId: 'ASC', dropoffZoneId: 'ASC' },
    });
  }

  /**
   * An approved, currently-active zone — or a refusal.
   *
   * Used wherever a client hands us a zone id (registration, profile update,
   * order creation). An unknown or deactivated area must never fall through to
   * a default price, so this throws rather than returning null.
   */
  async getActiveZone(zoneId: number): Promise<DeliveryZone> {
    const zone = await this.zones.findOne({
      where: { id: zoneId, isActive: true },
    });
    if (!zone) {
      throw new BadRequestException(
        'المنطقة المختارة غير مدعومة حالياً، اختر منطقة من المناطق المتاحة',
      );
    }
    return zone;
  }

  /** Zone lookup by its stable code (`kom_hamada`…). Null when absent. */
  findByCode(code: string): Promise<DeliveryZone | null> {
    return this.zones.findOne({ where: { code, isActive: true } });
  }

  /**
   * Normal-order price: a flat fee determined by the **destination area only**.
   *
   * Deliberately ignores distance and the merchant's location — a restaurant
   * order and a pharmacy order to the same area cost the same to deliver.
   */
  async quoteByDestination(dropoffZoneId: number): Promise<DestinationQuote> {
    const zone = await this.getActiveZone(dropoffZoneId);

    // A null fee means "not an approved destination", which is not the same as
    // free delivery — refuse instead of quoting zero.
    if (
      zone.normalDeliveryFee === null ||
      zone.normalDeliveryFee === undefined
    ) {
      throw new BadRequestException(
        `لا يوجد سعر توصيل معتمد لمنطقة ${zone.name} حالياً`,
      );
    }

    return {
      dropoffZone: { id: zone.id, name: zone.name, code: zone.code },
      deliveryFee: Number(zone.normalDeliveryFee),
      currency: 'EGP',
    };
  }

  async quoteByZones(pickupZoneId: number, dropoffZoneId: number) {
    const rate = await this.rates.findOne({
      where: { pickupZoneId, dropoffZoneId, isActive: true },
      relations: { pickupZone: true, dropoffZone: true },
    });
    if (!rate) {
      // Both areas may be valid on their own and still have no approved route
      // between them, so this is a route-level refusal, not an unknown zone.
      throw new BadRequestException(
        'لا يوجد سعر معتمد للتوصيل بين المنطقتين المختارتين',
      );
    }
    return {
      pickupZone: {
        id: rate.pickupZone.id,
        name: rate.pickupZone.name,
        code: rate.pickupZone.code,
      },
      dropoffZone: {
        id: rate.dropoffZone.id,
        name: rate.dropoffZone.name,
        code: rate.dropoffZone.code,
      },
      deliveryFee: Number(rate.deliveryFee),
      estimatedMinutes: rate.estimatedMinutes,
      currency: 'EGP' as const,
    };
  }
}
