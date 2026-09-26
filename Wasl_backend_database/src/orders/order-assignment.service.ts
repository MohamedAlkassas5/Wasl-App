import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, In, LessThanOrEqual, Repository } from 'typeorm';

import {
  Order,
  OrderStatus,
  DRIVER_ACTIVE_STATUSES,
} from './entities/order.entity';
import {
  OrderAssignment,
  AssignmentStatus,
} from './entities/order-assignment.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { User } from '../users/entities/user.entity';
import { DeliveryService } from '../delivery/delivery.service';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { checkDriverEligibility } from '../delivery/driver-eligibility';
import { isValidCoordinate } from '../common/geo.util';
import {
  NotificationsService,
  NotificationKind,
} from '../notifications/notifications.service';

/**
 * How many drivers a single wave goes out to.
 *
 * Three, not one: offering to one driver at a time means an order waits a full
 * minute for each person who happens to be looking away, and in a town this
 * size that is most of them. Three at once keeps the wait short while staying
 * small enough that losing is uncommon rather than routine.
 *
 * These are business rules rather than tunables — they are not in
 * `app_settings` because changing them changes how the product behaves, not
 * how it is priced.
 */
const WAVE_SIZE = 3;

/** How long a driver has to answer before the offer lapses. */
const OFFER_TIMEOUT_SECONDS = 60;

/** The furthest an order is ever offered. */
const MAX_RADIUS_KM = 10;

export interface WaveResult {
  /** Drivers newly offered this order. Empty when nobody was available. */
  offered: number[];
  waveNumber: number;
  radiusKm: number;
  /** True when the radius ceiling was reached with nobody left to ask. */
  exhausted: boolean;
}

/**
 * Who gets offered an order, and for how long.
 *
 * The rules, in one place:
 *
 *  - **Eligible.** The same {@link checkDriverEligibility} that guards going
 *    online and accepting. There is no second definition of "approved" here.
 *  - **Free.** One active order per driver. A driver mid-delivery is not asked.
 *  - **Near.** Within the wave's radius of the pickup point, and within the
 *    driver's own `availabilityRadiusKm` — a driver who only works a 3 km patch
 *    is not offered a job 8 km away just because the wave has widened.
 *  - **Not already asked.** One offer per driver per order, ever. A driver who
 *    declined, or whose offer lapsed, is not pestered on the next wave.
 *
 * Ranking is plain nearest-first. Nothing weights rating or earnings: an
 * explainable rule a driver can predict is worth more here than an optimal one
 * they cannot.
 */
@Injectable()
export class OrderAssignmentService {
  private readonly logger = new Logger(OrderAssignmentService.name);

  constructor(
    @InjectRepository(OrderAssignment)
    private readonly assignmentRepository: Repository<OrderAssignment>,
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly deliveryService: DeliveryService,
    private readonly settings: SettingsService,
    private readonly notifications: NotificationsService,
  ) {}

  // ─── Reading ─────────────────────────────────────────────────────────────

  /** The orders currently offered to this driver and still answerable. */
  async liveOffersFor(driverId: number): Promise<OrderAssignment[]> {
    return this.assignmentRepository.find({
      where: { driverId, status: AssignmentStatus.OFFERED },
      order: { offeredAt: 'DESC' },
    });
  }

