import { ForbiddenException } from '@nestjs/common';

import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

/** Which side of an order the caller must be on. */
export type OrderRelation = 'customer' | 'driver' | 'any';

/** The parts of an order that decide who may touch it. */
export interface OrderParties {
  customerId: number;
  acceptedDriverId?: number | null;
}

/**
 * Is this caller a party to this order?
 *
 * The only two participants are the customer who placed it and the driver it
 * was assigned to. A driver merely browsing the marketplace is **not** a
 * participant — they have no relationship to the order until they are assigned.
 */
export function isOrderParticipant(
  order: OrderParties,
  user: AuthUser,
  as: OrderRelation = 'any',
): boolean {
  if (user.role === UserRole.ADMIN) return true;

  const isCustomer = Number(order.customerId) === Number(user.sub);
  const isDriver =
    order.acceptedDriverId != null &&
    Number(order.acceptedDriverId) === Number(user.sub);

  if (as === 'customer') return isCustomer;
  if (as === 'driver') return isDriver;
  return isCustomer || isDriver;
}

/**
 * Throwing form of {@link isOrderParticipant}.
 *
 * Extracted so order routes and chat routes cannot drift into two different
 * ideas of who is allowed on an order — there is one rule, in one place, and
 * both call it.
 */
export function assertOrderParticipant(
  order: OrderParties,
  user: AuthUser,
  as: OrderRelation = 'any',
): void {
  if (!isOrderParticipant(order, user, as)) {
    throw new ForbiddenException('عفواً، هذا الطلب لا يخصك');
  }
}
