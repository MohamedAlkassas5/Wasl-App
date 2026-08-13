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
 * `initiatedBy` is accepted but does not change the figure today: a driver who
 * approves a customer's cancellation request is charged exactly as a driver who
 * cancels outright, per the approved rules. It is a parameter rather than an
 * omission because that is the one thing most likely to change — a driver who
 * approves a request the customer opened has an obvious argument for paying
 * less — and this function is the single place that decision lives.
 */
export function cancellationPenaltyFor(
  finalDeliveryFee: number,
  penaltyPercent: number,
  initiatedBy: CancellationInitiator,
): number {
  void initiatedBy;

  const fee = Math.max(0, Number(finalDeliveryFee) || 0);
  const percent = Math.max(0, Number(penaltyPercent) || 0);

  // A delivery that was never charged for owes nothing on cancellation.
  if (fee <= 0) return 0;

  return Math.round(((fee * percent) / 100) * 100) / 100;
}
