import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, Repository } from 'typeorm';

import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { SettingKey, SettingsService } from '../settings/settings.service';
import { PaymentsService } from '../payments/payments.service';
import { WalletTxType } from '../payments/entities/wallet-transaction.entity';
import { Order, OrderStatus } from './entities/order.entity';
import {
  CancellationAppealStatus,
  CancellationInitiator,
  CancellationStatus,
  OrderCancellationRequest,
} from './entities/order-cancellation-request.entity';
import { cancellationPenaltyFor } from './cancellation-penalty';
import { assertOrderParticipant } from './order-participation';
import { OrdersService } from './orders.service';
import {
  AppealCancellationDto,
  CreateCancellationRequestDto,
  DecideCancellationDto,
  DriverCancelOrderDto,
  ReviewCancellationDto,
} from './dto/cancellation.dto';

/**
 * States an accepted order may be cancelled from.
 *
 * `delivering` is deliberately absent. The driver is holding the goods and is
 * on the customer's doorstep; unwinding that is a support decision, not a
 * button. `completed` and `cancelled` are final and are excluded by being
 * absent too.
 */
export const CANCELLABLE_STATES: readonly OrderStatus[] = [
  OrderStatus.ACCEPTED,
  OrderStatus.AT_STORE,
  OrderStatus.ITEMS_BOUGHT,
];

/** Postgres unique-violation. */
const UNIQUE_VIOLATION = '23505';

/** A wallet ledger row as the admin review query returns it. */
export interface LedgerRow {
  id: number;
  driver_id: number;
  amount: string;
  type: string;
  balance_after: string;
  reference: string | null;
  created_at: Date;
}

function isUniqueViolation(error: unknown): boolean {
  return (error as { code?: string })?.code === UNIQUE_VIOLATION;
}

/**
 * Cancelling an accepted order, and the money that follows.
 *
 * Two doors into the same room:
 *
 *  - the **customer** opens a request and the assigned driver answers it;
 *  - the **driver** cancels outright.
 *
 * Both end in one `order_cancellation_requests` row and, when the order
 * actually cancels, one penalty debit against the driver's wallet. There is no
 * customer wallet anywhere in this file — the customer is never charged,
 * because there is nothing to charge.
 *
 * A driver who believes the customer caused it appeals, points at the order
 * chat as evidence, and an admin either upholds the charge or refunds it.
 * Nothing is refunded automatically.
 */
