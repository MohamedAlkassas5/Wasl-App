import { BadRequestException, ForbiddenException } from '@nestjs/common';

import {
  allowedNextStates,
  assertTransitionAllowed,
  isFinalState,
} from './order-state-machine';
import { OrderStatus } from './entities/order.entity';
import { UserRole } from '../users/entities/user.entity';

/**
 * The transition graph on its own.
 *
 * The old implementation assigned whatever status arrived on the query string,
 * so an order could go straight from `accepted` to `completed` — skipping the
 * pickup and triggering settlement for a delivery that never happened — and a
 * finished order could be completed repeatedly. These tests pin the edges that
 * exist and, more importantly, the ones that do not.
 */
describe('order state machine', () => {
  const asDriver = (from: OrderStatus, to: OrderStatus) =>
    assertTransitionAllowed(from, to, 'driver', UserRole.DELIVERY);
  const asCustomer = (from: OrderStatus, to: OrderStatus) =>
    assertTransitionAllowed(from, to, 'customer', UserRole.CUSTOMER);

  describe('valid moves', () => {
    it('a driver accepts a waiting order', () => {
      expect(() =>
        asDriver(OrderStatus.PENDING_OFFERS, OrderStatus.ACCEPTED),
      ).not.toThrow();
    });

    it('a shopping order goes accepted → at_store → items_bought → delivering', () => {
      expect(() =>
        asDriver(OrderStatus.ACCEPTED, OrderStatus.AT_STORE),
      ).not.toThrow();
      expect(() =>
        asDriver(OrderStatus.AT_STORE, OrderStatus.ITEMS_BOUGHT),
      ).not.toThrow();
      expect(() =>
        asDriver(OrderStatus.ITEMS_BOUGHT, OrderStatus.DELIVERING),
      ).not.toThrow();
    });

    it('a courier run skips the shop: accepted → delivering', () => {
      // Waslly has nothing to buy, so forcing it through at_store would be a
      // stage that does not exist for that order type.
      expect(() =>
        asDriver(OrderStatus.ACCEPTED, OrderStatus.DELIVERING),
      ).not.toThrow();
    });

    it('a customer cancels while the order is still waiting', () => {
      expect(() =>
        asCustomer(OrderStatus.PENDING_OFFERS, OrderStatus.CANCELLED),
      ).not.toThrow();
    });
  });

  describe('invalid moves', () => {
    it('refuses to jump from accepted straight to completed', () => {
      expect(() =>
        asDriver(OrderStatus.ACCEPTED, OrderStatus.COMPLETED),
      ).toThrow(BadRequestException);
    });

    it('refuses to jump from a waiting order straight to completed', () => {
      expect(() =>
        asDriver(OrderStatus.PENDING_OFFERS, OrderStatus.COMPLETED),
      ).toThrow(BadRequestException);
    });

    it('refuses to buy items before reaching the shop', () => {
      expect(() =>
        asDriver(OrderStatus.ACCEPTED, OrderStatus.ITEMS_BOUGHT),
      ).toThrow(BadRequestException);
    });

    it('refuses to go backwards', () => {
      expect(() =>
        asDriver(OrderStatus.DELIVERING, OrderStatus.ACCEPTED),
      ).toThrow(BadRequestException);
    });

    it('rejects a status value that is not in the enum at all', () => {
      expect(() =>
        asDriver(OrderStatus.ACCEPTED, 'delivered_lol' as OrderStatus),
      ).toThrow(BadRequestException);
    });

    it('names the legal options so the client can recover', () => {
      expect(() =>
        asDriver(OrderStatus.ACCEPTED, OrderStatus.COMPLETED),
      ).toThrow(/at_store|delivering/);
    });
  });

  describe('final states are final', () => {
    it.each([OrderStatus.COMPLETED, OrderStatus.CANCELLED])(
      '%s accepts no further transition',
      (state) => {
        expect(isFinalState(state)).toBe(true);
        expect(allowedNextStates(state)).toHaveLength(0);
        for (const to of Object.values(OrderStatus)) {
          expect(() => asDriver(state, to)).toThrow(BadRequestException);
        }
      },
    );

    it('a completed order cannot be re-completed', () => {
      expect(() =>
        asDriver(OrderStatus.COMPLETED, OrderStatus.COMPLETED),
      ).toThrow(BadRequestException);
    });

    it('a cancelled order cannot be revived', () => {
      expect(() =>
        asDriver(OrderStatus.CANCELLED, OrderStatus.ACCEPTED),
      ).toThrow(BadRequestException);
    });
  });

  describe('role authorization', () => {
    it('a customer cannot perform a driver move', () => {
      expect(() =>
        asCustomer(OrderStatus.ACCEPTED, OrderStatus.DELIVERING),
      ).toThrow(ForbiddenException);
    });

    it('a driver cannot cancel on the customer’s behalf', () => {
      expect(() =>
        asDriver(OrderStatus.PENDING_OFFERS, OrderStatus.CANCELLED),
      ).toThrow(ForbiddenException);
    });

    it('an admin may drive either side of a legal edge', () => {
      expect(() =>
        assertTransitionAllowed(
          OrderStatus.ACCEPTED,
          OrderStatus.DELIVERING,
          'customer',
          UserRole.ADMIN,
        ),
      ).not.toThrow();
    });

    it('but an admin still cannot use an illegal edge', () => {
      // Otherwise an administrator could teleport an order to completed and
      // bypass settlement entirely.
      expect(() =>
        assertTransitionAllowed(
          OrderStatus.ACCEPTED,
          OrderStatus.COMPLETED,
          'driver',
          UserRole.ADMIN,
        ),
      ).toThrow(BadRequestException);
    });
  });

  it('completion is not reachable through the generic transition path', () => {
    // It moves money, so it lives behind its own endpoint.
    for (const from of Object.values(OrderStatus)) {
      expect(allowedNextStates(from)).not.toContain(OrderStatus.COMPLETED);
    }
  });
});
