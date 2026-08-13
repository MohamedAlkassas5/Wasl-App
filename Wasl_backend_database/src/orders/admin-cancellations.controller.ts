import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { OrderCancellationService } from './order-cancellation.service';
import { CancellationAppealStatus } from './entities/order-cancellation-request.entity';
import { ReviewCancellationDto } from './dto/cancellation.dto';

/**
 * Admin review of cancellations and the penalties they charged.
 *
 * This is backend support for a review interface, not an interface: it exposes
 * the reason, who started it, who decided it, the timestamps, the money that
 * moved and where the evidence lives. Building the dashboard itself is out of
 * scope.
 */
@Controller('admin/cancellations')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminCancellationsController {
  constructor(private readonly cancellationService: OrderCancellationService) {}

  /** The queue. `?appealStatus=pending` is the one an admin actually works. */
  @Get()
  list(@Query('appealStatus') appealStatus?: CancellationAppealStatus) {
    return this.cancellationService.listForReview(appealStatus);
  }

  /** One cancellation in full: record, order, ledger entries, evidence links. */
  @Get(':id')
  detail(@Param('id', ParseIntPipe) id: number) {
    return this.cancellationService.getReviewDetail(id);
  }

  /** Customer was at fault — give the driver their penalty back. */
  @Post(':id/refund')
  refund(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ReviewCancellationDto,
  ) {
    return this.cancellationService.refundPenalty(id, admin, dto ?? {});
  }

  /** Driver was at fault — the charge stands. */
  @Post(':id/uphold')
  uphold(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ReviewCancellationDto,
  ) {
    return this.cancellationService.upholdPenalty(id, admin, dto ?? {});
  }
}