@Injectable()
export class OrderCancellationService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,

    @InjectRepository(OrderCancellationRequest)
    private readonly cancellationRepository: Repository<OrderCancellationRequest>,

    private readonly settings: SettingsService,
    private readonly ordersService: OrdersService,
  ) {}

  // ─── Customer opens a request ────────────────────────────────────────────

  /**
   * The customer asks to cancel an order a driver has already accepted.
   *
   * Nothing is cancelled here and no money moves: the driver may already be at
   * the shop, so they get to answer. Before acceptance the customer still
   * cancels outright through `OrdersService.cancelOrderByCustomer`, which is
   * free and needs nobody's permission.
   */
  async requestCancellation(
    orderId: number,
    user: AuthUser,
    dto: CreateCancellationRequestDto,
  ) {
    const order = await this.loadCancellableOrder(orderId, user, 'customer');

    // Asking twice is the same ask. Returning the open request beats a 409 the
    // app would have to special-case, and it cannot open a second one.
    const open = await this.cancellationRepository.findOne({
      where: { orderId, status: CancellationStatus.PENDING },
    });
    if (open) {
      return { success: true, repeated: true, data: open };
    }

    let request: OrderCancellationRequest;
    try {
      request = await this.cancellationRepository.save(
        this.cancellationRepository.create({
          orderId,
          requestedBy: user.sub,
          requestedByRole: CancellationInitiator.CUSTOMER,
          reason: dto.reason.trim(),
          status: CancellationStatus.PENDING,
          appealStatus: CancellationAppealStatus.NONE,
        }),
      );
    } catch (error) {
      if (isUniqueViolation(error)) {
        const existing = await this.cancellationRepository.findOne({
          where: { orderId, status: CancellationStatus.PENDING },
        });
        if (existing) return { success: true, repeated: true, data: existing };
      }
      throw error;
    }

    if (order.acceptedDriverId) {
      await this.ordersService.createNotification(
        order.acceptedDriverId,
        '⚠️ طلب إلغاء من العميل',
        `العميل طلب إلغاء الطلب FL-${orderId}. راجع السبب ووافق أو ارفض.`,
      );
    }

    return { success: true, repeated: false, data: request };
  }

  // ─── Driver answers it ───────────────────────────────────────────────────

  /**
   * The assigned driver approves or rejects the customer's request.
   *
   * Approving cancels the order and charges the penalty. Rejecting changes
   * nothing at all — the order continues and no money moves — but the request
   * and the refusal both stay on the record.
   */
  async decideCancellation(
    orderId: number,
    user: AuthUser,
    approve: boolean,
    dto: DecideCancellationDto,
  ) {
    await this.loadCancellableOrderForDecision(orderId, user);

    if (!approve) {
      const request = await this.requirePendingRequest(orderId);
      const now = new Date();
      await this.cancellationRepository.update(
        { id: request.id, status: CancellationStatus.PENDING },
        {
          status: CancellationStatus.REJECTED,
          decidedBy: user.sub,
          decidedAt: now,
          decisionReason: dto?.decisionReason?.trim() || null,
        },
      );

      const order = await this.orderRepository.findOne({
        where: { id: orderId },
      });
      await this.ordersService.createNotification(
        order!.customerId,
        'ℹ️ تم رفض طلب الإلغاء',
        `رفض الكابتن إلغاء الطلب FL-${orderId}، والطلب مستمر كالمعتاد.`,
      );

      // Same shape as the approve branch, so a caller never has to narrow a
      // union to discover that nothing was cancelled and nothing was charged.
      return {
        success: true,
        cancelled: false,
        repeated: false,
        penalty: 0,
        data: await this.cancellationRepository.findOne({
          where: { id: request.id },
        }),
      };
    }

    return this.cancelAndCharge(orderId, user, {
      initiatedBy: CancellationInitiator.CUSTOMER,
    });
  }

  // ─── Driver cancels outright ─────────────────────────────────────────────

  /**
   * The driver abandons an order they accepted.
   *
   * Its own route rather than a status transition: cancelling moves money, and
   * the generic status endpoint must never be a way to reach a state that
   * charges a wallet.
   */
  async driverCancel(
    orderId: number,
    user: AuthUser,
    dto: DriverCancelOrderDto,
  ) {
    await this.loadCancellableOrderForDecision(orderId, user);

    return this.cancelAndCharge(orderId, user, {
      initiatedBy: CancellationInitiator.DRIVER,
      reason: dto.reason.trim(),
    });
  }

  /**
   * The one path that cancels an order and charges for it.
   *
   * Everything happens inside a single transaction behind a row lock on the
   * order:
   *
   *  - the order must still be cancellable (re-checked under the lock, so two
   *    requests racing each other cannot both pass);
   *  - the penalty is computed from the fee **frozen on the order**, never from
   *    a number in the request;
   *  - the debit carries `order-<id>-cancel-penalty`, which is UNIQUE in the
   *    database.
   *
   * That last point is what makes a double tap harmless: two calls that both
   * pass every check still collide on the unique index, and the loser's
   * transaction — balance included — rolls back in full. The retry then sees a
   * cancelled order and returns the same answer instead of charging twice.
   */
  private async cancelAndCharge(
    orderId: number,
    user: AuthUser,
    options: { initiatedBy: CancellationInitiator; reason?: string },
  ) {
    try {
      const outcome = await this.orderRepository.manager.transaction(
        async (manager) => {
          const order = await manager.findOne(Order, {
            where: { id: orderId },
            lock: { mode: 'pessimistic_write' },
          });
          if (!order) throw new NotFoundException('الطلب غير موجود');

          // Already cancelled: a retry, not an error. Hand back what happened.
          if (order.status === OrderStatus.CANCELLED) {
            const existing = await manager.findOne(OrderCancellationRequest, {
              where: { orderId, status: CancellationStatus.APPROVED },
            });
            return { order, request: existing, repeated: true, penalty: 0 };
          }

          if (!CANCELLABLE_STATES.includes(order.status)) {
            throw new BadRequestException(
              order.status === OrderStatus.COMPLETED
                ? 'الطلب مكتمل بالفعل ولا يمكن إلغاؤه'
                : 'لا يمكن إلغاء الطلب في هذه المرحلة، تواصل مع الدعم',
            );
          }
          if (!order.acceptedDriverId) {
            throw new BadRequestException('هذا الطلب غير مسند لكابتن');
          }

          // 💰 From the order's own frozen fee, never from the request body.
          const penalty = cancellationPenaltyFor(
            Number(order.finalDeliveryFee),
            this.settings.getNumber(
              SettingKey.CANCELLATION_PENALTY_PERCENT,
              20,
            ),
            options.initiatedBy,
          );
          const penaltyReference = `order-${orderId}-cancel-penalty`;

          if (penalty > 0) {
            await PaymentsService.creditWithin(manager, {
              driverId: order.acceptedDriverId,
              amount: -penalty,
              type: WalletTxType.CANCELLATION_PENALTY,
              note: `غرامة إلغاء الطلب FL-${orderId}`,
              reference: penaltyReference,
              orderId,
            });
          }

          const now = new Date();
          const request = await this.upsertApprovedRequest(manager, {
            orderId,
            user,
            options,
            penalty,
            penaltyReference: penalty > 0 ? penaltyReference : null,
            now,
          });

          await manager.update(
            Order,
            { id: orderId },
            { status: OrderStatus.CANCELLED, cancelledAt: now },
          );

          return {
            order: { ...order, status: OrderStatus.CANCELLED },
            request,
            repeated: false,
            penalty,
          };
        },
      );

      if (!outcome.repeated) {
        await this.notifyCancelled(outcome.order, options.initiatedBy);
      }

      return {
        success: true,
        cancelled: true,
        repeated: outcome.repeated,
        penalty: outcome.penalty,
        data: outcome.request,
      };
    } catch (error) {
      // Lost a race against a concurrent cancellation: the winner already did
      // exactly this work, so report their result rather than a failure.
      if (isUniqueViolation(error)) {
        const settled = await this.cancellationRepository.findOne({
          where: { orderId, status: CancellationStatus.APPROVED },
        });
        if (settled) {
          return {
            success: true,
            cancelled: true,
            repeated: true,
            penalty: 0,
            data: settled,
          };
        }
        throw new ConflictException('تعذّر إلغاء الطلب، حاول مرة أخرى');
      }
      throw error;
    }
  }

  /**
   * Records the approved cancellation: closes the customer's open request if
   * there is one, otherwise writes the driver's own.
   */
  private async upsertApprovedRequest(
    manager: EntityManager,
    input: {
      orderId: number;
      user: AuthUser;
      options: { initiatedBy: CancellationInitiator; reason?: string };
      penalty: number;
      penaltyReference: string | null;
      now: Date;
    },
  ): Promise<OrderCancellationRequest> {
    const { orderId, user, options, penalty, penaltyReference, now } = input;

    const pending = await manager.findOne(OrderCancellationRequest, {
      where: { orderId, status: CancellationStatus.PENDING },
    });

    if (pending) {
      await manager.update(
        OrderCancellationRequest,
        { id: pending.id, status: CancellationStatus.PENDING },
        {
          status: CancellationStatus.APPROVED,
          decidedBy: user.sub,
          decidedAt: now,
          penaltyAmount: penalty,
          penaltyReference,
        },
      );
      return (await manager.findOne(OrderCancellationRequest, {
        where: { id: pending.id },
      }))!;
    }

    const created = manager.create(OrderCancellationRequest, {
      orderId,
      requestedBy: user.sub,
      requestedByRole: options.initiatedBy,
      reason: options.reason ?? 'إلغاء من الكابتن',
      status: CancellationStatus.APPROVED,
      decidedBy: user.sub,
      decidedAt: now,
      penaltyAmount: penalty,
      penaltyReference,
      appealStatus: CancellationAppealStatus.NONE,
    });
    return manager.save(created);
  }

  private async notifyCancelled(
    order: Pick<Order, 'id' | 'customerId' | 'acceptedDriverId'>,
    initiatedBy: CancellationInitiator,
  ) {
    await this.ordersService.createNotification(
      order.customerId,
      '❌ تم إلغاء الطلب',
      initiatedBy === CancellationInitiator.CUSTOMER
        ? `تم إلغاء طلبك FL-${order.id} بعد موافقة الكابتن.`
        : `اعتذر الكابتن عن تنفيذ طلبك FL-${order.id}. يمكنك إعادة الطلب.`,
    );
    if (order.acceptedDriverId) {
      await this.ordersService.createNotification(
        order.acceptedDriverId,
        '❌ تم إلغاء الطلب',
        `تم إلغاء الطلب FL-${order.id} وخُصمت غرامة الإلغاء من محفظتك. لو الإلغاء بسبب العميل، قدّم اعتراضاً وأرفق الأدلة من محادثة الطلب.`,
      );
    }
  }

  // ─── The driver disputes the penalty ─────────────────────────────────────

  /**
   * The driver asks an admin to look again.
   *
   * The evidence itself is not uploaded here: it is already in the order's
   * chat, which is append-only and readable by admins. This only opens the
   * review and records why.
   */
  async appeal(orderId: number, user: AuthUser, dto: AppealCancellationDto) {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });
    if (!order) throw new NotFoundException('الطلب غير موجود');
    assertOrderParticipant(order, user, 'driver');

    const request = await this.cancellationRepository.findOne({
      where: { orderId, status: CancellationStatus.APPROVED },
    });
    if (!request) {
      throw new NotFoundException('لا يوجد إلغاء على هذا الطلب');
    }
    if (!request.penaltyReference) {
      throw new BadRequestException('لم تُخصم غرامة على هذا الإلغاء');
    }
    if (request.appealStatus === CancellationAppealStatus.PENDING) {
      return { success: true, repeated: true, data: request };
    }
    if (request.appealStatus !== CancellationAppealStatus.NONE) {
      throw new ConflictException('تمت مراجعة هذا الاعتراض بالفعل');
    }

    await this.cancellationRepository.update(
      { id: request.id, appealStatus: CancellationAppealStatus.NONE },
      {
        appealStatus: CancellationAppealStatus.PENDING,
        appealReason: dto.reason.trim(),
        appealedAt: new Date(),
      },
    );

    return {
      success: true,
      repeated: false,
      data: await this.cancellationRepository.findOne({
        where: { id: request.id },
      }),
    };
  }

  // ─── Reading ─────────────────────────────────────────────────────────────

  /** The cancellation record on an order, for either party or an admin. */
  async getForOrder(orderId: number, user: AuthUser) {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });
    if (!order) throw new NotFoundException('الطلب غير موجود');
    assertOrderParticipant(order, user, 'any');

    const requests = await this.cancellationRepository.find({
      where: { orderId },
      order: { id: 'ASC' },
    });
    return { success: true, orderId, requests };
  }

  // ─── Admin review ────────────────────────────────────────────────────────

  /** The review queue. Defaults to appeals actually waiting on an admin. */
  async listForReview(appealStatus?: CancellationAppealStatus) {
    const requests = await this.cancellationRepository.find({
      where: appealStatus ? { appealStatus } : {},
      order: { createdAt: 'DESC' },
      take: 200,
    });
    return { success: true, count: requests.length, requests };
  }

  /**
   * Everything an admin needs to judge one cancellation: the record, the order
   * it belongs to, the money that moved, and the conversation that is the
   * evidence.
   */
  async getReviewDetail(id: number) {
    const request = await this.cancellationRepository.findOne({
      where: { id },
    });
    if (!request) throw new NotFoundException('سجل الإلغاء غير موجود');

    const order = await this.orderRepository.findOne({
      where: { id: request.orderId },
    });
    const transactions = await this.orderRepository.manager.query<LedgerRow[]>(
      `SELECT id, driver_id, amount, type, balance_after, reference, created_at
         FROM wallet_transactions WHERE order_id = $1 ORDER BY id ASC`,
      [request.orderId],
    );

    return {
      success: true,
      request,
      order,
      transactions,
      // The evidence lives in the order chat; admins already read it there.
      evidence: {
        messages: `/orders/${request.orderId}/chat/messages`,
        priceProposals: `/orders/${request.orderId}/chat/price-proposals`,
      },
    };
  }

  /**
   * The admin finds the customer at fault and gives the driver their money
   * back.
   *
   * Same discipline as the penalty: one transaction, and a UNIQUE reference
   * (`order-<id>-cancel-refund`) so a repeated click cannot credit twice.
   */
  async refundPenalty(id: number, admin: AuthUser, dto: ReviewCancellationDto) {
    if (admin.role !== UserRole.ADMIN) {
      throw new ForbiddenException('هذا الإجراء مخصص للإدارة');
    }

    try {
      const outcome = await this.orderRepository.manager.transaction(
        async (manager) => {
          const request = await manager.findOne(OrderCancellationRequest, {
            where: { id },
            lock: { mode: 'pessimistic_write' },
          });
          if (!request) throw new NotFoundException('سجل الإلغاء غير موجود');

          if (request.appealStatus === CancellationAppealStatus.REFUNDED) {
            // Already refunded: a retry. Uniform shape so the caller does not
            // have to narrow a union to find out nothing happened.
            return {
              request,
              repeated: true,
              driverId: null as number | null,
              penalty: 0,
            };
          }
          if (request.appealStatus === CancellationAppealStatus.UPHELD) {
            throw new ConflictException('تم رفض هذا الاعتراض بالفعل');
          }

          const penalty = Number(request.penaltyAmount) || 0;
          if (penalty <= 0 || !request.penaltyReference) {
            throw new BadRequestException('لا توجد غرامة قابلة للاسترداد');
          }

          const order = await manager.findOne(Order, {
            where: { id: request.orderId },
          });
          if (!order?.acceptedDriverId) {
            throw new BadRequestException('لا يوجد كابتن مرتبط بهذا الطلب');
          }

          const refundReference = `order-${request.orderId}-cancel-refund`;
          await PaymentsService.creditWithin(manager, {
            driverId: order.acceptedDriverId,
            amount: penalty,
            type: WalletTxType.PENALTY_REFUND,
            note: `استرداد غرامة إلغاء الطلب FL-${request.orderId}`,
            reference: refundReference,
            orderId: request.orderId,
          });

          const now = new Date();
          await manager.update(
            OrderCancellationRequest,
            { id: request.id, appealStatus: request.appealStatus },
            {
              appealStatus: CancellationAppealStatus.REFUNDED,
              reviewedBy: admin.sub,
              reviewedAt: now,
              reviewNote: dto?.note?.trim() || null,
              refundAmount: penalty,
              refundReference,
            },
          );

          return {
            request: (await manager.findOne(OrderCancellationRequest, {
              where: { id: request.id },
            }))!,
            repeated: false,
            driverId: order.acceptedDriverId,
            penalty,
          };
        },
      );

      if (!outcome.repeated && outcome.driverId != null) {
        await this.ordersService.createNotification(
          outcome.driverId,
          '✅ تم استرداد غرامة الإلغاء',
          `راجعت الإدارة اعتراضك على الطلب FL-${outcome.request.orderId} وأعادت ${outcome.penalty} ج.م إلى محفظتك.`,
        );
      }

      return {
        success: true,
        repeated: outcome.repeated,
        data: outcome.request,
      };
    } catch (error) {
      if (isUniqueViolation(error)) {
        const settled = await this.cancellationRepository.findOne({
          where: { id },
        });
        if (settled?.appealStatus === CancellationAppealStatus.REFUNDED) {
          return { success: true, repeated: true, data: settled };
        }
        throw new ConflictException('تعذّر تنفيذ الاسترداد، حاول مرة أخرى');
      }
      throw error;
    }
  }

  /** The admin finds the driver at fault. The charge stands; nothing moves. */
  async upholdPenalty(id: number, admin: AuthUser, dto: ReviewCancellationDto) {
    if (admin.role !== UserRole.ADMIN) {
      throw new ForbiddenException('هذا الإجراء مخصص للإدارة');
    }

    const request = await this.cancellationRepository.findOne({
      where: { id },
    });
    if (!request) throw new NotFoundException('سجل الإلغاء غير موجود');

    if (request.appealStatus === CancellationAppealStatus.UPHELD) {
      return { success: true, repeated: true, data: request };
    }
    if (request.appealStatus === CancellationAppealStatus.REFUNDED) {
      throw new ConflictException('تم استرداد هذه الغرامة بالفعل');
    }

    await this.cancellationRepository.update(
      { id: request.id, appealStatus: request.appealStatus },
      {
        appealStatus: CancellationAppealStatus.UPHELD,
        reviewedBy: admin.sub,
        reviewedAt: new Date(),
        reviewNote: dto?.note?.trim() || null,
      },
    );

    const order = await this.orderRepository.findOne({
      where: { id: request.orderId },
    });
    if (order?.acceptedDriverId) {
      await this.ordersService.createNotification(
        order.acceptedDriverId,
        'ℹ️ نتيجة مراجعة الاعتراض',
        `راجعت الإدارة اعتراضك على الطلب FL-${request.orderId} وتقرر بقاء الغرامة.`,
      );
    }

    return {
      success: true,
      repeated: false,
      data: await this.cancellationRepository.findOne({ where: { id } }),
    };
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  /** Loads an order the caller may open a cancellation request on. */
  private async loadCancellableOrder(
    orderId: number,
    user: AuthUser,
    as: 'customer' | 'driver',
    allowAlreadyCancelled = false,
  ): Promise<Order> {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });
    if (!order) throw new NotFoundException('الطلب غير موجود');
    assertOrderParticipant(order, user, as);

    // A driver retrying a cancellation that already went through is not an
    // error — the request simply arrives twice, and the transaction below
    // hands back what happened the first time. The customer's *request* path
    // does not get this leniency: asking to cancel a dead order is a mistake
    // worth reporting.
    if (allowAlreadyCancelled && order.status === OrderStatus.CANCELLED) {
      return order;
    }

    if (order.status === OrderStatus.PENDING_OFFERS) {
      throw new BadRequestException(
        'الطلب لم يُسند لكابتن بعد، يمكنك إلغاؤه مباشرة',
      );
    }
    if (!CANCELLABLE_STATES.includes(order.status)) {
      throw new BadRequestException(
        order.status === OrderStatus.CANCELLED
          ? 'الطلب ملغي بالفعل'
          : order.status === OrderStatus.COMPLETED
            ? 'الطلب مكتمل بالفعل'
            : 'لا يمكن طلب الإلغاء في هذه المرحلة، تواصل مع الدعم',
      );
    }
    return order;
  }

  /** Same, for the assigned driver deciding or cancelling. */
  private loadCancellableOrderForDecision(orderId: number, user: AuthUser) {
    return this.loadCancellableOrder(orderId, user, 'driver', true);
  }

  private async requirePendingRequest(
    orderId: number,
  ): Promise<OrderCancellationRequest> {
    const request = await this.cancellationRepository.findOne({
      where: { orderId, status: CancellationStatus.PENDING },
    });
    if (!request) {
      throw new NotFoundException('لا يوجد طلب إلغاء بانتظار الرد');
    }
    return request;
  }
}
