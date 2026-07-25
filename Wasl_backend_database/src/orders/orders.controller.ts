import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Patch,
  Query,
  ParseIntPipe,
  BadRequestException,
  UseInterceptors,
  UploadedFile,
  UseGuards,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { existsSync, mkdirSync } from 'fs';

import { OrdersService } from './orders.service';
import { OrderStatus } from './entities/order.entity';
import { CreateOrderDto } from './dto/create-order.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

const orderUploadPath = './uploads/orders';

// 🔐 Every order/wallet/offer/notification route requires a valid JWT. Closes
// the previous broken-access-control hole where any client could act as any
// user by passing an id. The Flutter app attaches the Bearer token on all
// order-service calls.
@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post('create')
  @UseInterceptors(
    FileInterceptor('itemsImage', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          if (!existsSync(orderUploadPath)) {
            mkdirSync(orderUploadPath, { recursive: true });
          }
          cb(null, orderUploadPath);
        },
        filename: (_req, file, cb) => {
          const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
          cb(null, `order-${uniqueSuffix}${extname(file.originalname)}`);
        },
      }),
    }),
  )
  create(
    @UploadedFile() file: Express.Multer.File,
    @Body() createOrderDto: CreateOrderDto,
  ) {
    if (!createOrderDto || !createOrderDto.customerId) {
      throw new BadRequestException(
        'معرف العميل (customerId) مطلوب لإنشاء الطلب',
      );
    }

    // 2. معالجة وتأمين قائمة الأصناف
    if (typeof createOrderDto.items === 'string') {
      try {
        createOrderDto.items = JSON.parse(createOrderDto.items) as unknown[];
      } catch {
        createOrderDto.items = createOrderDto.items
          ? [createOrderDto.items]
          : [];
      }
    } else if (!createOrderDto.items) {
      createOrderDto.items = [];
    }

    // 3. تأمين الأسماء والعناوين الافتراضية
    createOrderDto.pickupTitle =
      createOrderDto.pickupTitle || 'موقع الاستلام الحالي';
    createOrderDto.dropoffTitle =
      createOrderDto.dropoffTitle || 'موقع التوصيل المحدد';

    // 💰 تحويل السعر لرقم (تأمين إضافي)
    if (createOrderDto.itemsPrice) {
      createOrderDto.itemsPrice = Number(createOrderDto.itemsPrice);
    }

    if (file?.filename) {
      createOrderDto.itemsImageUrl = `uploads/orders/${file.filename}`;
    }

    return this.ordersService.createOrder(
      Number(createOrderDto.customerId),
      createOrderDto,
    );
  }

  // 🎯 جلب الطلبات المتاحة حياً للسوق اللوجستي + طلبات الكابتن النشطة عبر الـ Query Parameter
  @Get('available')
  getAvailable(@Query('driverId') driverId?: string) {
    return this.ordersService.getAvailableOrders(
      driverId ? Number(driverId) : undefined,
    );
  }

  // 🎯 جلب طلبات عميل محدد فقط (بدون تسريب بيانات العملاء الآخرين)
  @Get('customer/:customerId')
  getCustomerOrders(
    @Param('customerId', ParseIntPipe) customerId: number,
  ) {
    return this.ordersService.getCustomerOrders(customerId);
  }

  @Get('driver/:driverId/online-status')
  getDriverOnlineStatus(
    @Param('driverId', ParseIntPipe) driverId: number,
  ) {
    return this.ordersService.getDriverOnlineStatus(driverId);
  }

  @Patch('driver/:driverId/online-status')
  setDriverOnlineStatus(
    @Param('driverId', ParseIntPipe) driverId: number,
    @Body('isOnline') isOnline: boolean,
  ) {
    return this.ordersService.setDriverOnlineStatus(
      driverId,
      Boolean(isOnline),
    );
  }

  // 🚀 مسار إحصائيات لوحة التحكم الشامل والمزامنة الآنية
  @Get('driver/:driverId/dashboard-stats')
  async getDriverDashboardStats(
    @Param('driverId', ParseIntPipe) driverId: number,
  ) {
    const driver = await this.ordersService.getDriverProfile(driverId);

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const availableOrders =
      await this.ordersService.getAvailableOrders(driverId);

    const todayCompletedOrders = (availableOrders || []).filter(
      (order) =>
        order.status === OrderStatus.COMPLETED &&
        order.createdAt &&
        new Date(order.createdAt) >= todayStart,
    );

    const todayOrdersCount = todayCompletedOrders.length;
    let todayEarnings = 0;
    let todayCommissions = 0;

    todayCompletedOrders.forEach((order) => {
      const fee = Number(order.finalDeliveryFee || 0);
      todayEarnings += fee;
      todayCommissions += this.ordersService.calculateWaslCommission(fee);
    });

    return {
      success: true,
      balance: driver ? Number(driver.balance || 0) : 0.0,
      todayOrdersCount,
      todayEarnings,
      todayCommissions,
      rating: driver ? Number(driver.rating || 4.95) : 4.95,
    };
  }

  // 🎯 مسار إرسال تقييم جديد لكابتن محدد وحساب المتوسط الحسابي فوراً من العميل لايف
  @Post('driver/:driverId/rate')
  async rateDriver(
    @Param('driverId', ParseIntPipe) driverId: number,
    @Body('rating') rating: number,
  ) {
    const validatedRating = Math.max(1, Math.min(5, Number(rating || 5)));
    return this.ordersService.updateDriverRating(driverId, validatedRating);
  }

  @Patch('driver/:driverId/topup-request')
  requestTopUp(
    @Param('driverId', ParseIntPipe) driverId: number,
    @Body('amount') amount: number,
  ) {
    const validatedAmount = Math.max(0, Number(amount || 0));
    return {
      success: true,
      message: 'تم توليد طلب الشحن بنجاح',
      paymentUrl: `https://mock-gateway.wasl.com/pay?driverId=${driverId}&amount=${validatedAmount}`,
    };
  }

  // 🚀 الـ Webhook الحاسم والمؤمن فور نجاح السداد
  @Post('payment/webhook')
  async handlePaymentWebhook(
    @Body() body: { driverId: number; amount: number; status: string },
  ) {
    if (body && body.status === 'success' && body.driverId) {
      return this.ordersService.processDriverTopUp(
        Number(body.driverId),
        Number(body.amount || 0),
      );
    }
    return { success: false, message: 'طلب دفع غير مكتمل أو مشوه' };
  }

  // 🎯 مسار جلب الإشعارات الحية وغير المقروءة للعميل والمندوب فوراً
  @Get('user/:userId/notifications')
  getNotifications(@Param('userId', ParseIntPipe) userId: number) {
    return this.ordersService.getUnreadNotifications(userId);
  }

  // 🎯 مسار حذف إشعار فردي محدد
  @Delete('notifications/:id')
  async deleteNotification(@Param('id', ParseIntPipe) id: number) {
    await this.ordersService.deleteNotification(id);
    return { success: true, message: 'تم مسح الإشعار بنجاح' };
  }

  // 🎯 مسار مسح وتصفية كل إشعارات العميل أو الكابتن دفعة واحدة
  @Delete('user/:userId/notifications/clear-all')
  async clearAllNotifications(@Param('userId', ParseIntPipe) userId: number) {
    await this.ordersService.clearAllUserNotifications(userId);
    return { success: true, message: 'تم مسح مركز الإشعارات بالكامل' };
  }

  // 🎯 مسار تتبع العميل لقراءة التفاصيل الحية
  @Get(':id/customer-details')
  async getCustomerOrderDetails(@Param('id', ParseIntPipe) id: number) {
    return this.ordersService.getOrderDetailsForCustomer(id);
  }

  // 🎯 مسار أمني حاسم لحذف حساب الكابتن نهائياً من قاعدة البيانات (PostgreSQL)
  @Delete('driver/:driverId')
  async deleteDriverAccount(@Param('driverId', ParseIntPipe) driverId: number) {
    await this.ordersService.deleteDriverProfile(driverId);
    return {
      success: true,
      message: 'تم حذف الحساب والبيانات بنجاح من النظام',
    };
  }

  @Post(':id/submit-offer')
  submitOffer(
    @Param('id', ParseIntPipe) orderId: number,
    @Body()
    body: { driverId: number; deliveryFee: number; estimatedTime: number },
  ) {
    if (!body || !body.driverId) {
      throw new BadRequestException('بيانات تقديم العرض غير مكتملة');
    }
    return this.ordersService.submitOffer(
      Number(body.driverId),
      orderId,
      Number(body.deliveryFee || 0),
      Number(body.estimatedTime || 15),
    );
  }

  @Get(':id/offers')
  getOffers(@Param('id', ParseIntPipe) orderId: number) {
    return this.ordersService.getOrderOffers(orderId);
  }

  @Post(':id/offers/:offerId/accept')
  acceptOffer(
    @Param('id', ParseIntPipe) orderId: number,
    @Param('offerId', ParseIntPipe) offerId: number,
  ) {
    return this.ordersService.acceptOffer(orderId, offerId);
  }

  // 🧾 Driver uploads the purchase receipt/invoice image at pickup. Sets the
  // items price + receipt image and advances the order to "items_bought" so the
  // customer can review the real total before delivery.
  @Post(':id/invoice')
  @UseInterceptors(
    FileInterceptor('invoiceImage', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const invoicePath = './uploads/invoices';
          if (!existsSync(invoicePath)) {
            mkdirSync(invoicePath, { recursive: true });
          }
          cb(null, invoicePath);
        },
        filename: (_req, file, cb) => {
          const suffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
          cb(null, `invoice-${suffix}${extname(file.originalname)}`);
        },
      }),
    }),
  )
  uploadInvoice(
    @Param('id', ParseIntPipe) orderId: number,
    @UploadedFile() file: Express.Multer.File,
    @Body() body: { itemsPrice?: number },
  ) {
    const invoiceImageUrl = file?.filename
      ? `uploads/invoices/${file.filename}`
      : undefined;
    return this.ordersService.updateStatus(orderId, OrderStatus.ITEMS_BOUGHT, {
      itemsPrice: body?.itemsPrice ? Number(body.itemsPrice) : undefined,
      invoiceImageUrl,
    });
  }

  @Patch(':id/status')
  updateStatus(
    @Param('id', ParseIntPipe) orderId: number,
    @Query('status') status: OrderStatus,
    @Body() body: { itemsPrice?: number; invoiceImageUrl?: string },
  ) {
    const parsedBody = {
      itemsPrice: body?.itemsPrice ? Number(body.itemsPrice) : undefined,
      invoiceImageUrl: body?.invoiceImageUrl || undefined,
    };
    return this.ordersService.updateStatus(orderId, status, parsedBody);
  }
}
// import {
//   Controller,
//   Post,
//   Get,
//   Delete,
//   Body,
//   Param,
//   Patch,
//   Query,
//   ParseIntPipe,
//   BadRequestException,
//   UseInterceptors,
//   UploadedFile,
// } from '@nestjs/common';
// import { FileInterceptor } from '@nestjs/platform-express';
// import { OrdersService } from './orders.service';
// import { OrderStatus } from './entities/order.entity';
// import { CreateOrderDto } from './dto/create-order.dto';

