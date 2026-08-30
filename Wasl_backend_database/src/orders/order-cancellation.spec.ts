import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';

import { OrderCancellationService } from './order-cancellation.service';
import { Order, OrderStatus } from './entities/order.entity';
import {
  CancellationAppealStatus,
  CancellationInitiator,
  CancellationStatus,
  OrderCancellationRequest,
} from './entities/order-cancellation-request.entity';
import { WalletTxType } from '../payments/entities/wallet-transaction.entity';
import { PaymentsService } from '../payments/payments.service';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
const DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
const OTHER_DRIVER: AuthUser = { sub: 21, role: UserRole.DELIVERY };
const OTHER_CUSTOMER: AuthUser = { sub: 11, role: UserRole.CUSTOMER };
const ADMIN: AuthUser = { sub: 1, role: UserRole.ADMIN };

function orderFixture(overrides: Partial<Order> = {}): Order {
  return {
    id: 7,
    customerId: 10,
    acceptedDriverId: 20,
    status: OrderStatus.AT_STORE,
    finalDeliveryFee: 40,
    itemsPrice: 300, // deliberately large: it must never reach the penalty
    ...overrides,
  } as Order;
}

interface BuildOptions {
  order?: Order | null;
  existingRequest?: Partial<OrderCancellationRequest> | null;
}

function build({
  order = orderFixture(),
  existingRequest = null,
}: BuildOptions = {}) {
  const ledger: Array<Record<string, unknown>> = [];
  const orderUpdates: Array<Record<string, unknown>> = [];
  const requestUpdates: Array<Record<string, unknown>> = [];
  const savedRequests: Array<Record<string, unknown>> = [];

  const creditWithin = jest
    .spyOn(PaymentsService, 'creditWithin')
    .mockImplementation((_manager, entry) => {
      ledger.push({ ...entry });
      return Promise.resolve(100 + entry.amount);
    });

  const manager = {
    findOne: jest.fn((entity: unknown) => {
      if (entity === Order) return Promise.resolve(order);
      return Promise.resolve(existingRequest ?? null);
    }),
    update: jest.fn((entity: unknown, _where: unknown, patch: object) => {
      if (entity === Order) orderUpdates.push(patch as Record<string, unknown>);
      else requestUpdates.push(patch as Record<string, unknown>);
      return Promise.resolve({ affected: 1 });
    }),
    create: jest.fn((_entity: unknown, row: object) => row),
    save: jest.fn((row: object) => {
      savedRequests.push(row as Record<string, unknown>);
      return Promise.resolve({ id: 55, ...row });
    }),
  };

  const orderRepository = {
    findOne: jest.fn().mockResolvedValue(order),
    manager: {
      transaction: jest.fn((cb: (m: typeof manager) => Promise<unknown>) =>
        cb(manager),
      ),
      query: jest.fn().mockResolvedValue([]),
    },
  };

  const cancellationRepository = {
    findOne: jest.fn().mockResolvedValue(existingRequest),
    find: jest.fn().mockResolvedValue(existingRequest ? [existingRequest] : []),
    create: jest.fn((row: object) => row),
    save: jest.fn((row: object) => {
      savedRequests.push(row as Record<string, unknown>);
      return Promise.resolve({ id: 55, ...row });
    }),
    update: jest.fn((_where: unknown, patch: object) => {
      requestUpdates.push(patch as Record<string, unknown>);
      return Promise.resolve({ affected: 1 });
    }),
  };

  const settings = { getNumber: jest.fn().mockReturnValue(20) };
  const ordersService = {
    createNotification: jest.fn().mockResolvedValue(undefined),
  };

  const service = new OrderCancellationService(
    orderRepository as never,
    cancellationRepository as never,
    settings as never,
    ordersService as never,
  );

  return {
    service,
    ledger,
    orderUpdates,
    requestUpdates,
    savedRequests,
    orderRepository,
    cancellationRepository,
    ordersService,
    manager,
    creditWithin,
  };
}

