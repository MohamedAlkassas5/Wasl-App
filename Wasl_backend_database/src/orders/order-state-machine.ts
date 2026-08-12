import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { OrderStatus } from './entities/order.entity';
import { UserRole } from '../users/entities/user.entity';

/** Who is allowed to drive a transition. */
export type TransitionActor = 'customer' | 'driver';

interface Transition {
  to: OrderStatus;
  by: TransitionActor;
  /** Shown when someone tries this move from the wrong state. */
  label: string;
}

/**
 * The whole order lifecycle, in one table.
 *
 * Everything the backend will accept is here and nowhere else. The previous
 * implementation took a status straight off the query string and assigned it —
 * any caller could jump an order from `accepted` to `completed`, skipping the
 * pickup entirely, or re-complete a finished order and be charged commission
 * again. Enumerating the legal moves is what makes those impossible rather
 * than merely unlikely.
 *
 * Two shapes of order share this graph. Ones that involve buying something
 * (restaurant, pharmacy, store) run `accepted → at_store → items_bought →
 * delivering`. A straight courier run (Waslly) has nothing to buy, so it goes
 * `accepted → delivering` directly. Both are legal edges out of `accepted`;
 * neither is forced on the other, which is why the graph doesn't need an order
 * "type" discriminator yet — that arrives with the per-type contracts in a
 * later checkpoint.
 *
 * `completed` and `cancelled` have no outgoing edges. They are final.
 */
const TRANSITIONS: Record<OrderStatus, Transition[]> = {
  [OrderStatus.PENDING_OFFERS]: [
    { to: OrderStatus.ACCEPTED, by: 'driver', label: 'قبول الطلب' },
    { to: OrderStatus.CANCELLED, by: 'customer', label: 'إلغاء الطلب' },
  ],
  [OrderStatus.ACCEPTED]: [
    { to: OrderStatus.AT_STORE, by: 'driver', label: 'الوصول للمحل' },
    // Courier runs have no shop to visit.
    { to: OrderStatus.DELIVERING, by: 'driver', label: 'بدء التوصيل' },
  ],
  [OrderStatus.AT_STORE]: [
    { to: OrderStatus.ITEMS_BOUGHT, by: 'driver', label: 'شراء المنتجات' },
  ],
  [OrderStatus.ITEMS_BOUGHT]: [
    { to: OrderStatus.DELIVERING, by: 'driver', label: 'بدء التوصيل' },
  ],
  // Completion is not reachable through the generic status route at all — it
  // moves money, so it has its own endpoint. See OrdersService.completeOrder.
  [OrderStatus.DELIVERING]: [],
  [OrderStatus.COMPLETED]: [],
  [OrderStatus.CANCELLED]: [],
};

/** States after which an order is a historical record, not a live thing. */
export const FINAL_STATES: readonly OrderStatus[] = [
  OrderStatus.COMPLETED,
  OrderStatus.CANCELLED,
];

export function isFinalState(status: OrderStatus): boolean {
  return FINAL_STATES.includes(status);
}

/** The state an order must be in before it can be delivered. */
export const COMPLETABLE_FROM = OrderStatus.DELIVERING;

/** Human-readable states reachable from here — used in error messages. */
export function allowedNextStates(from: OrderStatus): OrderStatus[] {
  return TRANSITIONS[from].map((t) => t.to);
}

/**
 * Checks a requested move and explains the refusal when there is one.
 *
 * `actor` is what the caller *is* relative to this order (its customer, its
 * assigned driver), already established from the token — not what they claim.
 * An admin may drive any transition the graph allows, but the graph still
 * applies: an administrator cannot teleport an order to `completed` either,
 * because that would bypass settlement.
 */
export function assertTransitionAllowed(
  from: OrderStatus,
  to: OrderStatus,
  actor: TransitionActor,
  role: UserRole,
): void {
  if (!Object.values(OrderStatus).includes(to)) {
    throw new BadRequestException('حالة الطلب غير صالحة');
  }

  if (isFinalState(from)) {
    throw new BadRequestException(
      from === OrderStatus.COMPLETED
        ? 'الطلب مكتمل بالفعل ولا يمكن تعديله'
        : 'الطلب ملغي ولا يمكن تعديله',
    );
  }

  const transition = TRANSITIONS[from].find((t) => t.to === to);
  if (!transition) {
    const options = allowedNextStates(from);
    throw new BadRequestException(
      options.length === 0
        ? 'لا يمكن تغيير حالة الطلب من هنا'
        : `لا يمكن الانتقال من "${from}" إلى "${to}". المسموح: ${options.join('، ')}`,
    );
  }

  // Admins act on behalf of either party, but only along a legal edge.
  if (role === UserRole.ADMIN) return;

  if (transition.by !== actor) {
    throw new ForbiddenException(
      transition.by === 'driver'
        ? 'هذا الإجراء مخصص للكابتن المسند له الطلب'
        : 'هذا الإجراء مخصص لصاحب الطلب',
    );
  }
}
