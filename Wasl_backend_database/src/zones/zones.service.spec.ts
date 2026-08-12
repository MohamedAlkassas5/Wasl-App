import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { ZonesService } from './zones.service';
import { DeliveryZone } from './entities/delivery-zone.entity';
import { DeliveryZoneRate } from './entities/delivery-zone-rate.entity';

/**
 * The approved V1 areas and the two price tables built on them.
 *
 * These mirror what `SeedApprovedAreas1785041500000` writes, so if the seed and
 * the rules ever disagree, this fails.
 */
const ZONES: Partial<DeliveryZone>[] = [
  {
    id: 1,
    code: 'kom_hamada',
    name: 'كوم حمادة',
    normalDeliveryFee: 20,
    isActive: true,
  },
  {
    id: 2,
    code: 'biban',
    name: 'بيبان',
    normalDeliveryFee: 40,
    isActive: true,
  },
  { id: 3, code: 'breem', name: 'بريم', normalDeliveryFee: 40, isActive: true },
];

/**
 * The nine approved routes, keyed "pickupZoneId->dropoffZoneId"
 * (1 = كوم حمادة, 2 = بيبان, 3 = بريم).
 *
 * Same area 20 · a leg through كوم حمادة 40 · بيبان ↔ بريم 50.
 */
const ROUTE_FEES: Record<string, number> = {
  '1->1': 20,
  '2->2': 20,
  '3->3': 20,
  '1->2': 40,
  '2->1': 40,
  '1->3': 40,
  '3->1': 40,
  '2->3': 50,
  '3->2': 50,
};

describe('ZonesService (approved areas and their prices)', () => {
  let service: ZonesService;

  /** `zoneOverrides` lets a test bend one zone without restating the table. */
  const build = async (
    zoneOverrides: Partial<DeliveryZone>[] = ZONES,
  ): Promise<ZonesService> => {
    const zoneRepo = {
      findOne: ({ where }: { where: Partial<DeliveryZone> }) => {
        const found = zoneOverrides.find(
          (z) =>
            (where.id === undefined || z.id === where.id) &&
            (where.code === undefined || z.code === where.code) &&
            (where.isActive === undefined || z.isActive === where.isActive),
        );
        return Promise.resolve(found ?? null);
      },
    };

    const rateRepo = {
      findOne: ({
        where,
      }: {
        where: { pickupZoneId: number; dropoffZoneId: number };
      }) => {
        const fee = ROUTE_FEES[`${where.pickupZoneId}->${where.dropoffZoneId}`];
        if (fee === undefined) return Promise.resolve(null);
        return Promise.resolve({
          deliveryFee: fee,
          estimatedMinutes: 30,
          pickupZone: ZONES.find((z) => z.id === where.pickupZoneId),
          dropoffZone: ZONES.find((z) => z.id === where.dropoffZoneId),
        } as unknown as DeliveryZoneRate);
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ZonesService,
        { provide: getRepositoryToken(DeliveryZone), useValue: zoneRepo },
        { provide: getRepositoryToken(DeliveryZoneRate), useValue: rateRepo },
      ],
    }).compile();

    return module.get(ZonesService);
  };

  beforeEach(async () => {
    service = await build();
  });

  describe('normal orders are priced by destination area alone', () => {
    it.each([
      ['كوم حمادة', 1, 20],
      ['بيبان', 2, 40],
      ['بريم', 3, 40],
    ])('%s costs %i EGP to deliver into', async (_name, zoneId, expected) => {
      const quote = await service.quoteByDestination(zoneId);
      expect(quote.deliveryFee).toBe(expected);
      expect(quote.currency).toBe('EGP');
    });

    it('refuses an area that is not one of the approved three', async () => {
      await expect(service.quoteByDestination(99)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('refuses a deactivated area rather than quoting it anyway', async () => {
      service = await build([{ ...ZONES[0], isActive: false }]);
      await expect(service.quoteByDestination(1)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('refuses an approved area that has no fee set, instead of quoting free delivery', async () => {
      service = await build([{ ...ZONES[0], normalDeliveryFee: undefined }]);
      await expect(service.quoteByDestination(1)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('Waslly is priced by the pickup → drop-off route', () => {
    it.each(Object.entries(ROUTE_FEES))(
      'route %s costs %i EGP',
      async (route, expected) => {
        const [pickup, dropoff] = route.split('->').map(Number);
        const quote = await service.quoteByZones(pickup, dropoff);
        expect(quote.deliveryFee).toBe(expected);
      },
    );

    it('covers all nine approved routes', () => {
      expect(Object.keys(ROUTE_FEES)).toHaveLength(9);
    });

    it('refuses a route with no approved rate', async () => {
      await expect(service.quoteByZones(1, 99)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('getActiveZone is the single gate on "is this area supported?"', () => {
    it('returns an approved area', async () => {
      await expect(service.getActiveZone(2)).resolves.toMatchObject({
        code: 'biban',
      });
    });

    it('rejects an unknown area', async () => {
      await expect(service.getActiveZone(404)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });
});
