import { cancellationPenaltyFor } from './cancellation-penalty';
import { CancellationInitiator } from './entities/order-cancellation-request.entity';

const BY_DRIVER = CancellationInitiator.DRIVER;
const BY_CUSTOMER = CancellationInitiator.CUSTOMER;

/**
 * The approved rule, pinned exactly:
 *
 *     penalty = finalDeliveryFee × 20%,  no floor, no cap
 *
 * The floor is the trap. Commission is `max(fee × 20%, 5)` and lives two files
 * away; wiring the penalty through it would look right and silently overcharge
 * every cheap trip. The 20 EGP case below is the test that fails if anyone does.
 */
describe('cancellation penalty', () => {
  const PERCENT = 20;

  it('is 20% of the delivery fee — the approved worked example', () => {
    expect(cancellationPenaltyFor(40, PERCENT, BY_DRIVER)).toBe(8);
  });

  it('has NO 5 EGP floor: a 20 EGP delivery cancels for 4, not 5', () => {
    // commissionForFee(20) would be max(4, 5) = 5. The penalty is not that.
    expect(cancellationPenaltyFor(20, PERCENT, BY_DRIVER)).toBe(4);
  });

  it('stays under the commission floor all the way down', () => {
    expect(cancellationPenaltyFor(10, PERCENT, BY_DRIVER)).toBe(2);
    expect(cancellationPenaltyFor(5, PERCENT, BY_DRIVER)).toBe(1);
    expect(cancellationPenaltyFor(1, PERCENT, BY_DRIVER)).toBe(0.2);
  });

  it('has no cap', () => {
    expect(cancellationPenaltyFor(500, PERCENT, BY_DRIVER)).toBe(100);
    expect(cancellationPenaltyFor(10_000, PERCENT, BY_DRIVER)).toBe(2000);
  });

  // ── Q-B3, approved: approving the customer's request costs the driver
  // nothing. Only abandoning an order they accepted does.
  describe('who asked for the cancellation (Q-B3)', () => {
    it('charges nothing when the driver approves the customer’s request', () => {
      expect(cancellationPenaltyFor(40, PERCENT, BY_CUSTOMER)).toBe(0);
    });

    it('still charges the driver who cancels outright', () => {
      expect(cancellationPenaltyFor(40, PERCENT, BY_DRIVER)).toBe(8);
    });

    it('is free for the customer-approved case at every fee', () => {
      // Not a rounding artefact of one number: nothing is charged at all.
      [1, 5, 20, 40, 500, 10_000].forEach((fee) => {
        expect(cancellationPenaltyFor(fee, PERCENT, BY_CUSTOMER)).toBe(0);
      });
    });

    it('is free even at a percentage that would otherwise bite', () => {
      expect(cancellationPenaltyFor(40, 100, BY_CUSTOMER)).toBe(0);
      // …and the driver-initiated case at the same percentage is not free,
      // so this pair fails if the branch is ever dropped.
      expect(cancellationPenaltyFor(40, 100, BY_DRIVER)).toBe(40);
    });
  });

  it('ignores the purchase amount entirely — it is not a parameter', () => {
    // The function cannot see itemsPrice. This documents the contract: a
    // 300 EGP pharmacy run and a 0 EGP one cancel for the same 8 EGP.
    expect(cancellationPenaltyFor.length).toBe(3);
    expect(cancellationPenaltyFor(40, PERCENT, BY_DRIVER)).toBe(8);
  });

  it('rounds to piastres', () => {
    expect(cancellationPenaltyFor(33.33, PERCENT, BY_DRIVER)).toBe(6.67);
    expect(cancellationPenaltyFor(12.5, PERCENT, BY_DRIVER)).toBe(2.5);
  });

  it('charges nothing for a delivery that was never charged for', () => {
    expect(cancellationPenaltyFor(0, PERCENT, BY_DRIVER)).toBe(0);
  });

  it('treats a missing or nonsense fee as zero rather than NaN', () => {
    expect(
      cancellationPenaltyFor(
        undefined as unknown as number,
        PERCENT,
        BY_DRIVER,
      ),
    ).toBe(0);
    expect(
      cancellationPenaltyFor(null as unknown as number, PERCENT, BY_DRIVER),
    ).toBe(0);
    expect(cancellationPenaltyFor(-40, PERCENT, BY_DRIVER)).toBe(0);
  });

  it('reads the percentage from configuration rather than hardcoding it', () => {
    expect(cancellationPenaltyFor(40, 10, BY_DRIVER)).toBe(4);
    expect(cancellationPenaltyFor(40, 0, BY_DRIVER)).toBe(0);
  });

  it('accepts the numeric strings Postgres returns for decimal columns', () => {
    expect(
      cancellationPenaltyFor('40.00' as unknown as number, PERCENT, BY_DRIVER),
    ).toBe(8);
  });
});
