import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';

import {
  Order,
  OrderStatus,
  PaymentMethod,
  PaymentStatus,
  PricingSource,
  SettlementStatus,
  DRIVER_ACTIVE_STATUSES,
} from './entities/order.entity';
import { OrderAssignmentService } from './order-assignment.service';
import {
  NotificationsService,
  NotificationKind,
  NotifyOptions,
} from '../notifications/notifications.service';
import { User } from '../users/entities/user.entity';
import { OrderItem } from './entities/order-item.entity';
import { OrderType } from './entities/order.entity';
import { CatalogService } from '../catalog/catalog.service';
import { buildOrderItems } from './order-items.builder';
import {
  assertTransitionAllowed,
  COMPLETABLE_FROM,
} from './order-state-machine';
import {
  assertDriverEligible,
  checkDriverEligibility,
} from '../delivery/driver-eligibility';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { InAppNotification } from './entities/notification.entity';
import { CreateOrderDto } from './dto/create-order.dto';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { WalletTxType } from '../payments/entities/wallet-transaction.entity';
import { haversineKm, roundKm, isValidCoordinate } from '../common/geo.util';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { assertOrderParticipant } from './order-participation';

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,

    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,

    @InjectRepository(InAppNotification)
    private readonly notificationRepository: Repository<InAppNotification>,

    @InjectRepository(User)
    private readonly userRepository: Repository<User>,

    @InjectRepository(OrderItem)
    private readonly orderItemRepository: Repository<OrderItem>,

    private readonly catalogService: CatalogService,
    private readonly pricingService: PricingService,
    private readonly deliveryService: DeliveryService,
    private readonly paymentsService: PaymentsService,
    private readonly assignmentService: OrderAssignmentService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * 🔐 Loads an order and asserts the caller is allowed to see/touch it.
   * `as` narrows the allowed relationship: the order's customer, its assigned
   * driver, or either. Admins always pass.
   */
  private async getOrderFor(
    orderId: number,
    user: AuthUser,
    as: 'customer' | 'driver' | 'any',
  ): Promise<Order> {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });
    if (!order) {
      throw new NotFoundException('الطلب غير موجود');
    }
    assertOrderParticipant(order, user, as);
    return order;
  }

  /**
   * 🔔 Records a notification and pushes it to the user's devices.
   *
   * Delegates to {@link NotificationsService} rather than writing the row here:
   * every notification in the system goes through that one place, so adding
   * push did not mean touching each of the callers below, and there is no
   * second path where a row is written but no phone ever lights up.
   */
  async createNotification(
    userId: number,
    title: string,
    message: string,
    options: NotifyOptions = {},
  ) {
    await this.notifications.notify(userId, title, message, {
      kind: NotificationKind.ORDER_UPDATE,
      ...options,
    });
  }

  // 🔔 دالة لجلب الإشعارات غير المقروءة حياً للمستخدم (كابتن أو عميل)
  async getUnreadNotifications(userId: number) {
    return await this.notificationRepository.find({
      where: { userId, isRead: false },
      order: { createdAt: 'DESC' },
    });
  }

  // 🎯 [تم التحديث والتطهير من أي اختراقات للنوع]: حماية الـ Fallback وقتل الـ Timeout نهائياً
  // 🎯 [تحديث] دالة إنشاء الطلب مع حقن السعر التقديري في قاعدة البيانات
  async createOrder(customerId: number, orderData: CreateOrderDto) {
    // 🔐 Storage paths are the server's to assign, never the caller's.
    //
    // `FilesService.canRead` grants access to an upload by finding the row that
    // references its path. Naming an arbitrary path here therefore *created*
    // permission to read it: a customer could point `prescriptionImageUrl` at
    // another driver's payment proof, or at somebody else's prescription, and
    // then download it legitimately as a party to their own order.
    //
    // The controller overwrites `itemsImageUrl` from the real upload when a
    // file is attached — but only then, so a request with no file kept whatever
    // the client sent. Clearing all three here closes that, and costs nothing:
    // the app has never sent any of them (the pharmacy screen uploads its scan
    // as `itemsImage`).
    // `itemsImageUrl` is cleared in the controller, which is where the real
    // upload replaces it; these two have no upload path at all, so they are
    // simply dropped.
    orderData.prescriptionImageUrl = undefined;
    orderData.voiceNoteUrl = undefined;

    // تأمين تحويل الـ itemsDescription نصياً
    let processedItems = 'تفاصيل شحنة فارغة';
    if (orderData.itemsDescription) {
      if (Array.isArray(orderData.itemsDescription)) {
        const itemsArray = orderData.itemsDescription as unknown[];
        processedItems = itemsArray.map((item) => String(item)).join(', ');
      } else {
        processedItems = String(orderData.itemsDescription);
      }
    }

    // 📍 Real destination coordinates are required — no hardcoded fallback.
    if (!isValidCoordinate(orderData.latitude, orderData.longitude)) {
      throw new BadRequestException(
        'يجب تحديد موقع التوصيل على الخريطة قبل إنشاء الطلب',
      );
    }

    const orderType = this.resolveOrderType(orderData);

    // 🛒 An itemised order is priced from the catalog, never from the client.
    // `itemsPrice` used to be whatever number the app put in the request.
    let orderItems: Partial<OrderItem>[] = [];
    let itemsPrice = Number(orderData.itemsPrice) || 0;

    if (orderData.items?.length) {
      if (!orderData.merchantId) {
        throw new BadRequestException('الطلب المفصّل لازم يكون من متجر محدد');
      }
      // 🏪 The shop has to be open before anything is priced. Checking the
      // products alone was not enough: an item stays `isAvailable` when a
      // kitchen closes for the night, so a cart could be built and charged
      // against a store that was never going to cook it.
      await this.catalogService.assertMerchantCanTakeOrders(
        orderData.merchantId,
      );
      const catalog = await this.catalogService.getSellableProducts(
        orderData.merchantId,
        orderData.items.map((line) => line.productId),
      );
      const built = buildOrderItems(orderData.items, catalog);
      orderItems = built.items;
      itemsPrice = built.itemsTotal;
      processedItems = built.description;
    }

    if (orderType === OrderType.PHARMACY && !orderData.pharmacyName?.trim()) {
      throw new BadRequestException('اكتب اسم الصيدلية المطلوبة');
    }

    // 💰 The fee is decided here and nowhere else. Nothing the client sends can
    // set or influence it — the app passes areas, the server passes back money.
    const pricing = await this.resolvePricing(customerId, orderData);
    const distanceKm = pricing.distanceKm;
    const estimatedDeliveryFee = pricing.deliveryFee;

    const order = this.orderRepository.create({
      customerId: customerId || orderData.customerId,
      orderType,
      merchantId: orderData.merchantId ?? null,
      categoryType: orderData.categoryType || 'طلب عام',
      storeName: orderData.storeName || 'غير محدد',
      pharmacyName: orderData.pharmacyName?.trim() || null,
      prescriptionImageUrl: orderData.prescriptionImageUrl ?? null,
      recipientPhone: orderData.recipientPhone?.replace(/[^0-9]/g, '') || null,
      recipientName: orderData.recipientName?.trim() || null,
      itemsDescription: processedItems,
      customerName: orderData.customerName || 'عميل وصل',
      customerPhone: orderData.customerPhone || '',
      deliveryAddressText:
        orderData.deliveryAddressText || 'العنوان محدد على الخريطة',

      latitude: orderData.latitude,
      longitude: orderData.longitude,
      pickupAddressText: orderData.pickupAddressText,
      pickupLatitude: orderData.pickupLatitude,
      pickupLongitude: orderData.pickupLongitude,
      pickupZoneId: pricing.pickupZoneId,
      dropoffZoneId: pricing.dropoffZoneId,
      distanceKm,
      estimatedDeliveryFee,
      pricingSource: pricing.source,

      itemsPrice,
      // Cash on delivery is the only method the platform can actually collect
      // through, so it is not negotiable by the request.
      paymentMethod: PaymentMethod.COD,
      paymentStatus: PaymentStatus.COD_DUE,
      itemsImageUrl: orderData.itemsImageUrl,
      voiceNoteUrl: orderData.voiceNoteUrl,

      status: OrderStatus.PENDING_OFFERS,
    });

    const savedOrder = await this.orderRepository.save(order);

    if (orderItems.length) {
      await this.orderItemRepository.insert(
        orderItems.map((item) => ({ ...item, orderId: savedOrder.id })),
      );
    }

    // 🚀 Offer it to the three nearest eligible, unoccupied drivers.
    await this.openFirstWave(savedOrder);

    return savedOrder;
  }

  /**
   * Which contract an order follows.
   *
   * Explicit when the app says so. Otherwise inferred, so builds that predate
   * typed orders keep behaving: a run with both areas and nothing bought is a
   * Waslly courier job, and anything else stays `general`.
   */
  private resolveOrderType(orderData: CreateOrderDto): OrderType {
    if (orderData.orderType) return orderData.orderType;
    if (orderData.pickupZoneId && orderData.dropoffZoneId) {
      return OrderType.WASLLY;
    }
    return OrderType.GENERAL;
  }

  /**
   * Strips fields the viewer is not entitled to.
   *
   * The recipient's phone belongs to a third party who never agreed to be in
   * this app. The assigned driver needs it to hand the parcel over; a driver
   * merely browsing the marketplace does not, and neither does anyone else.
   * Enforced here rather than by trusting the app to hide a field it was sent.
   */
  /**
   * The assigned driver, as the customer is allowed to see them.
   *
   * `relations: { acceptedDriver: true }` loads the whole `User` row, and
   * spreading that into the response handed the customer the driver's **bcrypt
   * password hash**, along with their email, Firebase uid, admin notes and
   * account status. Verified against a real database, not inferred: the payload
   * really did contain `passwordHash`.
   *
   * What the customer actually needs is who is coming and how to reach them.
   * Anything else about that person is not theirs to have, so this projects
   * explicitly rather than removing known-bad keys — a deny-list would leak
   * again the moment a column is added to `User`.
   */
  private publicDriver(driver: User | null | undefined) {
    if (!driver) return null;
    return {
      id: driver.id,
      name: driver.name,
      phone: driver.phone,
    };
  }

  private redactForViewer<
    T extends {
      customerId?: number;
      acceptedDriverId?: number | null;
      recipientPhone?: string | null;
      customerPhone?: string | null;
    },
  >(order: T, viewer: AuthUser): T {
    const isCustomer = Number(order.customerId) === Number(viewer.sub);
    const isAssignedDriver =
      order.acceptedDriverId != null &&
      Number(order.acceptedDriverId) === Number(viewer.sub);

    if (isCustomer || isAssignedDriver || viewer.role === UserRole.ADMIN) {
      return order;
    }
    return { ...order, recipientPhone: null, customerPhone: null };
  }

  /**
   * Decides what an order costs, and records which rule decided it.
   *
   * Precedence, highest first:
   *
   *  1. **Waslly** — both areas supplied ⇒ the fixed route fee. An area pair
   *     with no approved rate is refused outright; falling back to distance
   *     here would quietly sell an unsupported route.
   *  2. **Normal** — a destination area, either supplied explicitly or taken
   *     from the customer's own profile ⇒ that area's flat fee.
   *  3. **Legacy distance** — nothing but coordinates, which means an app build
   *     that predates areas. Kept working rather than broken.
   *
   * `distanceKm` is measured whenever both ends are known, but only *prices*
   * the order in case 3 — for zone-priced orders it is recorded as trip
   * metadata for the driver and has no effect on the money.
   */
  private async resolvePricing(
    customerId: number,
    orderData: CreateOrderDto,
  ): Promise<{
    deliveryFee: number;
    source: PricingSource;
    pickupZoneId?: number;
    dropoffZoneId?: number;
    distanceKm?: number;
  }> {
    const distanceKm = isValidCoordinate(
      orderData.pickupLatitude,
      orderData.pickupLongitude,
    )
      ? roundKm(
          haversineKm(
            {
              // `isValidCoordinate` is a type predicate on the latitude only,
              // which is why the longitude still needs the assertion.
              latitude: orderData.pickupLatitude,
              longitude: orderData.pickupLongitude!,
            },
            { latitude: orderData.latitude, longitude: orderData.longitude },
          ),
        )
      : undefined;

    // 1. Waslly route.
    if (orderData.pickupZoneId && orderData.dropoffZoneId) {
      const quote = await this.pricingService.quoteForZones(
        orderData.pickupZoneId,
        orderData.dropoffZoneId,
      );
      return {
        deliveryFee: quote.deliveryFee,
        source: PricingSource.WASLLY_ROUTE,
        pickupZoneId: orderData.pickupZoneId,
        dropoffZoneId: orderData.dropoffZoneId,
        distanceKm,
      };
    }

    // 2. Normal order — destination area only.
    const dropoffZoneId =
      orderData.dropoffZoneId ??
      (
        await this.userRepository.findOne({
          where: { id: customerId },
          select: { id: true, customerZoneId: true },
        })
      )?.customerZoneId;

    if (dropoffZoneId) {
      const quote =
        await this.pricingService.quoteForDestinationZone(dropoffZoneId);
      return {
        deliveryFee: quote.deliveryFee,
        source: PricingSource.NORMAL_ZONE,
        dropoffZoneId,
        distanceKm,
      };
    }

    // 3. Legacy fallback.
    return {
      deliveryFee: this.pricingService.quoteForDistance(distanceKm ?? 0)
        .deliveryFee,
      source: PricingSource.LEGACY_DISTANCE,
      distanceKm,
    };
  }

  /**
   * Assigns an order to the driver who accepted it — exactly one of them.
   *
   * Three separate races have to be impossible here, and each has its own
   * guard rather than one lock being asked to cover all of them:
   *
   *  1. **Two drivers, one order.** The order row is locked, then claimed with
   *     a conditional update that requires it still be unassigned. Whoever
   *     loses affects zero rows and is told the order is gone.
   *  2. **One driver, two orders.** The one-active-order rule. Checked here
   *     under the lock, and backed by a partial unique index on
   *     `orders (accepted_driver_id)` over the active statuses — so two
   *     acceptances arriving together on *different* orders still cannot both
   *     land, whatever the timing.
   *  3. **An offer that lapsed mid-request.** `markWinnerWithin` only promotes
   *     an assignment row that is still `offered`; a sweep that expired it a
   *     moment ago wins, and acceptance is refused.
   *
   * The price is not part of any of this. It was decided at creation and is
   * copied across as-is.
   */
  async acceptAvailableOrder(orderId: number, driverId: number) {
    const result = await this.orderRepository.manager.transaction(
      async (manager) => {
        const orders = manager.getRepository(Order);
        const order = await orders.findOne({
          where: { id: orderId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!order) throw new NotFoundException('الطلب غير موجود');
        if (order.status !== OrderStatus.PENDING_OFFERS) {
          // The row lock means the loser of a race lands here, not in a
          // duplicate assignment.
          throw new ConflictException('الطلب تم إسناده أو لم يعد متاحًا');
        }

        // 🔐 Approval first: an unreviewed driver must never hold an order,
        // because completing one charges commission against their wallet.
        const [driverUser, driver] = await Promise.all([
          manager.findOne(User, { where: { id: driverId } }),
          manager.findOne(DeliveryPartner, { where: { userId: driverId } }),
        ]);
        assertDriverEligible(driverUser, driver);

        if (!driver!.isOnline) {
          throw new BadRequestException('يجب أن تكون متصلًا لاستقبال الطلبات');
        }
        if (
          Number(driver!.balance) < this.pricingService.minWalletToGoOnline()
        ) {
          throw new BadRequestException(
            'رصيد المحفظة لا يسمح باستقبال الطلبات، يرجى الشحن أولاً',
          );
        }

        // 🚚 One active order at a time.
        const active = await orders.count({
          where: {
            acceptedDriverId: driverId,
            status: In([...DRIVER_ACTIVE_STATUSES]),
          },
        });
        if (active > 0) {
          throw new ConflictException(
            'لديك طلب قيد التنفيذ بالفعل، أنهِه أولاً قبل استلام طلب جديد',
          );
        }

        // 🎯 The order has to have been offered to them. Without this the
        // targeted waves would be decorative: any driver could accept anything
        // by calling the route directly, which is the open marketplace again.
        const won = await OrderAssignmentService.markWinnerWithin(
          manager,
          orderId,
          driverId,
        );
        if (!won) {
          throw new ConflictException(
            'انتهت مهلة هذا العرض أو لم يعد متاحًا لك',
          );
        }

        // Claim the order itself, conditional on it still being unclaimed.
        const claimed = await manager.update(
          Order,
          {
            id: orderId,
            status: OrderStatus.PENDING_OFFERS,
          },
          {
            acceptedDriverId: driverId,
            // The fee was decided by the server at creation; acceptance
            // freezes it rather than recomputing, so a rate change mid-flight
            // can't move it.
            finalDeliveryFee: Number(order.estimatedDeliveryFee),
            status: OrderStatus.ACCEPTED,
            acceptedAt: new Date(),
          },
        );
        if (!claimed.affected) {
          throw new ConflictException('الطلب تم إسناده أو لم يعد متاحًا');
        }

        const saved = await orders.findOne({ where: { id: orderId } });
        return { order: saved!, customerId: order.customerId };
      },
    );

    await this.createNotification(
      result.customerId,
      'تم إسناد الكابتن',
      `تم قبول طلبك رقم ${result.order.id} وسيبدأ الكابتن التنفيذ قريبًا.`,
    );
    return result.order;
  }

  /**
   * Opens the first assignment wave on a newly created order.
   *
   * This replaced a broadcast: every online driver within an expanding radius
   * used to get a "new order near you" notification and then race each other
   * to it. Now three specific drivers are offered the order for sixty seconds
   * and only they can take it — the notification goes to the people who can
   * actually act on it.
   *
   * Failures here are logged, not thrown: an order that was created and priced
   * must not be rolled back because the matching pass had a bad moment. The
   * sweep re-waves anything left sitting in `pending_offers`.
   */
  private async openFirstWave(order: Order): Promise<void> {
    try {
      // The wave notifies the drivers it offers to — here and on every later
      // wave the sweep opens. Doing it there rather than here is what keeps
      // one notification per offer instead of one only for the first round.
      await this.assignmentService.openNextWave(order.id);
    } catch (error) {
      console.error('💥 [ASSIGNMENT WAVE ERROR]:', error);
    }
  }

  // 🗑️ Driver bidding is gone. `submitOffer`, `getOrderOffers` and
  // `acceptOffer` used to live here and let a driver name their own delivery
  // fee, which `acceptOffer` then wrote straight onto `finalDeliveryFee` with
  // no bound check against the zone table. That made the driver, not the
  // server, the last word on price.
  //
  // The delivery fee now comes from the central zone rate table and nowhere
  // else: `createOrder` quotes it, and `acceptAvailableOrder` freezes that
  // quote onto the order. A driver accepts an order or does not.
  //
  // This is unrelated to the price *proposals* in OrderChatService — those
  // change `itemsPrice`, what the goods actually cost at the shop, and only
  // ever with the customer's explicit approval.

  /**
   * Platform commission for a delivery fee, using the configurable percentage
   * from settings (was previously a flat hardcoded 5 EGP).
   */
  calculateWaslCommission(deliveryFee: number): number {
    return this.pricingService.commissionForFee(deliveryFee);
  }

  /**
   * Advances an order one step along the lifecycle.
   *
   * This used to take a status off the query string and assign it. Any value in
   * the enum was accepted from any state, by anyone the ownership check let
   * through — so an order could jump from `accepted` straight to `completed`,
   * skipping the pickup, and a finished order could be "completed" again and
   * again, charging commission each time.
   *
   * Now the move has to exist in {@link assertTransitionAllowed}'s graph, and
   * completion is not reachable from here at all: it moves money, so it has its
   * own endpoint ({@link completeOrder}).
   */
  async updateStatus(
    orderId: number,
    status: OrderStatus,
    extraData?: {
      itemsPrice?: number;
      invoiceImageUrl?: string;
    },
    user?: AuthUser,
  ) {
    // 🔐 Status drives the order, so only the assigned driver — or an admin —
    // may advance it. `getOrderFor` proves the caller *is* that driver.
    const order = user
      ? await this.getOrderFor(orderId, user, 'driver')
      : await this.orderRepository.findOne({ where: { id: orderId } });

    if (!order) {
      throw new NotFoundException('الطلب غير موجود');
    }

    if (status === OrderStatus.COMPLETED) {
      throw new BadRequestException(
        'إنهاء الطلب له مسار مخصص، استخدم تأكيد التسليم',
      );
    }

    // 🔐 Cancellation charges a wallet, so it has its own routes with their own
    // rules — a reason, a penalty, an appeal. Without this, an admin could put
    // `cancelled` in the query string and terminate an order with no record and
    // no penalty, which is exactly the bypass the dedicated routes exist to
    // prevent. See OrderCancellationService.
    if (status === OrderStatus.CANCELLED) {
      throw new BadRequestException(
        'إلغاء الطلب له مسار مخصص بقواعده، لا يتم من هنا',
      );
    }

    assertTransitionAllowed(
      order.status,
      status,
      'driver',
      user?.role ?? UserRole.ADMIN,
    );

    order.status = status;
    if (status === OrderStatus.DELIVERING) {
      order.deliveringAt = new Date();
    }

    // 🔐 The receipt is the driver's report of what they paid — but the *price*
    // is not theirs to change. This route used to write whatever number the
    // driver sent, so a customer discovered the new total when they were asked
    // to pay it. A differing figure is now refused and the driver is sent to
    // the price-change request, which the customer explicitly approves or
    // rejects (see OrderChatService.decideProposal — the only writer of
    // `itemsPrice` after creation).
    if (extraData?.itemsPrice !== undefined) {
      const current = Number(order.itemsPrice) || 0;
      if (Number(extraData.itemsPrice) !== current) {
        throw new BadRequestException(
          'لا يمكن تعديل سعر المشتريات مباشرة. أرسل طلب تعديل سعر ليوافق عليه العميل.',
        );
      }
    }

    if (extraData?.invoiceImageUrl) {
      order.invoiceImageUrl = extraData.invoiceImageUrl;
    }

    // 🔔 [إشعارات رحلة التوصيل الحية للعميل بناءً على تغير الحالة]:
    if (status === OrderStatus.ACCEPTED) {
      await this.createNotification(
        order.customerId,
        '🤝 تم تأكيد الطلب',
        `وافق الكابتن على توصيل طلبك رقم FL-${orderId} وجاري بدء التجهيز.`,
      );
    } else if (status === OrderStatus.AT_STORE) {
      await this.createNotification(
        order.customerId,
        '🏪 الكابتن وصل للمحل',
        `الكابتن وصل لموقع الشراء وجاري تجهيز طلبك رقم FL-${orderId}.`,
      );
    } else if (status === OrderStatus.ITEMS_BOUGHT) {
      await this.createNotification(
        order.customerId,
        '🧾 تم شراء المنتجات',
        `تم شراء منتجات طلبك رقم FL-${orderId}. راجع الفاتورة ووافق للمتابعة.`,
      );
    } else if (status === OrderStatus.DELIVERING) {
      await this.createNotification(
        order.customerId,
        '🚴 الكابتن في الطريق!',
        `تحرك الكابتن الآن وهو في طريقه إليك لتسليم الطلب FL-${orderId}.`,
      );
    }

    return await this.orderRepository.save(order);
  }

  /**
   * Marks an order delivered and settles it — the only path that does.
   *
   * The customer is not asked to confirm: they already have their delivery, and
   * making the driver's payout wait on a tap the customer may never make would
   * strand money indefinitely.
   *
   * Everything happens inside one transaction, behind a row lock on the order:
   *
   *  - the order must be `delivering`, so a driver cannot skip the trip;
   *  - the caller must be the assigned driver;
   *  - the order must not already be settled;
   *  - the commission is computed from the fee **frozen on the order**, never
   *    from today's settings;
   *  - the debit carries `order-<id>-commission` as its reference, which is
   *    UNIQUE in the database.
   *
   * That last point is what makes a double tap harmless: two requests that both
   * pass every check still collide on the unique index, and the loser's
   * transaction — including its balance update — rolls back in full. The retry
   * then sees `settled` and returns the same result instead of charging again.
   */
  async completeOrder(orderId: number, user: AuthUser) {
    const outcome = await this.orderRepository.manager.transaction(
      async (manager) => {
        const order = await manager.findOne(Order, {
          where: { id: orderId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!order) throw new NotFoundException('الطلب غير موجود');

        const isAssignedDriver =
          order.acceptedDriverId != null &&
          Number(order.acceptedDriverId) === Number(user.sub);
        if (!isAssignedDriver && user.role !== UserRole.ADMIN) {
          throw new ForbiddenException('هذا الطلب غير مسند لك');
        }

        // Retrying a completion that already went through is a success, not an
        // error — the client may simply have lost the first response.
        if (order.settlementStatus === SettlementStatus.SETTLED) {
          return { order, alreadySettled: true, commission: 0, balance: null };
        }

        if (order.status !== COMPLETABLE_FROM) {
          throw new BadRequestException(
            order.status === OrderStatus.COMPLETED
              ? 'الطلب مكتمل بالفعل'
              : 'لا يمكن تأكيد التسليم قبل أن يبدأ الكابتن التوصيل',
          );
        }
        if (!order.acceptedDriverId) {
          throw new BadRequestException(
            'لا يمكن إكمال طلب لم يتم إسناده لكابتن',
          );
        }

        // 💰 From the snapshot on the order, not from live settings.
        const deliveryFee = Number(order.finalDeliveryFee) || 0;
        const commission = this.pricingService.commissionForFee(deliveryFee);
        const driverShare = Math.round((deliveryFee - commission) * 100) / 100;
        const reference = `order-${order.id}-commission`;

        const balance =
          commission > 0
            ? await PaymentsService.creditWithin(manager, {
                driverId: order.acceptedDriverId,
                amount: -commission,
                type: WalletTxType.COMMISSION,
                note: `عمولة توصيل الطلب FL-${order.id}`,
                reference,
                orderId: order.id,
              })
            : null;

        const now = new Date();
        await manager.update(
          Order,
          { id: order.id },
          {
            status: OrderStatus.COMPLETED,
            completedAt: now,
            commissionAmount: commission,
            driverShare,
            settlementStatus: SettlementStatus.SETTLED,
            settledAt: now,
            settlementReference: reference,
          },
        );

        // Falling under the minimum takes the driver offline, so they stop
        // receiving work until they top up.
        if (
          balance != null &&
          balance < this.pricingService.minWalletToGoOnline()
        ) {
          await manager.update(
            DeliveryPartner,
            { userId: order.acceptedDriverId },
            { isOnline: false },
          );
        }

        return {
          order: { ...order, status: OrderStatus.COMPLETED },
          alreadySettled: false,
          commission,
          balance,
        };
      },
    );

    // Notifications sit outside the transaction: a failure to notify must not
    // roll back a completed delivery and its settlement.
    if (!outcome.alreadySettled) {
      await this.createNotification(
        outcome.order.customerId,
        '🏁 تم توصيل طلبك بنجاح',
        `يسعدنا دائماً خدمتك! تم إنهاء وتوصيل الطلب FL-${orderId} بنجاح.`,
      );
      if (outcome.order.acceptedDriverId && outcome.balance != null) {
        await this.createNotification(
          outcome.order.acceptedDriverId,
          '💰 تم خصم عمولة الطلب',
          `تم خصم ${outcome.commission} ج.م من محفظتك لإكمال الطلب FL-${orderId}. رصيدك الحالي: ${outcome.balance.toFixed(2)} ج.م.`,
        );
      }
    }

    return {
      success: true,
      alreadySettled: outcome.alreadySettled,
      orderId,
      status: OrderStatus.COMPLETED,
      commission: outcome.commission,
    };
  }

  async getDriverProfile(driverId: number) {
    return await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });
  }

  async deleteDriverProfile(driverId: number) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });

    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود بالفعل في النظام');
    }

    return await this.deliveryRepository.remove(driver);
  }

  // 🔐 Live tracking exposes the customer's address/phone and the driver's GPS,
  // so it is limited to the two parties on the order (or an admin).
  async getOrderDetailsForCustomer(orderId: number, user: AuthUser) {
    await this.getOrderFor(orderId, user, 'any');

    const order = await this.orderRepository.findOne({
      where: { id: orderId },
      relations: {
        acceptedDriver: true,
        items: true,
      },
    });

    if (!order) {
      throw new NotFoundException('الطلب غير موجود في النظام');
    }

    // 🛰️ Merge the driver's LIVE GPS location (stored on DeliveryPartner, not
    // on User) into the accepted-driver payload so the customer's tracking map
    // can actually follow the driver in real time.
    let driverLocation: {
      latitude: number | null;
      longitude: number | null;
      lastLocationUpdate: Date | null;
      rating: number;
    } | null = null;

    if (order.acceptedDriverId) {
      const partner = await this.deliveryRepository.findOne({
        where: { userId: order.acceptedDriverId },
      });
      if (partner) {
        driverLocation = {
          latitude: partner.currentLatitude ?? null,
          longitude: partner.currentLongitude ?? null,
          lastLocationUpdate: partner.lastLocationUpdate ?? null,
          rating: Number(partner.rating ?? 5),
        };
      }
    }

    console.log(
      `📡 [LIVE SYNC] الطلب رقم FL-${orderId} حالته الحالية في الداتابيز هي: ${order.status}`,
    );

    // Spread keeps every existing field; the driver is projected down to what
    // the customer may see (see `publicDriver`) and enriched with live location.
    const publicDriver = this.publicDriver(order.acceptedDriver);
    return this.redactForViewer(
      {
        ...order,
        agreedDeliveryFee: Number(order.finalDeliveryFee) || null,
        acceptedDriver: publicDriver
          ? { ...publicDriver, ...driverLocation }
          : null,
      },
      user,
    );
  }

  // 🎯 Available orders for the marketplace. When a driverId is supplied and
  // the driver has a live GPS fix, each pending order is annotated with its
  // distance from the driver and the list is sorted nearest-first.
  /**
   * The marketplace, as one driver sees it.
   *
   * `viewer` drives redaction: a driver browsing orders they have not been
   * assigned must not be handed the recipient's or the customer's phone
   * number just because the row contains it.
   */
  async getAvailableOrders(driverId?: number, viewer?: AuthUser) {
    const orders = await this.loadAvailableOrders(driverId);
    if (!viewer) return orders;
    return orders.map((order) => this.redactForViewer(order, viewer));
  }

  private async loadAvailableOrders(driverId?: number) {
    const ownWork = (id: number) =>
      DRIVER_ACTIVE_STATUSES.map((status) => ({
        acceptedDriverId: id,
        status,
      }));

    // 🔐 An unapproved driver sees their own assigned work but no offers:
    // "receive new orders" is part of what approval gates, and showing work
    // they cannot accept would only produce confusing failures.
    if (driverId) {
      const [driverUser, partner] = await Promise.all([
        this.userRepository.findOne({ where: { id: driverId } }),
        this.deliveryRepository.findOne({ where: { userId: driverId } }),
      ]);
      if (!checkDriverEligibility(driverUser, partner).eligible) {
        return this.orderRepository.find({
          where: ownWork(driverId),
          order: { createdAt: 'DESC' },
        });
      }
    }

    // 📡 No open marketplace any more. A driver sees the orders they were
    // actually offered — and only while the offer is live — plus whatever they
    // are already working on. An order nobody offered them is not theirs to
    // take, so listing it would only invite a request the server refuses.
    let orders: Order[];
    if (driverId) {
      const offers = await this.assignmentService.liveOffersFor(driverId);
      const offeredIds = offers
        .filter((offer) => new Date(offer.expiresAt) > new Date())
        .map((offer) => offer.orderId);

      orders = await this.orderRepository.find({
        where: [
          ...(offeredIds.length
            ? [{ id: In(offeredIds), status: OrderStatus.PENDING_OFFERS }]
            : []),
          ...ownWork(driverId),
        ],
        order: { createdAt: 'DESC' },
      });
    } else {
      orders = await this.orderRepository.find({
        where: { status: OrderStatus.PENDING_OFFERS },
        order: { createdAt: 'DESC' },
      });
    }

    if (!driverId) return orders;

    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });
    if (
      !driver ||
      !isValidCoordinate(driver.currentLatitude, driver.currentLongitude)
    ) {
      // No driver location yet → return unsorted (newest-first) as before.
      return orders;
    }

    const origin = {
      latitude: Number(driver.currentLatitude),
      longitude: Number(driver.currentLongitude),
    };

    const enriched = orders.map((o) => {
      const targetLat = Number(o.pickupLatitude ?? o.latitude);
      const targetLng = Number(o.pickupLongitude ?? o.longitude);
      const distanceToDriverKm = isValidCoordinate(targetLat, targetLng)
        ? roundKm(
            haversineKm(origin, {
              latitude: targetLat,
              longitude: targetLng,
            }),
          )
        : null;
      return { ...o, distanceToDriverKm };
    });

    // Nearest-first; orders without coordinates sink to the bottom.
    enriched.sort(
      (a, b) =>
        (a.distanceToDriverKm ?? Number.MAX_SAFE_INTEGER) -
        (b.distanceToDriverKm ?? Number.MAX_SAFE_INTEGER),
    );

    return enriched;
  }

  async getCustomerOrders(customerId: number) {
    const orders = await this.orderRepository.find({
      where: { customerId },
      order: { createdAt: 'DESC' },
      relations: { acceptedDriver: true },
    });

    // Same projection as the tracking screen: the history list was handing out
    // the driver's full user row, password hash included.
    return orders.map((order) => ({
      ...order,
      acceptedDriver: this.publicDriver(order.acceptedDriver),
    }));
  }

  async getDriverOnlineStatus(driverId: number) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });

    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود');
    }

    // 📍 Being online is not enough to be *reachable*. Offers go to drivers
    // found by `findNearbyOnlineDrivers`, which ignores a GPS fix older than
    // `driver_location_ttl_min` — so a driver whose app stopped reporting is
    // still `is_online` while silently receiving nothing.
    //
    // That gap was invisible: the switch said online, the orders never came,
    // and nothing anywhere said why. Reporting it here is what lets the app
    // tell the driver the truth instead of the switch.
    const lastFix = driver.lastLocationUpdate
      ? new Date(driver.lastLocationUpdate)
      : null;
    const { fresh: locationFresh, ttlMinutes } =
      this.deliveryService.locationFreshness(lastFix);

    return {
      success: true,
      isOnline: driver.isOnline,
      balance: Number(driver.balance || 0),
      lastLocationUpdate: lastFix,
      locationFresh,
      locationTtlMinutes: ttlMinutes,
      // What the driver actually is, as far as the marketplace is concerned.
      receivingOffers: driver.isOnline && locationFresh,
    };
  }

  async setDriverOnlineStatus(driverId: number, isOnline: boolean) {
    const [driverUser, driver] = await Promise.all([
      this.userRepository.findOne({ where: { id: driverId } }),
      this.deliveryRepository.findOne({ where: { userId: driverId } }),
    ]);

    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود');
    }

    // 🔐 Only an approved driver may go online. Going *offline* is always
    // allowed — a driver whose approval was withdrawn must still be able to
    // stop receiving work.
    if (isOnline) {
      assertDriverEligible(driverUser, driver);
    }

    const minWallet = this.pricingService.minWalletToGoOnline();
    if (isOnline && Number(driver.balance) < minWallet) {
      throw new BadRequestException(
        `رصيد المحفظة غير كافٍ. يرجى شحن ${minWallet} ج.م على الأقل للاستمرار.`,
      );
    }

    driver.isOnline = isOnline;
    await this.deliveryRepository.save(driver);

    return {
      success: true,
      isOnline: driver.isOnline,
      balance: Number(driver.balance || 0),
    };
  }

  /**
   * 🔴 The automatic 10-minute cancellation was removed.
   *
   * It originally `delete()`d stale pending orders outright: the row vanished,
   * so a customer's order disappeared from "طلباتي" with no record and no
   * reason. Marking them `cancelled` fixed the data loss, but the behaviour
   * itself was still wrong — an order with no bids yet is not a failed order,
   * it is simply waiting, and cancelling it out from under the customer after
   * ten minutes is a decision only they should make.
   *
   * An order now stays in `pending_offers` until a driver accepts it or the
   * customer cancels it themselves (see {@link cancelOrderByCustomer}).
   *
   * If a cleanup policy is ever needed again, it belongs on a much longer
   * horizon and must notify the customer — not run silently every minute.
   */

  /**
   * Customer-initiated cancellation.
   *
   * Only allowed while the order is still `pending_offers`: once a driver has
   * accepted, they may already be on their way to the shop, so cancelling has
   * to go through support rather than a button. Ownership is enforced from the
   * token, so nobody can cancel someone else's order.
   */
  async cancelOrderByCustomer(orderId: number, user: AuthUser) {
    const order = await this.getOrderFor(orderId, user, 'customer');

    if (order.status !== OrderStatus.PENDING_OFFERS) {
      throw new BadRequestException(
        order.status === OrderStatus.CANCELLED
          ? 'الطلب ملغي بالفعل'
          : 'لا يمكن إلغاء الطلب بعد قبول كابتن له، تواصل مع الدعم',
      );
    }

    order.status = OrderStatus.CANCELLED;
    order.cancelledAt = new Date();
    await this.orderRepository.save(order);

    // Nothing to clean up behind this: with bidding gone the only way to take
    // an order is `acceptAvailableOrder`, which re-reads the status under a row
    // lock and refuses anything that is no longer PENDING_OFFERS.

    await this.createNotification(
      order.customerId,
      '❌ تم إلغاء طلبك',
      `تم إلغاء طلبك رقم FL-${orderId} بناءً على طلبك.`,
    );

    return { success: true, message: 'تم إلغاء الطلب بنجاح' };
  }

  // 🎯 حذف إشعار فردي من قاعدة البيانات (لصاحبه فقط)
  async deleteNotification(id: number, user: AuthUser) {
    const notification = await this.notificationRepository.findOne({
      where: { id },
    });
    if (!notification) {
      throw new NotFoundException('الإشعار غير موجود');
    }
    if (
      user.role !== UserRole.ADMIN &&
      Number(notification.userId) !== Number(user.sub)
    ) {
      throw new ForbiddenException('عفواً، هذا الإشعار لا يخصك');
    }

    await this.notificationRepository.delete(id);
    console.log(`🗑️ [NOTIF CLEAR] تم حذف الإشعار رقم: ${id}`);
  }

  // 🎯 مسح وتصفية كافة الإشعارات الخاصة بمستخدم محدد دفعة واحدة
  async clearAllUserNotifications(userId: number) {
    await this.notificationRepository.delete({ userId });
    console.log(
      `🗑️ [NOTIF CLEAR ALL] تم تصفية micro إشعارات المستخدم رقم: ${userId}`,
    );
  }

  // 🎯 دالة تحديث وتقييم الكابتن وحساب المتوسط الحسابي لايف
  // 🔐 `raterCustomerId` must be a customer who actually completed an order with
  // this driver — without it, anyone could inflate or tank a captain's rating.
  async updateDriverRating(
    driverId: number,
    newRating: number,
    raterCustomerId: number,
  ) {
    const completedTogether = await this.orderRepository.findOne({
      where: {
        customerId: raterCustomerId,
        acceptedDriverId: driverId,
        status: OrderStatus.COMPLETED,
      },
    });

    if (!completedTogether) {
      throw new ForbiddenException('يمكنك تقييم الكابتن فقط بعد إتمام طلب معه');
    }

    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });

    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود');
    }

    const currentRating = Number(driver.rating || 5.0);
    const calculatedAverage = (currentRating * 9 + newRating) / 10;
    driver.rating = Number(calculatedAverage.toFixed(2));

    await this.deliveryRepository.save(driver);

    console.log(
      `⭐ [RATING UPDATED] الكابتن رقم ${driverId} حصل على تقييم ${newRating}. التقييم التراكمي الحالي: ${driver.rating}`,
    );
    return { success: true, rating: driver.rating };
  }
}
