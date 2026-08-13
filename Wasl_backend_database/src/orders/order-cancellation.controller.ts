import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../auth/current-user';
import { OrderCancellationService } from './order-cancellation.service';
import {
  AppealCancellationDto,
  CreateCancellationRequestDto,
  DecideCancellationDto,
  DriverCancelOrderDto,
} from './dto/cancellation.dto';

/**
 * Cancelling an order that a driver has already accepted.
 *
 * 🔐 Every route is authenticated and re-derives the caller's relationship to
 * the order from the token. Cancellation lives here, on its own routes, rather
 * than behind the generic status endpoint — it moves money, and a state that
 * charges a wallet must not be reachable by putting a string in a query
 * parameter.
 *
 * Nothing in this controller accepts an amount. The penalty is computed
 * server-side from the fee frozen on the order.
 */
@Controller('orders/:orderId')
@UseGuards(JwtAuthGuard)
export class OrderCancellationController {
  constructor(private readonly cancellationService: OrderCancellationService) {}

  /** Customer asks; the driver still has to agree. */
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('cancellation-request')
  request(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: CreateCancellationRequestDto,
  ) {
    return this.cancellationService.requestCancellation(orderId, user, dto);
  }

  /** Assigned driver agrees: the order cancels and the penalty is charged. */
  @Post('cancellation-request/approve')
  approve(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: DecideCancellationDto,
  ) {
    return this.cancellationService.decideCancellation(
      orderId,
      user,
      true,
      dto ?? {},
    );
  }

  /** Assigned driver refuses: the order continues and no money moves. */
  @Post('cancellation-request/reject')
  reject(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: DecideCancellationDto,
  ) {
    return this.cancellationService.decideCancellation(
      orderId,
      user,
      false,
      dto ?? {},
    );
  }

  /** Assigned driver abandons the order. Reason required. */
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('driver-cancel')
  driverCancel(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: DriverCancelOrderDto,
  ) {
    return this.cancellationService.driverCancel(orderId, user, dto);
  }

  /**
   * Driver disputes the penalty. The evidence is the order chat — already
   * append-only and admin-readable — so nothing is uploaded here.
   */
  @Post('cancellation/appeal')
  appeal(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: AppealCancellationDto,
  ) {
    return this.cancellationService.appeal(orderId, user, dto);
  }

  /** The cancellation record, for either party or an admin. */
  @Get('cancellation')
  get(
    @CurrentUser() user: AuthUser,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.cancellationService.getForOrder(orderId, user);
  }
}
