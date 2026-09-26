import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppSetting } from './entities/app-setting.entity';

/**
 * Canonical keys for all runtime-configurable business rules.
 * Centralising them here prevents typos and documents the config surface.
 */
export const SettingKey = {
  COMMISSION_PERCENT: 'commission_percent',
  MIN_COMMISSION: 'min_commission',
  BASE_FEE_CITY: 'base_fee_city',
  BASE_FEE_NEARBY: 'base_fee_nearby',
  TIER1_MAX_KM: 'tier1_max_km',
  TIER2_MAX_KM: 'tier2_max_km',
  PER_KM_FAR: 'per_km_far',
  DRIVER_SEARCH_RADIUS_KM: 'driver_search_radius_km',
  DRIVER_LOCATION_TTL_MIN: 'driver_location_ttl_min',
  STORE_SEARCH_RADIUS_KM: 'store_search_radius_km',
  MIN_WALLET_TO_GO_ONLINE: 'min_wallet_to_go_online',
  CANCELLATION_PENALTY_PERCENT: 'cancellation_penalty_percent',
  PAY_VODAFONE_NUMBER: 'pay_vodafone_number',
  PAY_INSTAPAY_HANDLE: 'pay_instapay_handle',
  PAY_INSTRUCTIONS: 'pay_instructions',
  TOPUP_MIN_AMOUNT: 'topup_min_amount',
  TOPUP_MAX_AMOUNT: 'topup_max_amount',
} as const;

export type SettingKeyType = (typeof SettingKey)[keyof typeof SettingKey];

interface SettingSeed {
  key: SettingKeyType;
  value: string;
  description: string;
}

/**
 * Default configuration seeded on first boot. These are the Kom Hamada V1
 * numbers, but every one of them is editable at runtime by an admin without
 * a redeploy — nothing here is hardcoded into business logic.
 */
const DEFAULT_SETTINGS: SettingSeed[] = [
  {
    key: SettingKey.COMMISSION_PERCENT,
    value: '20',
    description: 'Platform commission taken from the delivery fee (%).',
  },
  {
    key: SettingKey.MIN_COMMISSION,
    value: '5',
    description:
      'Floor (EGP) under which the platform commission never falls, however small the delivery fee.',
  },
  {
    key: SettingKey.BASE_FEE_CITY,
    value: '20',
    description: 'Delivery fee (EGP) for trips within the city tier.',
  },
  {
    key: SettingKey.BASE_FEE_NEARBY,
    value: '40',
    description: 'Delivery fee (EGP) for nearby villages/cities tier.',
  },
  {
    key: SettingKey.TIER1_MAX_KM,
    value: '5',
    description: 'Upper bound (km) of the city tier.',
  },
  {
    key: SettingKey.TIER2_MAX_KM,
    value: '15',
    description: 'Upper bound (km) of the nearby tier.',
  },
  {
    key: SettingKey.PER_KM_FAR,
    value: '5',
    description: 'Extra EGP charged per km beyond the nearby tier.',
  },
  {
    key: SettingKey.DRIVER_SEARCH_RADIUS_KM,
    value: '5',
    description: 'Initial radius (km) used to search for nearby drivers.',
  },
  {
    key: SettingKey.DRIVER_LOCATION_TTL_MIN,
    value: '10',
    description:
      'A driver GPS fix older than this (minutes) is treated as stale.',
  },
  {
    key: SettingKey.STORE_SEARCH_RADIUS_KM,
    value: '10',
    description:
      'Radius (km) within which partner stores are shown to a customer.',
  },
  {
    key: SettingKey.MIN_WALLET_TO_GO_ONLINE,
    value: '5',
    description: 'Minimum driver wallet balance (EGP) required to go online.',
  },
  {
    key: SettingKey.CANCELLATION_PENALTY_PERCENT,
    value: '20',
    description:
      'Penalty (%) charged to the driver when an accepted order is cancelled. Applies to the delivery fee only, with no floor and no cap — deliberately separate from commission_percent so changing one never moves the other.',
  },
  {
    key: SettingKey.PAY_VODAFONE_NUMBER,
    value: '01032919674',
    description: 'Platform Vodafone Cash number drivers pay top-ups to.',
  },
  {
    key: SettingKey.PAY_INSTAPAY_HANDLE,
    value: '01220346717',
    description: 'Platform InstaPay handle/address drivers pay top-ups to.',
  },
  {
    key: SettingKey.PAY_INSTRUCTIONS,
    value: 'حوّل المبلغ إلى أحد الحسابات ثم ارفق صورة التحويل ورقم المُرسِل.',
    description: 'Instructions shown to drivers on the top-up screen.',
  },
  {
    key: SettingKey.TOPUP_MIN_AMOUNT,
    value: '10',
    description:
      'Smallest wallet top-up (EGP) a driver may request. Enforced server-side.',
  },
  {
    key: SettingKey.TOPUP_MAX_AMOUNT,
    value: '5000',
    description:
      'Largest wallet top-up (EGP) a driver may request in one go. A ceiling keeps a typo (or a tampered client) from filing a request an admin might approve by reflex.',
  },
];

@Injectable()
export class SettingsService implements OnModuleInit {
  private readonly logger = new Logger(SettingsService.name);

  /** In-memory cache so business logic can read config synchronously. */
  private readonly cache = new Map<string, string>();

  constructor(
    @InjectRepository(AppSetting)
    private readonly settingRepository: Repository<AppSetting>,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.seedDefaults();
    await this.refreshCache();
    this.logger.log(`⚙️  Loaded ${this.cache.size} app settings into cache.`);
  }

  /** Insert any missing default keys (never overwrites edited values). */
  private async seedDefaults(): Promise<void> {
    for (const seed of DEFAULT_SETTINGS) {
      const existing = await this.settingRepository.findOne({
        where: { key: seed.key },
      });
      if (!existing) {
        await this.settingRepository.save(this.settingRepository.create(seed));
      }
    }
  }

  private async refreshCache(): Promise<void> {
    const all = await this.settingRepository.find();
    this.cache.clear();
    for (const s of all) {
      this.cache.set(s.key, s.value);
    }
  }

  /** Synchronous numeric getter with a safe fallback. */
  getNumber(key: SettingKeyType, fallback = 0): number {
    const raw = this.cache.get(key);
    if (raw === undefined) return fallback;
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  getString(key: SettingKeyType, fallback = ''): string {
    return this.cache.get(key) ?? fallback;
  }

  async getAll(): Promise<AppSetting[]> {
    return this.settingRepository.find({ order: { key: 'ASC' } });
  }

  /** Update a single setting (admin) and keep the cache hot. */
  async set(key: string, value: string): Promise<AppSetting> {
    let setting = await this.settingRepository.findOne({ where: { key } });
    if (!setting) {
      setting = this.settingRepository.create({ key, value });
    } else {
      setting.value = value;
    }
    const saved = await this.settingRepository.save(setting);
    this.cache.set(saved.key, saved.value);
    return saved;
  }
}
