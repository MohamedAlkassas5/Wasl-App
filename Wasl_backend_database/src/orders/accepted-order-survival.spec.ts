import { OrdersService } from './orders.service';
import { Order, OrderStatus, SettlementStatus } from './entities/order.entity';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { PaymentsService } from '../payments/payments.service';

const DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };

/**
 * CP6 §15 — the minimum balance and the online flag gate **new** work. They
 * must never reach back and disturb an order the driver already holds.
 *
 * The scenario, end to end: an eligible driver accepts, then goes offline, then
 * their balance falls under the minimum. The order stays theirs and stays
 * workable, all the way through settlement.
 *
 * These are written as "no code path re-checks eligibility after assignment",
 * because that is the actual invariant — an eligibility call added to
 * `updateStatus` or `completeOrder` in some later checkpoint would strand live
 * deliveries, and these tests are what would catch it.
 */
describe('accepted orders survive a driver going offline or broke (CP6 §15)', () => {
  /** An order already assigned to our driver, mid-journey. */
  function orderFixture(overrides: Partial<Order> = {}): Order {
    return {
      id: 7,
      customerId: 10,
      acceptedDriverId: 20,
      status: OrderStatus.ACCEPTED,
      finalDeliveryFee: 40,
      itemsPrice: 0,
      settlementStatus: SettlementStatus.PENDING,
      ...overrides,
    } as Order;
  }

  /**
   * The driver is in the worst state the rules allow: offline, no balance, and
   * — deliberately — not even approved any more. None of it may matter here.
   */
  function build(order: Order) {
    const updates: Record<string, unknown>[] = [];

    const orderRepository = {
      findOne: jest.fn().mockResolvedValue(order),
      save: jest.fn((row: Order) => {
        updates.push({ ...row });
        return Promise.resolve(row);
      }),
      manager: {
        transaction: jest.fn(),
      },
    };

    const brokeOfflineDriver = {
      userId: 20,
      isOnline: false,
      balance: 0,
      verificationStatus: 'pending',
    };

    const deliveryRepository = {
      findOne: jest.fn().mockResolvedValue(brokeOfflineDriver),
      save: jest.fn(),
    };
    const eligibilitySpy = jest.fn();

    const service = new OrdersService(
      orderRepository as never,
      deliveryRepository as never,
      { create: jest.fn(), save: jest.fn() } as never,
      {
        findOne: jest.fn((...args: unknown[]) => {
          eligibilitySpy(...args);
          return Promise.resolve({ id: 20, status: 'pending' });
        }),
      } as never,
      {} as never,
      {} as never,
      {
        minWalletToGoOnline: () => 5,
        commissionForFee: (fee: number) => Math.max(fee * 0.2, 5),
      } as never,
      {} as never,
      {} as never,
      // Assignment plays no part once an order is already the driver's.
      { liveOffersFor: jest.fn().mockResolvedValue([]) } as never,
    );

    return { service, orderRepository, deliveryRepository, updates };
  }

  it('lets the assigned driver advance accepted → at_store while offline and broke', async () => {
    const { service, updates } = build(orderFixture());

    await service.updateStatus(7, OrderStatus.AT_STORE, {}, DRIVER);

    expect(updates[0].status).toBe(OrderStatus.AT_STORE);
  });

  it('lets them advance at_store → items_bought', async () => {
    const { service, updates } = build(
      orderFixture({ status: OrderStatus.AT_STORE }),
    );

    await service.updateStatus(7, OrderStatus.ITEMS_BOUGHT, {}, DRIVER);

    expect(updates[0].status).toBe(OrderStatus.ITEMS_BOUGHT);
  });

  it('lets them advance items_bought → delivering', async () => {
    const { service, updates } = build(
      orderFixture({ status: OrderStatus.ITEMS_BOUGHT }),
    );

    await service.updateStatus(7, OrderStatus.DELIVERING, {}, DRIVER);

    expect(updates[0].status).toBe(OrderStatus.DELIVERING);
  });

  it('never consults the wallet balance while advancing an assigned order', async () => {
    const { service, deliveryRepository } = build(orderFixture());

    await service.updateStatus(7, OrderStatus.AT_STORE, {}, DRIVER);

    // If a future change added an eligibility or balance check here, a driver
    // whose balance dipped mid-delivery would be stranded. It must not look.
    expect(deliveryRepository.findOne).not.toHaveBeenCalled();
  });

  it('settles a delivery completed by an offline, zero-balance driver', async () => {
    const order = orderFixture({ status: OrderStatus.DELIVERING });
    const { service, orderRepository } = build(order);

    const managerUpdates: Record<string, unknown>[] = [];
    const manager = {
      findOne: jest.fn().mockResolvedValue(order),
      update: jest.fn((_entity: unknown, _where: unknown, patch: object) => {
        managerUpdates.push(patch as Record<string, unknown>);
        return Promise.resolve({ affected: 1 });
      }),
    };
    orderRepository.manager.transaction = jest.fn(
      (cb: (m: typeof manager) => Promise<unknown>) => cb(manager),
    );

    // The commission debit itself is covered by order-settlement.spec.ts; here
    // the only question is whether being offline and broke blocks completion.
    const paymentsCredit = jest
      .spyOn(PaymentsService, 'creditWithin')
      .mockResolvedValue(-8);

    const result = await service.completeOrder(7, DRIVER);

    expect(result.success).toBe(true);
    expect(managerUpdates[0]).toMatchObject({
      status: OrderStatus.COMPLETED,
      settlementStatus: SettlementStatus.SETTLED,
    });

    paymentsCredit.mockRestore();
  });

  it('does not cancel or reassign the order when the driver goes offline', async () => {
    const { service, deliveryRepository, updates } = build(orderFixture());

    // Going offline touches the driver row and nothing else.
    deliveryRepository.findOne.mockResolvedValue({
      userId: 20,
      isOnline: true,
      balance: 0,
      verificationStatus: 'approved',
    });

    await service.setDriverOnlineStatus(20, false);

    expect(deliveryRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({ isOnline: false }),
    );
    // No order was written at all.
    expect(updates).toHaveLength(0);
  });
});