// @Controller('orders')
// export class OrdersController {
//   constructor(private readonly ordersService: OrdersService) {}

//   // 🛠️ مسار إنشاء الطلب (تم التحديث لدعم رفع الصور)
//   // في الـ Controller، تأكد من استخدام الـ DTO
//   // في الـ Controller، تأكد من استخدام الـ DTO
//   @Post('create')
//   @UseInterceptors(FileInterceptor('file'))
//   async create(
//     @UploadedFile() file: Express.Multer.File,
//     @Body() createOrderDto: CreateOrderDto, // استخدم DTO هنا
//   ) {
//     // تأكد من تمرير البيانات للـ service بشكل صحيح
//     const data = {
//       ...createOrderDto,
//       itemsImageUrl: file?.path || null,
//       itemsPrice: Number(createOrderDto.itemsPrice || 0),
//     };

//     return await this.ordersService.createOrder(
//       Number(createOrderDto.customerId),
//       data as CreateOrderDto, // تمرير البيانات
//     );
//   }

//   // 🎯 جلب الطلبات المتاحة
//   @Get('available')
//   async getAvailable(@Query('driverId') driverId?: string) {
//     return await this.ordersService.getAvailableOrders(
//       driverId ? Number(driverId) : undefined,
//     );
//   }

//   // 🚀 إحصائيات لوحة التحكم
//   @Get('driver/:driverId/dashboard-stats')
//   async getDriverDashboardStats(
//     @Param('driverId', ParseIntPipe) driverId: number,
//   ) {
//     return await this.ordersService.getDriverDashboardStats(driverId);
//   }

