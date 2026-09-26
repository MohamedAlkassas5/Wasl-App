import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { DeliveryService } from './delivery.service';
import { DeliveryController } from './delivery.controller';
import {
  DeliveryPartner,
  VehicleType,
  DeliveryVerificationStatus,
} from './entities/delivery-partner.entity';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';

/**
 * "بيانات المركبة" — the driver reading and editing their own vehicle.
 *
 * The Settings item behind this was a dead `onTap: () {}` because nothing on
 * the server would answer it. These pin the two properties that matter now
 * that something does:
 *
 *   1. the driver acts on **their own** row, taken from the token; and
 *   2. the route hands back — and accepts — only vehicle fields. The same
 *      table holds the wallet balance, the live GPS fix, the admin's private
 *      notes and the verification verdict, and none of those may leak out of
 *      or be written through a "my vehicle" screen.
 */
describe('driver vehicle details', () => {
  const buildService = (row?: Partial<DeliveryPartner>) => {
    const stored: Partial<DeliveryPartner> = row
      ? { ...row }
      : {
          userId: 7,
          vehicleType: VehicleType.MOTORCYCLE,
          licenseNumber: 'ABC 123',
          vehicleImage: 'uploads/vehicle-7.jpg',
          verificationStatus: DeliveryVerificationStatus.APPROVED,
          // Everything below must never surface on this route.
          balance: 250.75,
          isOnline: true,
          adminNotes: 'ملاحظة داخلية للإدارة',
          currentLatitude: 30.76,
          currentLongitude: 30.69,
          nationalIdFront: 'uploads/id-front-7.jpg',
          selfie: 'uploads/selfie-7.jpg',
        };

    const repository = {
      findOne: ({ where }: { where: { userId: number } }) =>
        Promise.resolve(where.userId === stored.userId ? stored : null),
      save: (patched: Partial<DeliveryPartner>) => {
        Object.assign(stored, patched);
        return Promise.resolve(stored);
      },
    };

    return {
      stored,
      service: new DeliveryService(repository as never, {} as never),
    };
  };

  describe('reading', () => {
    it('returns the vehicle fields', async () => {
      const { service } = buildService();

      const result = await service.getMyVehicle(7);

      expect(result).toMatchObject({
        success: true,
        vehicleType: VehicleType.MOTORCYCLE,
        licenseNumber: 'ABC 123',
        vehicleImage: 'uploads/vehicle-7.jpg',
        verificationStatus: DeliveryVerificationStatus.APPROVED,
      });
    });

    it('leaks nothing else from the partner row', async () => {
      const { service } = buildService();

      const result = await service.getMyVehicle(7);

      expect(Object.keys(result).sort()).toEqual([
        'licenseNumber',
        'success',
        'vehicleImage',
        'vehicleType',
        'verificationStatus',
      ]);
      const serialised = JSON.stringify(result);
      expect(serialised).not.toContain('250.75'); // balance
      expect(serialised).not.toContain('ملاحظة داخلية'); // admin notes
      expect(serialised).not.toContain('30.76'); // live location
      expect(serialised).not.toContain('selfie-7'); // identity documents
    });

    it('reports a missing driver rather than an empty vehicle', async () => {
      const { service } = buildService();
      await expect(service.getMyVehicle(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe('editing', () => {
    it('saves a new vehicle type and plate number', async () => {
      const { service, stored } = buildService();

      const result = await service.updateMyVehicle(7, {
        vehicleType: VehicleType.CAR,
        licenseNumber: 'XYZ 999',
      });

      expect(stored.vehicleType).toBe(VehicleType.CAR);
      expect(stored.licenseNumber).toBe('XYZ 999');
      expect(result).toMatchObject({
        success: true,
        vehicleType: VehicleType.CAR,
        licenseNumber: 'XYZ 999',
      });
    });

    it('changes only the field that was sent', async () => {
      const { service, stored } = buildService();

      await service.updateMyVehicle(7, { licenseNumber: 'NEW 1' });

      expect(stored.licenseNumber).toBe('NEW 1');
      expect(stored.vehicleType).toBe(VehicleType.MOTORCYCLE);
    });

    it('trims the plate, and an empty one clears it', async () => {
      const { service, stored } = buildService();

      await service.updateMyVehicle(7, { licenseNumber: '  P 55  ' });
      expect(stored.licenseNumber).toBe('P 55');

      await service.updateMyVehicle(7, { licenseNumber: '   ' });
      expect(stored.licenseNumber).toBeUndefined();
    });

    it('rejects an edit that changes nothing', async () => {
      const { service } = buildService();
      await expect(service.updateMyVehicle(7, {})).rejects.toThrow(
        BadRequestException,
      );
    });

    it('never touches the verification verdict, balance or admin notes', async () => {
      const { service, stored } = buildService();

      // What a tampered client would send. The DTO whitelist drops these
      // before the service sees them; this asserts the service would not
      // honour them even if they arrived.
      await service.updateMyVehicle(7, {
        vehicleType: VehicleType.CAR,
        verificationStatus: DeliveryVerificationStatus.APPROVED,
        balance: 99999,
        isOnline: true,
        adminNotes: 'approved by me',
        vehicleImage: 'uploads/someone-elses.jpg',
      } as UpdateVehicleDto);

      expect(stored.balance).toBe(250.75);
      expect(stored.adminNotes).toBe('ملاحظة داخلية للإدارة');
      expect(stored.vehicleImage).toBe('uploads/vehicle-7.jpg');
      expect(stored.verificationStatus).toBe(
        DeliveryVerificationStatus.APPROVED,
      );
    });

    it('a pending driver cannot approve themselves through this route', async () => {
      const { service, stored } = buildService({
        userId: 7,
        vehicleType: VehicleType.MOTORCYCLE,
        verificationStatus: DeliveryVerificationStatus.PENDING,
      });

      await service.updateMyVehicle(7, {
        vehicleType: VehicleType.CAR,
        verificationStatus: DeliveryVerificationStatus.APPROVED,
      } as UpdateVehicleDto);

      expect(stored.verificationStatus).toBe(
        DeliveryVerificationStatus.PENDING,
      );
    });

    it('reports a missing driver', async () => {
      const { service } = buildService();
      await expect(
        service.updateMyVehicle(999, { vehicleType: VehicleType.CAR }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('authorization', () => {
    it('the controller is behind the JWT guard', () => {
      const guards = Reflect.getMetadata(
        '__guards__',
        DeliveryController,
      ) as unknown[];
      const names = guards.map((g: never) =>
        (g as { name?: string }).name
          ? (g as { name: string }).name
          : (g as object).constructor.name,
      );
      expect(names).toContain(JwtAuthGuard.name);
    });

    it('acts on the token holder, with no id to tamper with', async () => {
      const seen: number[] = [];
      const service = {
        getMyVehicle: (id: number) => {
          seen.push(id);
          return Promise.resolve({ success: true });
        },
        updateMyVehicle: (id: number) => {
          seen.push(id);
          return Promise.resolve({ success: true });
        },
      } as unknown as DeliveryService;

      const controller = new DeliveryController(service);
      const user = { sub: 7, role: 'delivery' } as never;

      await controller.getMyVehicle(user);
      // A body naming another driver — it has nowhere to go.
      await controller.updateMyVehicle(user, {
        vehicleType: VehicleType.CAR,
        userId: 9,
      } as never);

      expect(seen).toEqual([7, 7]);
    });
  });
});
