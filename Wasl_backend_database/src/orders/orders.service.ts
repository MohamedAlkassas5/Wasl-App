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

    // 🟢 إنشاء الطلب مع دمج حقل السعر التقديري (itemsPrice)
    const order = this.orderRepository.create({
      customerId: customerId || orderData.customerId,
      categoryType: orderData.categoryType || 'طلب عام',
      storeName: orderData.storeName || 'غير محدد',
      itemsDescription: processedItems,
      customerName: orderData.customerName || 'عميل فلاش المميز',
      customerPhone: orderData.customerPhone || '01xxxxxxxxx',
      deliveryAddressText:
        orderData.deliveryAddressText || 'العنوان مكتوب بالخريطة',

      // إحداثيات السادات / كوم حمادة كـ Fallbacks
      latitude: orderData.latitude || 30.463284,
      longitude: orderData.longitude || 30.702954,

      // 💰 حقن السعر التقديري (يأخذ القيمة من الـ DTO أو يضع 0 افتراضياً)
      itemsPrice: Number(orderData.itemsPrice) || 0,
      itemsImageUrl: orderData.itemsImageUrl,

      status: OrderStatus.PENDING_OFFERS,
    });

    const savedOrder = await this.orderRepository.save(order);

    // 🚀 جلب الكباتن وإرسال الإشعارات
    try {
      const drivers = await this.deliveryRepository.find({
        where: { isOnline: true },
      });
      const notificationTitle = '📦 طلب شحن جديد بالساحة!';
      const notificationMessage = `مطلوب توصيل إلى: ${order.deliveryAddressText}. افتح الساحة وقدم عرضك الحين! 🏁`;

      const notificationPromises = drivers.map((driver) => {
        return this.createNotification(
          driver.userId,
          notificationTitle,
          notificationMessage,
        );
      });

      await Promise.all(notificationPromises);
      console.log(
        `📡 [MARKETPLACE NOTIF] تم إشعار عدد ${drivers.length} كابتن بوجود الطلب الجديد رقم FL-${savedOrder.id}`,
      );
    } catch (error) {
      console.error('💥 [MARKETPLACE NOTIF ERROR]:', error);
    }

    return savedOrder;
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

  calculateWaslCommission(_deliveryFee: number): number {
    return 5;
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
        driver.balance = Number(driver.balance) - commission;

        if (Number(driver.balance) < 5) {
          driver.isOnline = false;
        }

        await this.deliveryRepository.save(driver);

        await this.createNotification(
          order.acceptedDriverId,
          '💰 تم خصم عمولة الطلب',
          `تم خصم ${commission} ج.م من محفظتك لإكمال الطلب FL-${orderId}. رصيدك الحالي: ${Number(driver.balance).toFixed(2)} ج.م.`,
        );

        console.log(
          `💰 [WASL SUCCESS] تم خصم عمولة بقيمة ${commission} ج.م من محفظة الكابتن رقم ${order.acceptedDriverId}. الرصيد الحالي: ${driver.balance}`,
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

    console.log(
      `📡 [LIVE SYNC] الطلب رقم FL-${orderId} حالته الحالية في الداتابيز هي: ${order.status}`,
    );

    return order;
  }

  // 🎯 [تم التأمين والتحديث الحقيقي لشاشات الكابتن والساحة اللوجستية]
  async getAvailableOrders(driverId?: number) {
    return await this.orderRepository.find({
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

    if (isOnline && Number(driver.balance) < 5) {
      throw new BadRequestException(
        'رصيد المحفظة غير كافٍ. يرجى شحن 100 ج.م على الأقل للاستمرار.',
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

  // 💰 دالة معالجة وتأكيد شحن المحفظة وتحديث الرصيد التراكمي في الداتابيز
  async processDriverTopUp(driverId: number, amount: number) {
    const driver = await this.deliveryRepository.findOne({
      where: { userId: driverId },
    });

    if (!driver) {
      throw new NotFoundException('حساب الكابتن غير موجود بالنظام');
    }

    driver.balance = Number(driver.balance) + Number(amount);

    await this.deliveryRepository.save(driver);

    console.log(
      `💳 [WALLET TOP-UP SUCCESS] الكابتن رقم ${driverId} شحن محفظته بـ ${amount} ج.م. الرصيد الجديد: ${driver.balance}`,
    );

    await this.createNotification(
      driverId,
      '💳 تم شحن محفظتك!',
      `نجحت عملية السداد، أضيف لحسابك بقيمة ${amount} ج.م. رصيدك الحالي: ${driver.balance} ج.م.`,
    );

    return {
      success: true,
      message: 'تم شحن المحفظة وتحديث الرصيد بنجاح',
      newBalance: driver.balance,
    };
  }
}
// import {
//   Injectable,
//   NotFoundException,
//   BadRequestException,
// } from '@nestjs/common';
// import { InjectRepository } from '@nestjs/typeorm';
// import { Repository, LessThan } from 'typeorm';
// import { Interval } from '@nestjs/schedule';

// import { Order, OrderOffer, OrderStatus } from './entities/order.entity';
// import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
// import { InAppNotification } from './entities/notification.entity';
// import { CreateOrderDto } from './dto/create-order.dto';

// @Injectable()
// export class OrdersService {
//   constructor(
//     @InjectRepository(Order)
//     private readonly orderRepository: Repository<Order>,
//     @InjectRepository(OrderOffer)
//     private readonly offerRepository: Repository<OrderOffer>,
//     @InjectRepository(DeliveryPartner)
//     private readonly deliveryRepository: Repository<DeliveryPartner>,
//     @InjectRepository(InAppNotification)
//     private readonly notificationRepository: Repository<InAppNotification>,
//   ) {}

//   // 🚀 دالة حساب إحصائيات اليوم (طلبات اليوم المكتملة فقط)
//   async getDriverDashboardStats(driverId: number) {
//     const driver = await this.deliveryRepository.findOne({
//       where: { userId: driverId },
//     });

//     const allCompletedOrders = await this.orderRepository.find({
//       where: { acceptedDriverId: driverId, status: OrderStatus.COMPLETED },
//     });

//     const today = new Date();
//     today.setHours(0, 0, 0, 0);

//     const todayOrders = allCompletedOrders.filter(
//       (order) => order.createdAt && new Date(order.createdAt) >= today,
//     );

//     let todayEarnings = 0;
//     let todayCommissions = 0;

//     todayOrders.forEach((order) => {
//       const fee = Number(order.finalDeliveryFee || 0);
//       todayEarnings += fee;
//       todayCommissions += this.calculateWaslCommission(fee);
//     });

//     return {
//       success: true,
//       balance: driver ? Number(driver.balance || 0) : 0.0,
//       todayOrdersCount: todayOrders.length,
//       todayEarnings,
//       todayCommissions,
//       rating: driver ? Number(driver.rating || 4.95) : 4.95,
//     };
//   }

//   // 🔄 تحديث الحالة (مع دعم الحقل الجديد invoiceImageUrl)
//   async updateStatus(
//     orderId: number,
//     status: OrderStatus,
//     extraData?: {
//       itemsPrice?: number;
//       invoiceImageUrl?: string;
//     },
//   ) {
//     const order = await this.orderRepository.findOne({
//       where: { id: orderId },
//     });
//     if (!order) throw new NotFoundException('الطلب غير موجود');

//     order.status = status;

//     if (extraData?.itemsPrice !== undefined) {
//       order.itemsPrice = extraData.itemsPrice;
//     }

//     if (extraData?.invoiceImageUrl !== undefined) {
//       order.invoiceImageUrl = extraData.invoiceImageUrl;
//     }

//     return await this.orderRepository.save(order);
//   }

//   // 🟢 إنشاء طلب جديد (يدعم الصورة المرفوعة)
//   // استبدل any بـ CreateOrderDto
//   async createOrder(customerId: number, orderData: CreateOrderDto) {
//     let processedItems = 'تفاصيل شحنة فارغة';
//     if (orderData.itemsDescription) {
//       processedItems = Array.isArray(orderData.itemsDescription)
//         ? orderData.itemsDescription.join(', ')
//         : String(orderData.itemsDescription);
//     }

//     // نقوم بإنشاء كائن نظيف يحتوي فقط على الحقول المطلوبة للـ Entity
//     const order = this.orderRepository.create({
//       customerId: customerId || orderData.customerId,
//       customerName: orderData.customerName,
//       customerPhone: orderData.customerPhone,
//       categoryType: orderData.categoryType,
//       storeName: orderData.storeName || 'غير محدد',
//       itemsDescription: processedItems,
//       itemsPrice: Number(orderData.itemsPrice || 0),
//       deliveryAddressText: orderData.deliveryAddressText,
//       latitude: orderData.latitude,
//       longitude: orderData.longitude,
//       // التأكد من تمرير undefined بدلاً من null لتجنب خطأ التايب
//       itemsImageUrl: orderData.itemsImageUrl || undefined,
//       status: OrderStatus.PENDING_OFFERS,
//     });

//     return await this.orderRepository.save(order);
//   }

//   // 🎯 تقديم عرض (مع التحقق من الرصيد)
//   async submitOffer(
//     driverId: number,
//     orderId: number,
//     deliveryFee: number,
//     estimatedTime: number,
//   ) {
//     const driver = await this.deliveryRepository.findOne({
//       where: { userId: driverId },
//     });
//     if (!driver) throw new NotFoundException('الكابتن غير موجود');

//     if (Number(driver.balance) <= -10.0) {
//       throw new BadRequestException('عفواً، رصيدك لا يسمح باستقبال طلبات.');
//     }

//     const offer = this.offerRepository.create({
//       orderId,
//       driverId,
//       deliveryFee,
//       estimatedTime,
//     });
//     return await this.offerRepository.save(offer);
//   }

//   // 🎯 قبول العرض
//   async acceptOffer(orderId: number, offerId: number) {
//     const offer = await this.offerRepository.findOne({
//       where: { id: offerId },
//     });
//     if (!offer) throw new NotFoundException('العرض غير موجود');

//     const order = await this.orderRepository.findOne({
//       where: { id: orderId },
//     });
//     if (!order) throw new NotFoundException('الطلب غير موجود');

//     order.status = OrderStatus.ACCEPTED;
//     order.acceptedDriverId = offer.driverId;
//     order.finalDeliveryFee = Number(offer.deliveryFee);

//     await this.orderRepository.save(order);
//     await this.offerRepository.delete({ orderId });

//     return { success: true, message: 'تم قبول العرض' };
//   }

//   calculateWaslCommission(deliveryFee: number): number {
//     return Number(((deliveryFee / 30) * 5).toFixed(2));
//   }

//   // 🎯 خدمات إضافية
//   async getUnreadNotifications(userId: number) {
//     return await this.notificationRepository.find({
//       where: { userId, isRead: false },
//       order: { createdAt: 'DESC' },
//     });
//   }

//   async getAvailableOrders(driverId?: number) {
//     return await this.orderRepository.find({
//       where: driverId
//         ? [
//             { status: OrderStatus.PENDING_OFFERS },
//             { acceptedDriverId: driverId },
//           ]
//         : { status: OrderStatus.PENDING_OFFERS },
//       order: { createdAt: 'DESC' },
//     });
//   }

//   async getDriverProfile(driverId: number) {
//     return await this.deliveryRepository.findOne({
//       where: { userId: driverId },
//     });
//   }

//   async updateDriverRating(driverId: number, newRating: number) {
//     const driver = await this.deliveryRepository.findOne({
//       where: { userId: driverId },
//     });
//     if (!driver) throw new NotFoundException('الكابتن غير موجود');
//     driver.rating = Number(
//       ((Number(driver.rating || 5.0) * 9 + newRating) / 10).toFixed(2),
//     );
//     return await this.deliveryRepository.save(driver);
//   }

//   async processDriverTopUp(driverId: number, amount: number) {
//     const driver = await this.deliveryRepository.findOne({
//       where: { userId: driverId },
//     });
//     if (!driver) throw new NotFoundException('الكابتن غير موجود');
//     driver.balance = Number(driver.balance) + Number(amount);
//     return await this.deliveryRepository.save(driver);
//   }

//   async deleteNotification(id: number) {
//     return await this.notificationRepository.delete(id);
//   }
//   async clearAllUserNotifications(userId: number) {
//     return await this.notificationRepository.delete({ userId });
//   }
//   async deleteDriverProfile(driverId: number) {
//     const driver = await this.deliveryRepository.findOne({
//       where: { userId: driverId },
//     });
//     if (!driver) throw new NotFoundException('الكابتن غير موجود');
//     return await this.deliveryRepository.remove(driver);
//   }

//   @Interval(60000)
//   async handleAutoCancelOrders() {
//     await this.orderRepository.delete({
//       status: OrderStatus.PENDING_OFFERS,
//       createdAt: LessThan(new Date(Date.now() - 600000)),
//     });
//   }
// }
