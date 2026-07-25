import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { Interval } from '@nestjs/schedule';

import { Order, OrderOffer, OrderStatus } from './entities/order.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { InAppNotification } from './entities/notification.entity';
import { CreateOrderDto } from './dto/create-order.dto';
import { PricingService } from '../pricing/pricing.service';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { WalletTxType } from '../payments/entities/wallet-transaction.entity';
import { haversineKm, roundKm, isValidCoordinate } from '../common/geo.util';

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,

    @InjectRepository(OrderOffer)
    private readonly offerRepository: Repository<OrderOffer>,

    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,

    @InjectRepository(InAppNotification)
    private readonly notificationRepository: Repository<InAppNotification>,

    private readonly pricingService: PricingService,
    private readonly deliveryService: DeliveryService,
    private readonly paymentsService: PaymentsService,
  ) {}

  // 🔔 دالة داخلية لإنشاء وحفظ الإشعارات تلقائياً في قاعدة البيانات
  async createNotification(userId: number, title: string, message: string) {
    const notification = this.notificationRepository.create({
      userId,
      title,
      message,
    });
    await this.notificationRepository.save(notification);
    console.log(
      `🔔 [NOTIFICATION SENT] إشعار جديد للمستخدم رقم ${userId}: ${title}`,
    );
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

    // 🧮 Compute trip distance + a price estimate when a pickup point exists.
    let distanceKm: number | undefined;
    let estimatedDeliveryFee = 0;
    if (
      isValidCoordinate(orderData.pickupLatitude, orderData.pickupLongitude)
    ) {
      distanceKm = roundKm(
        haversineKm(
          {
            latitude: orderData.pickupLatitude!,
            longitude: orderData.pickupLongitude!,
          },
          { latitude: orderData.latitude, longitude: orderData.longitude },
        ),
      );
      estimatedDeliveryFee =
        this.pricingService.quoteForDistance(distanceKm).deliveryFee;
    } else {
      // No pickup point ⇒ default to the city tier estimate.
      estimatedDeliveryFee =
        this.pricingService.quoteForDistance(0).deliveryFee;
    }

    const order = this.orderRepository.create({
      customerId: customerId || orderData.customerId,
      categoryType: orderData.categoryType || 'طلب عام',
      storeName: orderData.storeName || 'غير محدد',
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
      distanceKm,
      estimatedDeliveryFee,

      itemsPrice: Number(orderData.itemsPrice) || 0,
      itemsImageUrl: orderData.itemsImageUrl,
      voiceNoteUrl: orderData.voiceNoteUrl,

      status: OrderStatus.PENDING_OFFERS,
    });

    const savedOrder = await this.orderRepository.save(order);

    // 🚀 Notify only drivers near the PICKUP point (falls back to destination),
    // sorted nearest-first, using an expanding radius. No more blasting every
    // online driver in the whole system.
    await this.notifyNearbyDrivers(savedOrder);

    return savedOrder;
  }

  /**
   * Radius-scoped driver notification for a newly created order. Uses the
   * pickup point when available, otherwise the delivery destination.
   */
  private async notifyNearbyDrivers(order: Order): Promise<void> {
    try {
      const originLat = Number(order.pickupLatitude ?? order.latitude);
      const originLng = Number(order.pickupLongitude ?? order.longitude);

      if (!isValidCoordinate(originLat, originLng)) return;

      const { drivers, radiusKm } =
        await this.deliveryService.findNearbyWithExpansion(
          originLat,
          originLng,
        );

      const title = '📦 طلب توصيل جديد قريب منك!';
      await Promise.all(
        drivers.map((d) =>
          this.createNotification(
            d.driverId,
            title,
            `طلب توصيل إلى: ${order.deliveryAddressText} — يبعد ${d.distanceKm} كم عنك. قدّم عرضك الآن! 🏁`,
          ),
        ),
      );

      console.log(
        `📡 [MARKETPLACE NOTIF] أُشعر ${drivers.length} كابتن ضمن نطاق ${radiusKm} كم بالطلب رقم FL-${order.id}`,
      );
    } catch (error) {
      console.error('💥 [MARKETPLACE NOTIF ERROR]:', error);
    }
  }

  // 🎯 تقديم العروض + إشعار فوري للعميل بوصل عرض جديد
  async submitOffer(
    driverId: number,
    orderId: number,
    deliveryFee: number,
    estimatedTime: number,
  ) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });

    if (!driver) {
      throw new NotFoundException('الكابتن غير موجود');
    }

    if (Number(driver.balance) <= -10.0) {
      throw new BadRequestException(
        'عفواً، تم إيقاف حسابك مؤقتاً لتجاوز حد الدين المسموح به (-10 ج.م). يرجى شحن محفظتك أولاً لاستئناف استقبال الطلبات.',
      );
    }

    if (!driver.isOnline) {
      throw new BadRequestException(
        'يجب تفعيل وضع الأونلاين أولاً لتقديم عروض الأسعار.',
      );
    }

    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });

    if (!order) {
      throw new NotFoundException('الطلب غير موجود');
    }

    if (order.status !== OrderStatus.PENDING_OFFERS) {
      throw new BadRequestException('الطلب لا يستقبل عروض حالياً');
    }

    const offer = this.offerRepository.create({
      orderId,
      driverId,
      deliveryFee,
      estimatedTime,
    });

    const savedOffer = await this.offerRepository.save(offer);

    // 🎯 [إشعار فوري للعميل]: الكابتن قدم عرض سعر على طلبك
    await this.createNotification(
      order.customerId,
      '🏁 عرض سعر جديد!',
      `قدم الكابتن عرض توصيل بقيمة ${deliveryFee} ج.م لطلبك المعلق.`,
    );

    return savedOffer;
  }

  async getOrderOffers(orderId: number) {
    return await this.offerRepository.find({
      where: {
        orderId,
      },
      relations: {
        driver: true,
      },
    });
  }

  // 🎯 قبول العرض من العميل + إشعار فوري للكابتن لبدء الرحلة
  async acceptOffer(orderId: number, offerId: number) {
    const offer = await this.offerRepository.findOne({
      where: {
        id: offerId,
      },
    });

    if (!offer) {
      throw new NotFoundException('العرض غير موجود');
    }

    const order = await this.orderRepository.findOne({
      where: {
        id: orderId,
      },
    });

    if (!order) {
      throw new NotFoundException('الطلب غير موجود');
    }

    order.status = OrderStatus.ACCEPTED;
    order.acceptedDriverId = offer.driverId;
    order.finalDeliveryFee = Number(offer.deliveryFee);

    await this.orderRepository.save(order);

    await this.offerRepository.delete({
      orderId,
    });

    // 🎯 [إشعار فوري للكابتن]: العميل وافق على عرضك وبدأت الرحلة
    await this.createNotification(
      offer.driverId,
      '🚀 تم قبول عرضك!',
      `وافق العميل على عرض السعر الخاص بك للطلب FL-${orderId}. جاري بدء الرحلة والتحرك.`,
    );

    return {
      success: true,
      message: 'تم قبول العرض',
    };
  }

  /**
   * Platform commission for a delivery fee, using the configurable percentage
   * from settings (was previously a flat hardcoded 5 EGP).
   */
  calculateWaslCommission(deliveryFee: number): number {
    return this.pricingService.commissionForFee(deliveryFee);
  }

  // 🎯 تحديث الحالات + إرسال إشعارات تفاعلية متزامنة للعميل مع كل حركة للكابتن
  async updateStatus(
    orderId: number,
    status: OrderStatus,
    extraData?: {
      itemsPrice?: number;
      invoiceImageUrl?: string;
    },
  ) {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });

    if (!order) {
      throw new NotFoundException('الطلب غير موجود');
    }

    order.status = status;

    if (extraData?.itemsPrice !== undefined) {
      order.itemsPrice = extraData.itemsPrice;
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
    } else if (status === OrderStatus.COMPLETED) {
      await this.createNotification(
        order.customerId,
        '🏁 تم توصيل طلبك بنجاح',
        `يسعدنا دائماً خدمتك! تم إنهاء وتوصيل الطلب FL-${orderId} بنجاح.`,
      );
    }

    // 💰 تطبيق الحسبة والخصم من المحفظة ديناميكياً عند اكتمال الطلب
    if (status === OrderStatus.COMPLETED) {
      if (!order.acceptedDriverId) {
        throw new BadRequestException('لا يمكن إكمال طلب لم يتم قبول كابتن له');
      }

      const commission = this.calculateWaslCommission(
        Number(order.finalDeliveryFee),
      );

      const driver = await this.deliveryRepository.findOne({
        where: { userId: order.acceptedDriverId },
      });

      if (driver) {
        // Debit commission through the ledger so it's fully auditable.
        const newBalance = await this.paymentsService.credit(
          order.acceptedDriverId,
          -commission,
          WalletTxType.COMMISSION,
          `عمولة توصيل الطلب FL-${orderId}`,
        );

        const minWallet = this.pricingService.minWalletToGoOnline();
        if (newBalance < minWallet) {
          driver.isOnline = false;
          await this.deliveryRepository.save(driver);
        }

        await this.createNotification(
          order.acceptedDriverId,
          '💰 تم خصم عمولة الطلب',
          `تم خصم ${commission} ج.م من محفظتك لإكمال الطلب FL-${orderId}. رصيدك الحالي: ${newBalance.toFixed(2)} ج.م.`,
        );

        console.log(
          `💰 [WASL SUCCESS] تم خصم عمولة بقيمة ${commission} ج.م من محفظة الكابتن رقم ${order.acceptedDriverId}. الرصيد الحالي: ${newBalance}`,
        );
      }
    }

    return await this.orderRepository.save(order);
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

  async getOrderDetailsForCustomer(orderId: number) {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
      relations: {
        acceptedDriver: true,
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

    // Spread keeps every existing field; we enrich the acceptedDriver object
    // with live location and expose the agreed fee explicitly.
    return {
      ...order,
      agreedDeliveryFee: Number(order.finalDeliveryFee) || null,
      acceptedDriver: order.acceptedDriver
        ? { ...order.acceptedDriver, ...driverLocation }
        : null,
    };
  }

  // 🎯 Available orders for the marketplace. When a driverId is supplied and
  // the driver has a live GPS fix, each pending order is annotated with its
  // distance from the driver and the list is sorted nearest-first.
  async getAvailableOrders(driverId?: number) {
    const orders = await this.orderRepository.find({
      where: driverId
        ? [
            { status: OrderStatus.PENDING_OFFERS },
            { acceptedDriverId: driverId, status: OrderStatus.ACCEPTED },
            { acceptedDriverId: driverId, status: OrderStatus.AT_STORE },
            { acceptedDriverId: driverId, status: OrderStatus.ITEMS_BOUGHT },
            { acceptedDriverId: driverId, status: OrderStatus.DELIVERING },
          ]
        : { status: OrderStatus.PENDING_OFFERS },
      order: {
        createdAt: 'DESC',
      },
    });

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
    return await this.orderRepository.find({
      where: { customerId },
      order: { createdAt: 'DESC' },
      relations: { acceptedDriver: true },
    });
  }

  async getDriverOnlineStatus(driverId: number) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });

    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود');
    }

    return {
      success: true,
      isOnline: driver.isOnline,
      balance: Number(driver.balance || 0),
    };
  }

  async setDriverOnlineStatus(driverId: number, isOnline: boolean) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });

    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود');
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

  @Interval(60000)
  async handleAutoCancelOrders() {
    const tenMinutesAgo = new Date();
    tenMinutesAgo.setMinutes(tenMinutesAgo.getMinutes() - 10);

    console.log(
      `⏱️ [CRON JOB] جاري تنظيف الساحة من الطلبات المعلقة القديمة...`,
    );

    const result = await this.orderRepository.delete({
      status: OrderStatus.PENDING_OFFERS,
      createdAt: LessThan(tenMinutesAgo),
    });

    if (result.affected && result.affected > 0) {
      console.log(
        `🗑️ [CRON JOB SUCCESS] تم حذف ${result.affected} طلب معلق لتجاوزهم حاجز الـ 10 دقائق بدون مزايدة.`,
      );
    }
  }

  // 🎯 حذف إشعار فردي من قاعدة البيانات
  async deleteNotification(id: number) {
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
  async updateDriverRating(driverId: number, newRating: number) {
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

  // 🔒 [SECURITY] Self-service wallet crediting has been removed. Drivers can
  // no longer top up their own balance directly (this was exploitable). Top-ups
  // now go through PaymentsService: the driver files a request with proof of a
  // Vodafone Cash / InstaPay transfer, and an admin verifies it before the
  // balance is credited. This stub stays only to reject any legacy callers.
  processDriverTopUp(_driverId: number, _amount: number) {
    throw new BadRequestException(
      'شحن المحفظة يتم الآن عبر طلب شحن يوثّقه الأدمن بعد التحويل. الشحن الذاتي غير متاح.',
    );
  }
}