afterEach(() => jest.restoreAllMocks());

describe('order cancellation (CP6-C)', () => {
  // ─── Customer opens a request ──────────────────────────────────────────

  describe('customer cancellation request', () => {
    it('opens a pending request without cancelling anything', async () => {
      const { service, savedRequests, orderUpdates, ledger } = build();

      const result = await service.requestCancellation(7, CUSTOMER, {
        reason: 'غيرت رأيي',
      });

      expect(result.success).toBe(true);
      expect(savedRequests[0]).toMatchObject({
        orderId: 7,
        requestedBy: 10,
        requestedByRole: CancellationInitiator.CUSTOMER,
        status: CancellationStatus.PENDING,
      });
      // Crucially: the order is untouched and no money moved.
      expect(orderUpdates).toEqual([]);
      expect(ledger).toEqual([]);
    });

    it('notifies the assigned driver that a decision is waiting', async () => {
      const { service, ordersService } = build();

      await service.requestCancellation(7, CUSTOMER, { reason: 'ظروف طارئة' });

      expect(ordersService.createNotification).toHaveBeenCalledWith(
        20,
        expect.stringContaining('طلب إلغاء'),
        expect.stringContaining('FL-7'),
      );
    });

    it('returns the open request instead of opening a second one', async () => {
      const { service, savedRequests } = build({
        existingRequest: {
          id: 55,
          orderId: 7,
          status: CancellationStatus.PENDING,
        },
      });

      const result = await service.requestCancellation(7, CUSTOMER, {
        reason: 'again',
      });

      expect(result.repeated).toBe(true);
      expect(savedRequests).toEqual([]);
    });

    it('refuses a customer who does not own the order', async () => {
      const { service } = build();
      await expect(
        service.requestCancellation(7, OTHER_CUSTOMER, { reason: 'x' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('refuses the driver — this route is the customer’s', async () => {
      const { service } = build();
      await expect(
        service.requestCancellation(7, DRIVER, { reason: 'x' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('refuses once the order is out for delivery', async () => {
      const { service } = build({
        order: orderFixture({ status: OrderStatus.DELIVERING }),
      });
      await expect(
        service.requestCancellation(7, CUSTOMER, { reason: 'x' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('refuses on a completed order', async () => {
      const { service } = build({
        order: orderFixture({ status: OrderStatus.COMPLETED }),
      });
      await expect(
        service.requestCancellation(7, CUSTOMER, { reason: 'x' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('refuses on an already cancelled order', async () => {
      const { service } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
      });
      await expect(
        service.requestCancellation(7, CUSTOMER, { reason: 'x' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('points a pre-acceptance customer at the free direct cancel', async () => {
      const { service } = build({
        order: orderFixture({
          status: OrderStatus.PENDING_OFFERS,
          acceptedDriverId: undefined,
        }),
      });
      await expect(
        service.requestCancellation(7, CUSTOMER, { reason: 'x' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ─── Driver answers ────────────────────────────────────────────────────

  describe('driver rejects the request', () => {
    it('leaves the order running and moves no money', async () => {
      const { service, orderUpdates, ledger, requestUpdates } = build({
        existingRequest: {
          id: 55,
          orderId: 7,
          status: CancellationStatus.PENDING,
        },
      });

      const result = await service.decideCancellation(7, DRIVER, false, {
        decisionReason: 'أنا بالفعل في الصيدلية',
      });

      expect(result.cancelled).toBe(false);
      expect(orderUpdates).toEqual([]);
      expect(ledger).toEqual([]);
      expect(requestUpdates[0]).toMatchObject({
        status: CancellationStatus.REJECTED,
        decidedBy: 20,
      });
    });

    it('refuses a driver who is not the one assigned', async () => {
      const { service } = build();
      await expect(
        service.decideCancellation(7, OTHER_DRIVER, false, {}),
      ).rejects.toThrow(ForbiddenException);
    });

    it('refuses the customer deciding their own request', async () => {
      const { service } = build();
      await expect(
        service.decideCancellation(7, CUSTOMER, true, {}),
      ).rejects.toThrow(ForbiddenException);
    });

    it('404s when there is nothing pending to decide', async () => {
      const { service } = build({ existingRequest: null });
      await expect(
        service.decideCancellation(7, DRIVER, false, {}),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('driver approves the request', () => {
    // Q-B3, approved: saying yes to the customer is free for the driver.
    it('cancels the order and charges nothing (Q-B3)', async () => {
      const { service, orderUpdates, ledger } = build({
        existingRequest: {
          id: 55,
          orderId: 7,
          status: CancellationStatus.PENDING,
        },
      });

      const result = await service.decideCancellation(7, DRIVER, true, {});

      expect(result.cancelled).toBe(true);
      expect(result.penalty).toBe(0);
      expect(orderUpdates[0]).toMatchObject({ status: OrderStatus.CANCELLED });
      // Not merely "amount 0" — no wallet entry is written at all, so the
      // driver's ledger shows nothing for having been accommodating.
      expect(ledger).toEqual([]);
    });

    it('closes the customer’s request rather than opening a new record', async () => {
      const { service, requestUpdates, savedRequests } = build({
        existingRequest: {
          id: 55,
          orderId: 7,
          status: CancellationStatus.PENDING,
        },
      });

      await service.decideCancellation(7, DRIVER, true, {});

      expect(requestUpdates[0]).toMatchObject({
        status: CancellationStatus.APPROVED,
        penaltyAmount: 0,
        // No charge means no idempotency reference to hang an appeal on —
        // and nothing to appeal, which is the point.
        penaltyReference: null,
      });
      expect(savedRequests).toEqual([]);
    });
  });

  // ─── Driver cancels outright ───────────────────────────────────────────

  describe('driver-initiated cancellation', () => {
    it('cancels, charges the penalty, and records the reason', async () => {
      const { service, orderUpdates, ledger, savedRequests } = build();

      const result = await service.driverCancel(7, DRIVER, {
        reason: 'العربية اتعطلت',
      });

      expect(result.cancelled).toBe(true);
      expect(result.penalty).toBe(8);
      expect(orderUpdates[0]).toMatchObject({ status: OrderStatus.CANCELLED });
      expect(savedRequests[0]).toMatchObject({
        requestedByRole: CancellationInitiator.DRIVER,
        status: CancellationStatus.APPROVED,
        reason: 'العربية اتعطلت',
        penaltyAmount: 8,
      });
      expect(ledger[0]).toMatchObject({ amount: -8 });
    });

    it('refuses a driver the order is not assigned to', async () => {
      const { service, ledger } = build();
      await expect(
        service.driverCancel(7, OTHER_DRIVER, { reason: 'x' }),
      ).rejects.toThrow(ForbiddenException);
      expect(ledger).toEqual([]);
    });

    it('refuses the customer', async () => {
      const { service } = build();
      await expect(
        service.driverCancel(7, CUSTOMER, { reason: 'x' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('refuses once the order is out for delivery', async () => {
      const { service, ledger } = build({
        order: orderFixture({ status: OrderStatus.DELIVERING }),
      });
      await expect(
        service.driverCancel(7, DRIVER, { reason: 'x' }),
      ).rejects.toThrow(BadRequestException);
      expect(ledger).toEqual([]);
    });

    it('charges nothing when the delivery was free', async () => {
      const { service, ledger, orderUpdates } = build({
        order: orderFixture({ finalDeliveryFee: 0 }),
      });

      const result = await service.driverCancel(7, DRIVER, { reason: 'x' });

      expect(result.penalty).toBe(0);
      expect(ledger).toEqual([]); // no zero-value ledger noise
      expect(orderUpdates[0]).toMatchObject({ status: OrderStatus.CANCELLED });
    });

    it('never reads an amount from the caller', async () => {
      const { service, ledger } = build();

      await service.driverCancel(7, DRIVER, {
        reason: 'x',
        // A client trying to set its own penalty. The DTO drops it and the
        // service computes from the order regardless.
        penalty: 0,
        amount: 0,
      } as never);

      expect(ledger[0]).toMatchObject({ amount: -8 });
    });
  });

  // ─── Idempotency ───────────────────────────────────────────────────────

  describe('duplicate protection', () => {
    it('does not charge twice when the order is already cancelled', async () => {
      const { service, ledger, orderUpdates } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
        existingRequest: {
          id: 55,
          orderId: 7,
          status: CancellationStatus.APPROVED,
          penaltyAmount: 8,
        },
      });

      const result = await service.driverCancel(7, DRIVER, { reason: 'again' });

      expect(result.repeated).toBe(true);
      expect(ledger).toEqual([]);
      expect(orderUpdates).toEqual([]);
    });

    it('treats a lost race as the winner’s result, not an error', async () => {
      const { service, cancellationRepository, orderRepository } = build();

      // The competing transaction committed first; ours dies on the unique
      // index that guarantees one approved cancellation per order.
      (
        orderRepository as unknown as {
          manager: { transaction: jest.Mock };
        }
      ).manager.transaction = jest
        .fn()
        .mockRejectedValue(
          Object.assign(new Error('duplicate key'), { code: '23505' }),
        );
      cancellationRepository.findOne.mockResolvedValue({
        id: 55,
        orderId: 7,
        status: CancellationStatus.APPROVED,
        penaltyAmount: 8,
      });

      const result = await service.driverCancel(7, DRIVER, { reason: 'race' });

      expect(result.repeated).toBe(true);
      expect(result.cancelled).toBe(true);
    });
  });

  // ─── Appeal ────────────────────────────────────────────────────────────

  describe('driver appeal', () => {
    const charged = {
      id: 55,
      orderId: 7,
      status: CancellationStatus.APPROVED,
      penaltyAmount: 8,
      penaltyReference: 'order-7-cancel-penalty',
      appealStatus: CancellationAppealStatus.NONE,
    };

    it('opens a review without moving money', async () => {
      const { service, requestUpdates, ledger } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
        existingRequest: charged,
      });

      await service.appeal(7, DRIVER, { reason: 'العميل رفض استلام الطلب' });

      expect(requestUpdates[0]).toMatchObject({
        appealStatus: CancellationAppealStatus.PENDING,
      });
      expect(ledger).toEqual([]);
    });

    it('refuses a driver who is not on the order', async () => {
      const { service } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
        existingRequest: charged,
      });
      await expect(
        service.appeal(7, OTHER_DRIVER, { reason: 'x' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('refuses the customer', async () => {
      const { service } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
        existingRequest: charged,
      });
      await expect(
        service.appeal(7, CUSTOMER, { reason: 'x' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('refuses when no penalty was charged', async () => {
      const { service } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
        existingRequest: { ...charged, penaltyReference: null },
      });
      await expect(service.appeal(7, DRIVER, { reason: 'x' })).rejects.toThrow(
        BadRequestException,
      );
    });

    it('is idempotent while already pending', async () => {
      const { service, requestUpdates } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
        existingRequest: {
          ...charged,
          appealStatus: CancellationAppealStatus.PENDING,
        },
      });

      const result = await service.appeal(7, DRIVER, { reason: 'again' });

      expect(result.repeated).toBe(true);
      expect(requestUpdates).toEqual([]);
    });

    it('refuses to reopen a decided appeal', async () => {
      const { service } = build({
        order: orderFixture({ status: OrderStatus.CANCELLED }),
        existingRequest: {
          ...charged,
          appealStatus: CancellationAppealStatus.UPHELD,
        },
      });
      await expect(service.appeal(7, DRIVER, { reason: 'x' })).rejects.toThrow(
        ConflictException,
      );
    });
  });

  // ─── Admin review ──────────────────────────────────────────────────────

  describe('admin review', () => {
    const appealed = {
      id: 55,
      orderId: 7,
      status: CancellationStatus.APPROVED,
      penaltyAmount: 8,
      penaltyReference: 'order-7-cancel-penalty',
      appealStatus: CancellationAppealStatus.PENDING,
    };

    it('refunds the exact penalty, credited and order-linked', async () => {
      const { service, ledger, requestUpdates } = build({
        existingRequest: appealed,
      });

      await service.refundPenalty(55, ADMIN, { note: 'العميل هو السبب' });

      expect(ledger[0]).toMatchObject({
        driverId: 20,
        amount: 8, // credit, exactly what was taken
        type: WalletTxType.PENALTY_REFUND,
        reference: 'order-7-cancel-refund',
        orderId: 7,
      });
      expect(requestUpdates[0]).toMatchObject({
        appealStatus: CancellationAppealStatus.REFUNDED,
        refundAmount: 8,
        reviewedBy: 1,
      });
    });

    it('does not refund twice', async () => {
      const { service, ledger } = build({
        existingRequest: {
          ...appealed,
          appealStatus: CancellationAppealStatus.REFUNDED,
        },
      });

      const result = await service.refundPenalty(55, ADMIN, {});

      expect(result.repeated).toBe(true);
      expect(ledger).toEqual([]);
    });

    it('refuses to refund an upheld penalty', async () => {
      const { service } = build({
        existingRequest: {
          ...appealed,
          appealStatus: CancellationAppealStatus.UPHELD,
        },
      });
      await expect(service.refundPenalty(55, ADMIN, {})).rejects.toThrow(
        ConflictException,
      );
    });

    it('refuses a non-admin, even the driver who was charged', async () => {
      const { service, ledger } = build({ existingRequest: appealed });

      await expect(service.refundPenalty(55, DRIVER, {})).rejects.toThrow(
        ForbiddenException,
      );
      await expect(service.refundPenalty(55, CUSTOMER, {})).rejects.toThrow(
        ForbiddenException,
      );
      expect(ledger).toEqual([]);
    });

    it('upholding keeps the money where it is', async () => {
      const { service, ledger, requestUpdates } = build({
        existingRequest: appealed,
      });

      await service.upholdPenalty(55, ADMIN, { note: 'الكابتن مسؤول' });

      expect(ledger).toEqual([]);
      expect(requestUpdates[0]).toMatchObject({
        appealStatus: CancellationAppealStatus.UPHELD,
        reviewedBy: 1,
      });
    });

    it('refuses a non-admin upholding', async () => {
      const { service } = build({ existingRequest: appealed });
      await expect(service.upholdPenalty(55, DRIVER, {})).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('hands the reviewer the ledger and a pointer to the chat evidence', async () => {
      const { service } = build({ existingRequest: appealed });

      const detail = await service.getReviewDetail(55);

      expect(detail.evidence.messages).toBe('/orders/7/chat/messages');
      expect(detail).toHaveProperty('transactions');
      expect(detail).toHaveProperty('order');
    });
  });

  // ─── Reading ───────────────────────────────────────────────────────────

  describe('reading the record', () => {
    it('is visible to both parties and to an admin', async () => {
      for (const viewer of [CUSTOMER, DRIVER, ADMIN]) {
        const { service } = build({
          existingRequest: { id: 55, orderId: 7 },
        });
        await expect(service.getForOrder(7, viewer)).resolves.toMatchObject({
          success: true,
        });
      }
    });

    it('is hidden from anyone else', async () => {
      const { service } = build();
      await expect(service.getForOrder(7, OTHER_DRIVER)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });
});