  /** Every offer made on an order, newest first. The audit view. */
  async historyFor(orderId: number): Promise<OrderAssignment[]> {
    return this.assignmentRepository.find({
      where: { orderId },
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Whether this driver may answer for this order right now.
   *
   * Acceptance calls this before doing anything expensive; the authoritative
   * check is still the conditional update inside the transaction.
   */
  async hasLiveOffer(orderId: number, driverId: number): Promise<boolean> {
    const offer = await this.assignmentRepository.findOne({
      where: { orderId, driverId, status: AssignmentStatus.OFFERED },
    });
    return !!offer && new Date(offer.expiresAt) > new Date();
  }

  // ─── Capacity ────────────────────────────────────────────────────────────

  /**
   * The one-active-order rule, as a query.
   *
   * Takes an optional manager so acceptance can ask the same question inside
   * its own transaction and see its own uncommitted writes.
   */
  async activeOrderCount(
    driverId: number,
    manager?: EntityManager,
  ): Promise<number> {
    const repo = manager ? manager.getRepository(Order) : this.orderRepository;
    return repo.count({
      where: {
        acceptedDriverId: driverId,
        status: In([...DRIVER_ACTIVE_STATUSES]),
      },
    });
  }

  async isDriverFree(
    driverId: number,
    manager?: EntityManager,
  ): Promise<boolean> {
    return (await this.activeOrderCount(driverId, manager)) === 0;
  }

  // ─── Offering ────────────────────────────────────────────────────────────

  /**
   * Opens the next wave on an order.
   *
   * Wave 1 goes out at the platform's normal search radius; each later wave
   * widens by that same step until {@link MAX_RADIUS_KM}. `exhausted` comes
   * back true when the ceiling has been reached and there was still nobody to
   * ask — the sweep turns that into an expired order.
   */
  async openNextWave(orderId: number): Promise<WaveResult> {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (order.status !== OrderStatus.PENDING_OFFERS) {
      return {
        offered: [],
        waveNumber: 0,
        radiusKm: 0,
        exhausted: false,
      };
    }

    const previous = await this.assignmentRepository.find({
      where: { orderId },
    });

    // The counter is on the order, not derived from the rows above: a wave that
    // reaches nobody writes no rows, and deriving it would then replay that
    // same empty wave for ever instead of widening.
    const waveNumber = (order.assignmentWave ?? 0) + 1;
    await this.orderRepository.update(
      { id: orderId },
      { assignmentWave: waveNumber },
    );

    const step = this.startingRadiusKm();
    const radiusKm = Math.min(step * waveNumber, MAX_RADIUS_KM);
    const atCeiling = radiusKm >= MAX_RADIUS_KM;

    const alreadyAsked = new Set(previous.map((a) => a.driverId));
    const candidates = await this.findCandidates(order, radiusKm, alreadyAsked);

    if (candidates.length === 0) {
      return { offered: [], waveNumber, radiusKm, exhausted: atCeiling };
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + OFFER_TIMEOUT_SECONDS * 1000);

    const offered: number[] = [];
    for (const candidate of candidates.slice(0, WAVE_SIZE)) {
      try {
        await this.assignmentRepository.insert({
          orderId,
          driverId: candidate.driverId,
          waveNumber,
          radiusKm,
          distanceKm: candidate.distanceKm,
          status: AssignmentStatus.OFFERED,
          offeredAt: now,
          expiresAt,
        });
        offered.push(candidate.driverId);
      } catch {
        // Lost a race against another wave that just offered this same driver.
        // The unique index did its job; skip them and move on.
      }
    }

    this.logger.log(
      `📡 Order FL-${orderId} wave ${waveNumber} @ ${radiusKm}km → ${offered.length} driver(s)`,
    );

    // 🔔 Tell them. A sixty-second window is worthless if the driver only finds
    // out by happening to refresh, which is why this lives here rather than at
    // the creation site — every wave notifies, not just the first.
    await this.notifyQuietly(() =>
      this.notifications.notifyMany(
        offered,
        '📦 طلب توصيل جديد ليك!',
        `طلب جديد قريب منك برسوم توصيل ${Number(order.estimatedDeliveryFee)} ج.م. عندك دقيقة تقبله.`,
        { kind: NotificationKind.ORDER_OFFER, orderId },
      ),
    );

    return { offered, waveNumber, radiusKm, exhausted: atCeiling };
  }

  /**
   * Eligible, free, near, and not already asked — nearest first.
   *
   * The distance search is {@link DeliveryService.findNearbyOnlineDrivers},
   * unchanged: it already handles online state, stale GPS fixes and the
   * haversine sort, and duplicating that here is exactly the kind of second
   * system this checkpoint is meant to avoid.
   */
  private async findCandidates(
    order: Order,
    radiusKm: number,
    exclude: Set<number>,
  ) {
    const originLat = Number(order.pickupLatitude ?? order.latitude);
    const originLng = Number(order.pickupLongitude ?? order.longitude);
    if (!isValidCoordinate(originLat, originLng)) return [];

    const nearby = await this.deliveryService.findNearbyOnlineDrivers(
      originLat,
      originLng,
      radiusKm,
    );

    const fresh = nearby.filter((d) => !exclude.has(d.driverId));
    if (fresh.length === 0) return [];

    const partners = await this.deliveryRepository.find({
      where: { userId: In(fresh.map((d) => d.driverId)) },
    });
    const users = await this.userRepository.find({
      where: { id: In(fresh.map((d) => d.driverId)) },
    });
    const partnerById = new Map(partners.map((p) => [p.userId, p]));
    const userById = new Map(users.map((u) => [u.id, u]));

    const eligible: typeof fresh = [];
    for (const candidate of fresh) {
      const partner = partnerById.get(candidate.driverId);
      const user = userById.get(candidate.driverId);

      // The one definition of "approved", shared with going online and
      // accepting.
      if (!checkDriverEligibility(user ?? null, partner ?? null).eligible) {
        continue;
      }

      // A driver's own radius is a promise the platform made them, so widening
      // the wave never overrides it.
      const ownRadius = Number(partner?.availabilityRadiusKm ?? radiusKm);
      if (Number.isFinite(ownRadius) && candidate.distanceKm > ownRadius) {
        continue;
      }

      // Enough in the wallet to take work at all — the same floor acceptance
      // applies, checked here so we don't offer an order they cannot accept.
      if (
        Number(partner?.balance ?? 0) <
        this.settings.getNumber(SettingKey.MIN_WALLET_TO_GO_ONLINE, 5)
      ) {
        continue;
      }

      // 🚚 One active order per driver.
      if (!(await this.isDriverFree(candidate.driverId))) continue;

      eligible.push(candidate);
    }

    return eligible;
  }

  private startingRadiusKm(): number {
    const configured = this.settings.getNumber(
      SettingKey.DRIVER_SEARCH_RADIUS_KM,
      5,
    );
    return configured > 0 ? Math.min(configured, MAX_RADIUS_KM) : 5;
  }

  // ─── Answering ───────────────────────────────────────────────────────────

  /**
   * The driver says no.
   *
   * Not a penalty and not a mark against them — it only takes them out of the
   * running for this order so the next wave does not ask again. If they were
   * the last live offer, the sweep picks the order up on its next pass rather
   * than widening here: keeping all the widening in one place means an order
   * cannot be advanced down two paths at once.
   */
  async decline(orderId: number, driverId: number) {
    const result = await this.assignmentRepository.update(
      { orderId, driverId, status: AssignmentStatus.OFFERED },
      { status: AssignmentStatus.DECLINED, respondedAt: new Date() },
    );

    if (!result.affected) {
      throw new BadRequestException(
        'لا يوجد عرض مفتوح على هذا الطلب لك، ربما انتهت مهلته أو قبله كابتن آخر',
      );
    }

    return { success: true, message: 'تم رفض الطلب' };
  }

  /**
   * Records the winner and closes every other offer on the order.
   *
   * Runs inside acceptance's transaction — same manager, so it commits or rolls
   * back with the order's own state change. Marking the winner is a conditional
   * update on `status = 'offered'`: if their offer lapsed a moment ago, this
   * affects nothing and acceptance is refused.
   */
  static async markWinnerWithin(
    manager: EntityManager,
    orderId: number,
    driverId: number,
  ): Promise<boolean> {
    const now = new Date();

    const won = await manager.update(
      OrderAssignment,
      { orderId, driverId, status: AssignmentStatus.OFFERED },
      { status: AssignmentStatus.ACCEPTED, respondedAt: now },
    );
    if (!won.affected) return false;

    // Everyone else's offer on this order is over.
    await manager.update(
      OrderAssignment,
      { orderId, status: AssignmentStatus.OFFERED },
      { status: AssignmentStatus.EXPIRED, respondedAt: now },
    );

    // And this driver is now busy, so withdraw their offers on other orders —
    // they could not accept them anyway under the one-order rule, and leaving
    // them live would show the driver work they cannot take.
    await manager
      .createQueryBuilder()
      .update(OrderAssignment)
      .set({ status: AssignmentStatus.EXPIRED, respondedAt: now })
      .where('driver_id = :driverId', { driverId })
      .andWhere('order_id != :orderId', { orderId })
      .andWhere('status = :status', { status: AssignmentStatus.OFFERED })
      .execute();

    return true;
  }

  // ─── The sweep ───────────────────────────────────────────────────────────

  /**
   * Expires lapsed offers and moves each affected order along.
   *
   * Runs every fifteen seconds against a sixty-second window, so an order waits
   * at most a quarter-minute past its deadline before the next wave goes out.
   * Polling rather than a timer per order on purpose: timers do not survive a
   * restart, and an order stuck because the process was redeployed mid-wave is
   * exactly the failure this is meant to prevent.
   */
  @Interval('assignment-sweep', 15_000)
  async sweepExpiredOffers(): Promise<void> {
    try {
      await this.runSweep();
    } catch (error) {
      this.logger.error(
        'Assignment sweep failed',
        error instanceof Error ? error.message : String(error),
      );
    }
  }

  /** The sweep body, separated so tests can drive it directly. */
  async runSweep(now: Date = new Date()): Promise<{
    expiredOffers: number;
    rewaved: number[];
    expiredOrders: number[];
  }> {
    const lapsed = await this.assignmentRepository.find({
      where: {
        status: AssignmentStatus.OFFERED,
        expiresAt: LessThanOrEqual(now),
      },
    });

    if (lapsed.length > 0) {
      await this.assignmentRepository.update(
        { id: In(lapsed.map((a) => a.id)) },
        { status: AssignmentStatus.EXPIRED },
      );

      // 🔔 Close the loop for the drivers who ran out of time, so a stale offer
      // does not sit in their list looking answerable. Deliberately quiet — no
      // reproach, they may simply have been riding.
      await this.notifyQuietly(() =>
        this.notifications.notifyMany(
          [...new Set(lapsed.map((a) => a.driverId))],
          '⌛ انتهت مهلة العرض',
          'انتهت مهلة قبول أحد الطلبات المعروضة عليك، وتم عرضه على كابتن آخر.',
          { kind: NotificationKind.OFFER_EXPIRED },
        ),
      );
    }

    // 🩹 An order whose wave reached *nobody* writes no assignment row, so it
    // has nothing that can lapse — and the loop above, which only ever looked
    // at lapsed offers, would never revisit it. It sat in `pending_offers` for
    // ever: not offered, not widened, not expired, invisible to every driver
    // even after one came back online. Observed in the field, which is how it
    // was found. Those orders are collected here.
    const candidates = new Set<number>(lapsed.map((a) => a.orderId));
    for (const orderId of await this.findStalledOrders(now)) {
      candidates.add(orderId);
    }

    if (candidates.size === 0) {
      return { expiredOffers: lapsed.length, rewaved: [], expiredOrders: [] };
    }

    const rewaved: number[] = [];
    const expiredOrders: number[] = [];

    for (const orderId of candidates) {
      // Somebody may have accepted between the query and here.
      const stillWaiting = await this.assignmentRepository.count({
        where: { orderId, status: AssignmentStatus.OFFERED },
      });
      if (stillWaiting > 0) continue;

      const wave = await this.openNextWave(orderId);
      if (wave.offered.length > 0) {
        rewaved.push(orderId);
        continue;
      }
      if (wave.exhausted) {
        if (await this.expireOrder(orderId)) expiredOrders.push(orderId);
      }
    }

    return {
      expiredOffers: lapsed.length,
      rewaved,
      expiredOrders,
    };
  }

  /**
   * Orders that are waiting but have nobody to wait on.
   *
   * "Stalled" means: still `pending_offers`, no live offer outstanding, and
   * due for its next wave. The due time is derived rather than stored —
   * `createdAt + waveNumber × the offer timeout` — so an order gets the same
   * sixty seconds per wave it would have got had a driver been asked, instead
   * of racing through every radius in one sweep. That keeps the widening
   * paced without adding a column to `orders`.
   *
   * A wave that never ran at all (`assignmentWave` 0, because creation threw
   * before it) comes out due immediately, which is the repair such an order
   * needs.
   */
  private async findStalledOrders(now: Date): Promise<number[]> {
    const waiting = await this.orderRepository.find({
      where: { status: OrderStatus.PENDING_OFFERS },
    });
    if (waiting.length === 0) return [];

    const live = await this.assignmentRepository.find({
      where: {
        orderId: In(waiting.map((o) => o.id)),
        status: AssignmentStatus.OFFERED,
      },
    });
    const beingAsked = new Set(live.map((a) => a.orderId));

    return waiting
      .filter((order) => !beingAsked.has(order.id))
      .filter((order) => {
        const wave = order.assignmentWave ?? 0;
        const dueAt =
          new Date(order.createdAt).getTime() +
          wave * OFFER_TIMEOUT_SECONDS * 1000;
        return dueAt <= now.getTime();
      })
      .map((order) => order.id);
  }

  /**
   * Nobody took it. Conditional on the order still waiting, so an acceptance
   * that landed a moment ago is never overwritten.
   */
  private async expireOrder(orderId: number): Promise<boolean> {
    const result = await this.orderRepository.update(
      { id: orderId, status: OrderStatus.PENDING_OFFERS },
      { status: OrderStatus.EXPIRED },
    );
    if (!result.affected) return false;

    this.logger.warn(`⌛ Order FL-${orderId} expired — no captain found`);

    // 🔔 The customer has been watching a spinner. Tell them plainly what
    // happened and that they are free to try again — this is not a rejection
    // and nothing was charged, so the wording says neither.
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });
    if (order) {
      await this.notifyQuietly(() =>
        this.notifications.notify(
          order.customerId,
          '⌛ معلش، مفيش كابتن متاح دلوقتي',
          `مقدرناش نلاقي كابتن لطلبك رقم FL-${orderId} في الوقت الحالي. تقدر تعيد الطلب تاني بعد شوية.`,
          { kind: NotificationKind.ORDER_EXPIRED, orderId },
        ),
      );
    }

    return true;
  }

  /**
   * Runs a notification without letting it unwind the assignment that caused it.
   *
   * The offers are already written and the order's state already decided by the
   * time any of these fire. Letting a notifier throw would not undo that — it
   * would only abandon the rest of the sweep's loop, leaving other orders
   * unprocessed for no better reason than one message failing to send.
   */
  private async notifyQuietly(send: () => Promise<unknown>): Promise<void> {
    try {
      await send();
    } catch (error) {
      this.logger.error(
        'Assignment notification failed',
        error instanceof Error ? error.message : String(error),
      );
    }
  }
}