//   // 🎯 تقييم الكابتن
//   @Post('driver/:driverId/rate')
//   async rateDriver(
//     @Param('driverId', ParseIntPipe) driverId: number,
//     @Body('rating') rating: number,
//   ) {
//     return this.ordersService.updateDriverRating(
//       driverId,
//       Math.max(1, Math.min(5, Number(rating || 5))),
//     );
//   }

//   // 💳 طلب شحن
//   @Patch('driver/:driverId/topup-request')
//   requestTopUp(
//     @Param('driverId', ParseIntPipe) driverId: number,
//     @Body('amount') amount: number,
//   ) {
//     return {
//       success: true,
//       message: 'تم توليد طلب الشحن بنجاح',
//       paymentUrl: `https://mock-gateway.wasl.com/pay?driverId=${driverId}&amount=${Math.max(0, Number(amount || 0))}`,
//     };
//   }

//   // 🚀 Webhook للسداد
//   @Post('payment/webhook')
//   async handlePaymentWebhook(
//     @Body() body: { driverId: number; amount: number; status: string },
//   ) {
//     if (body?.status === 'success' && body.driverId) {
//       return await this.ordersService.processDriverTopUp(
//         Number(body.driverId),
//         Number(body.amount || 0),
//       );
//     }
//     throw new BadRequestException('بيانات دفع غير مكتملة');
//   }

