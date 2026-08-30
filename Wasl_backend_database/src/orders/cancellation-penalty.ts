import { CancellationInitiator } from './entities/order-cancellation-request.entity';

/**
 * What cancelling an accepted order costs the driver.
 *
 *     penalty = finalDeliveryFee × cancellationPenaltyPercent
 *
 * Three things this is **not**, each of them deliberate:
 *
 *  - **Not a share of the goods.** The purchase amount never enters. The driver
 *    buys those with their own cash and is repaid on delivery, so it is not the
 *    platform's to take a cut of — the same reasoning that keeps commission on
 *    the delivery fee alone.
 *  - **Not floored at 5 EGP.** That floor belongs to commission and only to
 *    commission. A 20 EGP delivery cancels for 4 EGP, not 5. Anything that
 *    reaches for `commissionForFee()` here is a bug.
 *  - **Not capped.**
 *
 * `initiatedBy` decides **whether** there is a penalty at all (Q-B3):
 *
 *  - **Driver cancels outright** (`DRIVER`) — they abandoned an order they had
 *    accepted, and the penalty applies.
 *  - **Driver approves a cancellation the customer asked for** (`CUSTOMER`) —
 *    **no penalty.** They are accommodating the customer, not abandoning the
 *    job, and charging them for saying yes would teach drivers to refuse every
 *    request and make the customer's only exit a driver who is paid to say no.
 *
 * Rejecting a request never reaches this function: the order simply continues
 * and no money moves. The two cases above are the only ones that charge.
 */
export function cancellationPenaltyFor(
  finalDeliveryFee: number,
  penaltyPercent: number,
  initiatedBy: CancellationInitiator,
): number {
  // Q-B3, approved: approving the customer's request is free for the driver.
  if (initiatedBy === CancellationInitiator.CUSTOMER) return 0;

  const fee = Math.max(0, Number(finalDeliveryFee) || 0);
  const percent = Math.max(0, Number(penaltyPercent) || 0);

  // A delivery that was never charged for owes nothing on cancellation.
  if (fee <= 0) return 0;

  return Math.round(((fee * percent) / 100) * 100) / 100;
}
