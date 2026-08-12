import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeliveryZone } from './entities/delivery-zone.entity';
import { DeliveryZoneRate } from './entities/delivery-zone-rate.entity';
import { CreateZoneDto } from './dto/create-zone.dto';
import { CreateZoneRateDto } from './dto/create-zone-rate.dto';

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

  async quoteByZones(pickupZoneId: number, dropoffZoneId: number) {
    const rate = await this.rates.findOne({
      where: { pickupZoneId, dropoffZoneId, isActive: true },
      relations: { pickupZone: true, dropoffZone: true },
    });
    if (!rate) {
      throw new NotFoundException(
        'No active delivery price exists for the selected areas.',
      );
    }
    return {
      pickupZone: { id: rate.pickupZone.id, name: rate.pickupZone.name },
      dropoffZone: { id: rate.dropoffZone.id, name: rate.dropoffZone.name },
      deliveryFee: Number(rate.deliveryFee),
      estimatedMinutes: rate.estimatedMinutes,
      currency: 'EGP' as const,
    };
  }
}
