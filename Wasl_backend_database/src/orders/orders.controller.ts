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

import { OrdersService } from './orders.service';
import { UploadService } from '../storage/upload.service';
import { OrderStatus } from './entities/order.entity';
import { plainToInstance } from 'class-transformer';

import { CreateOrderDto, OrderItemDto } from './dto/create-order.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser, assertSelfOrAdmin } from '../auth/current-user';
import { imageUploadPolicy } from '../common/upload-policy';
import { UserRole } from '../users/entities/user.entity';

// 🔐 Every order/wallet/offer/notification route requires a valid JWT, AND the
// caller's own id (from the token) is what identifies them — ids in the URL or
// body are authorization-checked against it, never trusted on their own. This
// closes the broken-access-control hole where any logged-in client could act as
// any other user by passing their id.
@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(
    private readonly ordersService: OrdersService,
    private readonly uploadService: UploadService,
  ) {}

  @Post('create')
  @UseInterceptors(FileInterceptor('itemsImage', imageUploadPolicy))
  async create(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File,
    @Body() createOrderDto: CreateOrderDto,
  ) {
    if (!createOrderDto) {
      throw new BadRequestException('بيانات الطلب غير مكتملة');
    }

    // 🔐 The order is always created for the authenticated caller. A client-sent
    // customerId is ignored so nobody can place orders in someone else's name.
    createOrderDto.customerId = user.sub;

    // 2. Cart lines arrive as a JSON string on the multipart path (a form field
    //    cannot carry an array). A malformed value is rejected rather than
    //    coerced into a one-element array of garbage, which is what used to
    //    happen — the resulting "item" then failed validation much later with
    //    an error that pointed nowhere near the real problem.
    if (typeof createOrderDto.items === 'string') {
      try {
        const parsed: unknown = JSON.parse(createOrderDto.items);
        if (!Array.isArray(parsed)) throw new Error('not an array');
        createOrderDto.items = plainToInstance(OrderItemDto, parsed);
      } catch {
        throw new BadRequestException('تعذّر قراءة أصناف الطلب');
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

    // Bytes go to the configured storage backend (local disk in dev, R2 in
    // production) and we persist the key it hands back.
    const itemsImageUrl = await this.uploadService.persistImage(
      file,
      'orders',
      'order',
    );
    if (itemsImageUrl) {
      createOrderDto.itemsImageUrl = itemsImageUrl;
    }

    return this.ordersService.createOrder(user.sub, createOrderDto);
  }

  // 🎯 جلب الطلبات المتاحة حياً للسوق اللوجستي + طلبات الكابتن النشطة
  // 🔐 The marketplace is always scoped to the calling driver.
  @Get('available')
  getAvailable(@CurrentUser() user: AuthUser) {
    return this.ordersService.getAvailableOrders(user.sub, user);
  }

  @Post(':id/accept')
  acceptAvailableOrder(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) orderId: number,
  ) {
    if (user.role !== UserRole.DELIVERY) {
      throw new BadRequestException('هذا المسار مخصص للكباتن فقط');
    }
    return this.ordersService.acceptAvailableOrder(orderId, user.sub);
  }

  // 🎯 جلب طلبات عميل محدد فقط (بدون تسريب بيانات العملاء الآخرين)
  @Get('customer/:customerId')
  getCustomerOrders(
    @CurrentUser() user: AuthUser,
    @Param('customerId', ParseIntPipe) customerId: number,
  ) {
    assertSelfOrAdmin(user, customerId);
    return this.ordersService.getCustomerOrders(customerId);
  }

  @Get('driver/:driverId/online-status')
  getDriverOnlineStatus(
    @CurrentUser() user: AuthUser,
    @Param('driverId', ParseIntPipe) driverId: number,
  ) {
    assertSelfOrAdmin(user, driverId);
    return this.ordersService.getDriverOnlineStatus(driverId);
  }

  @Patch('driver/:driverId/online-status')
  setDriverOnlineStatus(
    @CurrentUser() user: AuthUser,
    @Param('driverId', ParseIntPipe) driverId: number,
    @Body('isOnline') isOnline: boolean,
  ) {
    assertSelfOrAdmin(user, driverId);
    return this.ordersService.setDriverOnlineStatus(
      driverId,
      Boolean(isOnline),
    );
  }

  // 🚀 مسار إحصائيات لوحة التحكم الشامل والمزامنة الآنية
  @Get('driver/:driverId/dashboard-stats')
  async getDriverDashboardStats(
    @CurrentUser() user: AuthUser,
    @Param('driverId', ParseIntPipe) driverId: number,
  ) {
    assertSelfOrAdmin(user, driverId);
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
  // 🔐 Only a customer who actually had a completed order with this driver may
  // rate them — otherwise ratings could be brigaded by anyone with an account.
  @Post('driver/:driverId/rate')
  async rateDriver(
    @CurrentUser() user: AuthUser,
    @Param('driverId', ParseIntPipe) driverId: number,
    @Body('rating') rating: number,
  ) {
    const validatedRating = Math.max(1, Math.min(5, Number(rating || 5)));
    return this.ordersService.updateDriverRating(
      driverId,
      validatedRating,
      user.sub,
    );
  }

  // 🎯 مسار جلب الإشعارات الحية وغير المقروءة للعميل والمندوب فوراً
  @Get('user/:userId/notifications')
  getNotifications(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseIntPipe) userId: number,
  ) {
    assertSelfOrAdmin(user, userId);
    return this.ordersService.getUnreadNotifications(userId);
  }

  // 🎯 مسار حذف إشعار فردي محدد (لصاحب الإشعار فقط)
  @Delete('notifications/:id')
  async deleteNotification(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) id: number,
  ) {
    await this.ordersService.deleteNotification(id, user);
    return { success: true, message: 'تم مسح الإشعار بنجاح' };
  }

  // 🎯 مسار مسح وتصفية كل إشعارات العميل أو الكابتن دفعة واحدة
  @Delete('user/:userId/notifications/clear-all')
  async clearAllNotifications(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseIntPipe) userId: number,
  ) {
    assertSelfOrAdmin(user, userId);
    await this.ordersService.clearAllUserNotifications(userId);
    return { success: true, message: 'تم مسح مركز الإشعارات بالكامل' };
  }

  // 🎯 مسار تتبع العميل لقراءة التفاصيل الحية
  // 🔐 Restricted to the order's own customer, its assigned driver, or an admin.
  @Get(':id/customer-details')
  async getCustomerOrderDetails(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.ordersService.getOrderDetailsForCustomer(id, user);
  }

  // 🎯 مسار أمني حاسم لحذف حساب الكابتن نهائياً من قاعدة البيانات (PostgreSQL)
  // 🔐 A driver may delete only their own account; admins may delete any.
  @Delete('driver/:driverId')
  async deleteDriverAccount(
    @CurrentUser() user: AuthUser,
    @Param('driverId', ParseIntPipe) driverId: number,
  ) {
    assertSelfOrAdmin(user, driverId);
    await this.ordersService.deleteDriverProfile(driverId);
    return {
      success: true,
      message: 'تم حذف الحساب والبيانات بنجاح من النظام',
    };
  }

  // 🗑️ `POST :id/submit-offer`, `GET :id/offers` and
  // `POST :id/offers/:offerId/accept` are gone with driver bidding. The
  // delivery fee is the server's to decide, from the central zone rate table;
  // a driver takes an order through `POST :id/accept` or does not take it.

  // 🧾 Driver uploads the purchase receipt/invoice image at pickup. Sets the
  // items price + receipt image and advances the order to "items_bought" so the
  // customer can review the real total before delivery.
  @Post(':id/invoice')
  @UseInterceptors(FileInterceptor('invoiceImage', imageUploadPolicy))
  async uploadInvoice(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) orderId: number,
    @UploadedFile() file: Express.Multer.File,
    @Body() body: { itemsPrice?: number },
  ) {
    const invoiceImageUrl = await this.uploadService.persistImage(
      file,
      'invoices',
      'invoice',
    );
    return this.ordersService.updateStatus(
      orderId,
      OrderStatus.ITEMS_BOUGHT,
      {
        itemsPrice: body?.itemsPrice ? Number(body.itemsPrice) : undefined,
        invoiceImageUrl,
      },
      user,
    );
  }

  /**
   * Customer cancels their own order while it is still waiting for offers.
   * Ownership comes from the token; the service refuses once a driver has
   * accepted.
   */
  @Patch(':id/cancel')
  cancelOrder(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) orderId: number,
  ) {
    return this.ordersService.cancelOrderByCustomer(orderId, user);
  }

  /**
   * Confirms delivery and settles the order.
   *
   * Separate from the generic status route because it is the only action that
   * moves money. The server checks the order is actually out for delivery, that
   * the caller is its assigned driver, and that it has not already been
   * settled; the customer is not asked to confirm anything.
   *
   * Safe to repeat: a second call returns the same result instead of charging
   * commission twice.
   */
  @Post(':id/complete')
  completeOrder(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) orderId: number,
  ) {
    return this.ordersService.completeOrder(orderId, user);
  }

  /**
   * Moves an order one step along the lifecycle.
   *
   * 🔐 Only the assigned driver (or an admin) may advance it, and only along an
   * edge the state machine allows — an arbitrary enum value from the query
   * string can no longer force a state. Completion is deliberately not
   * reachable here; use `POST :id/complete`.
   */
  @Patch(':id/status')
  updateStatus(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseIntPipe) orderId: number,
    @Query('status') status: OrderStatus,
    @Body() body: { itemsPrice?: number; invoiceImageUrl?: string },
  ) {
    const parsedBody = {
      itemsPrice: body?.itemsPrice ? Number(body.itemsPrice) : undefined,
      invoiceImageUrl: body?.invoiceImageUrl || undefined,
    };
    return this.ordersService.updateStatus(orderId, status, parsedBody, user);
  }
}
