import { ForbiddenException } from '@nestjs/common';

import {
  assertOrderParticipant,
  isOrderParticipant,
} from './order-participation';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

/**
 * One rule decides who may touch an order, and both the order routes and the
 * chat routes call it. These pin the rule itself, so the two can never drift
 * into disagreeing about who a participant is.
 */
describe('order participation', () => {
  const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
  const ASSIGNED_DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
  const OTHER_DRIVER: AuthUser = { sub: 21, role: UserRole.DELIVERY };
  const ADMIN: AuthUser = { sub: 1, role: UserRole.ADMIN };

  const order = { customerId: 10, acceptedDriverId: 20 };
  const unassigned = { customerId: 10, acceptedDriverId: null };

  it('accepts the order’s customer', () => {
    expect(isOrderParticipant(order, CUSTOMER)).toBe(true);
    expect(isOrderParticipant(order, CUSTOMER, 'customer')).toBe(true);
  });

  it('accepts the assigned driver', () => {
    expect(isOrderParticipant(order, ASSIGNED_DRIVER)).toBe(true);
    expect(isOrderParticipant(order, ASSIGNED_DRIVER, 'driver')).toBe(true);
  });

  it('refuses a driver who was never assigned this order', () => {
    expect(isOrderParticipant(order, OTHER_DRIVER)).toBe(false);
    expect(() => assertOrderParticipant(order, OTHER_DRIVER)).toThrow(
      ForbiddenException,
    );
  });

  it('refuses a driver on an order that has no driver yet', () => {
    expect(isOrderParticipant(unassigned, ASSIGNED_DRIVER)).toBe(false);
  });

  it('does not let the customer act in the driver’s role, or the reverse', () => {
    expect(isOrderParticipant(order, CUSTOMER, 'driver')).toBe(false);
    expect(isOrderParticipant(order, ASSIGNED_DRIVER, 'customer')).toBe(false);
  });

  it('lets an admin through in every role', () => {
    expect(isOrderParticipant(order, ADMIN, 'customer')).toBe(true);
    expect(isOrderParticipant(order, ADMIN, 'driver')).toBe(true);
    expect(isOrderParticipant(unassigned, ADMIN)).toBe(true);
  });

  it('compares ids by value, not by type', () => {
    const stringy = { customerId: '10' as unknown as number };
    expect(isOrderParticipant(stringy, CUSTOMER)).toBe(true);
  });
});