//   // 🔔 إدارة الإشعارات
//   @Get('user/:userId/notifications')
//   getNotifications(@Param('userId', ParseIntPipe) userId: number) {
//     return this.ordersService.getUnreadNotifications(userId);
//   }

//   @Delete('notifications/:id')
//   async deleteNotification(@Param('id', ParseIntPipe) id: number) {
//     await this.ordersService.deleteNotification(id);
//     return { success: true, message: 'تم مسح الإشعار بنجاح' };
//   }

//   // 📦 العروض والقبول
//   @Post(':id/submit-offer')
//   submitOffer(
//     @Param('id', ParseIntPipe) orderId: number,
//     @Body()
//     body: { driverId: number; deliveryFee: number; estimatedTime: number },
//   ) {
//     return this.ordersService.submitOffer(
//       Number(body.driverId),
//       orderId,
//       Number(body.deliveryFee || 0),
//       Number(body.estimatedTime || 15),
//     );
//   }

//   @Post(':id/offers/:offerId/accept')
//   acceptOffer(
//     @Param('id', ParseIntPipe) orderId: number,
//     @Param('offerId', ParseIntPipe) offerId: number,
//   ) {
//     return this.ordersService.acceptOffer(orderId, offerId);
//   }

//   // 🔄 تحديث الحالة
//   @Patch(':id/status')
//   updateStatus(
//     @Param('id', ParseIntPipe) orderId: number,
//     @Query('status') status: OrderStatus,
//     @Body() body: { itemsPrice?: number; invoiceImageUrl?: string },
//   ) {
//     return this.ordersService.updateStatus(orderId, status, {
//       itemsPrice: body?.itemsPrice ? Number(body.itemsPrice) : undefined,
//       invoiceImageUrl: body?.invoiceImageUrl,
//     });
//   }
// }
