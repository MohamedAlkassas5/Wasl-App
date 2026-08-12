import { Test, TestingModule } from '@nestjs/testing';

import { PricingService } from './pricing.service';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { ZonesService } from '../zones/zones.service';

/**
 * commission = max(deliveryFee × 20%, 5 EGP)
 *
 * The floor exists because the percentage alone under-charges the short trips
 * that make up most of a small town's deliveries: 20% of a 20 EGP delivery is
 * 4 EGP. Both numbers are admin-editable settings rather than constants, which
 * is what these tests check by moving them.
 */
describe('PricingService — commission', () => {
  const build = async (
    overrides: Partial<Record<string, number>> = {},
  ): Promise<PricingService> => {
    const values: Record<string, number> = {
      [SettingKey.COMMISSION_PERCENT]: 20,
      [SettingKey.MIN_COMMISSION]: 5,
      ...overrides,
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PricingService,
        {
          provide: SettingsService,
          useValue: {
            getNumber: (key: string, fallback: number) =>
              values[key] ?? fallback,
          },
        },
        { provide: ZonesService, useValue: {} },
      ],
    }).compile();

    return module.get(PricingService);
  };

  let pricing: PricingService;
  beforeEach(async () => {
    pricing = await build();
  });

  describe('the 20% rule', () => {
    it.each([
      [40, 8],
      [50, 10],
      [100, 20],
      [250, 50],
    ])('a %i EGP delivery owes %i EGP', (fee, expected) => {
      expect(pricing.commissionForFee(fee)).toBe(expected);
    });
  });

  describe('the 5 EGP floor', () => {
    it('a 20 EGP delivery owes 5, not the 4 the percentage gives', () => {
      expect(pricing.commissionForFee(20)).toBe(5);
    });

    it.each([1, 10, 15, 24.99])(
      'a %s EGP delivery still owes the 5 EGP floor',
      (fee) => {
        expect(pricing.commissionForFee(fee)).toBe(5);
      },
    );

    it('25 EGP is the crossover: at or below it the floor wins', () => {
      expect(pricing.commissionForFee(24)).toBe(5); // 4.80 → floor
      expect(pricing.commissionForFee(25)).toBe(5); // 5.00 → equal
      expect(pricing.commissionForFee(26)).toBe(5.2); // 5.20 → percentage
    });

    it('charges nothing on a zero-fee order rather than the floor', () => {
      // A pickup the customer collects themselves was never charged for, so
      // there is no delivery fee to take a share of.
      expect(pricing.commissionForFee(0)).toBe(0);
    });

    it('treats a negative fee as zero instead of inverting the sign', () => {
      expect(pricing.commissionForFee(-40)).toBe(0);
    });
  });

  describe('the numbers are configuration, not constants', () => {
    it('follows a changed percentage', async () => {
      const service = await build({ [SettingKey.COMMISSION_PERCENT]: 30 });
      expect(service.commissionForFee(100)).toBe(30);
    });

    it('follows a changed floor', async () => {
      const service = await build({ [SettingKey.MIN_COMMISSION]: 8 });
      expect(service.commissionForFee(20)).toBe(8);
    });

    it('a zero floor turns the rule back into a plain percentage', async () => {
      const service = await build({ [SettingKey.MIN_COMMISSION]: 0 });
      expect(service.commissionForFee(20)).toBe(4);
    });
  });

  it('is taken from the delivery fee alone, never the goods', () => {
    // The driver buys the goods with their own money and is repaid in cash on
    // delivery, so that amount is not the platform's to take a share of. The
    // signature makes this structural: there is nowhere to pass a basket total.
    expect(pricing.commissionForFee(40)).toBe(8);
    expect(pricing.commissionForFee.length).toBe(1);
  });
});
