import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  Query,
  Req,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { PaymentsService } from './payments.service';
import { AdminAuditLogService } from '../admin/admin-audit-log.service';
import { ReviewTopUpDto, AdminCreditDto } from './dto/topup.dto';
import { TopUpStatus } from './entities/wallet-topup-request.entity';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

interface JwtReq extends Request {
  user?: { sub: number; role: string };
}

/**
 * Admin wallet management: verify driver top-up payments and adjust balances.
 * Guarded by JWT + ADMIN role.
 */
@Controller('admin/payments')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminPaymentsController {
  constructor(
    private readonly paymentsService: PaymentsService,
    private readonly auditLog: AdminAuditLogService,
  ) {}

  @Get('topup-requests')
  list(@Query('status') status?: TopUpStatus) {
    return this.paymentsService.getRequests(status);
  }

  @Patch('topup-requests/:id/approve')
  async approve(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: JwtReq,
    @Body() dto: ReviewTopUpDto,
  ) {
    const result = await this.paymentsService.approveRequest(
      id,
      req.user!.sub,
      dto.adminNote,
    );
    // Money moved. This is the entry someone will come looking for.
    await this.auditLog.record({
      adminId: req.user!.sub,
      action: 'wallet.topup.approve',
      targetType: 'topup_request',
      targetId: id,
      payload: dto,
    });
    return result;
  }

  @Patch('topup-requests/:id/reject')
  async reject(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: JwtReq,
    @Body() dto: ReviewTopUpDto,
  ) {
    const result = await this.paymentsService.rejectRequest(
      id,
      req.user!.sub,
      dto.adminNote,
    );
    await this.auditLog.record({
      adminId: req.user!.sub,
      action: 'wallet.topup.reject',
      targetType: 'topup_request',
      targetId: id,
      payload: dto,
    });
    return result;
  }

  @Patch('drivers/:driverId/credit')
  async credit(
    @Param('driverId', ParseIntPipe) driverId: number,
    @Req() req: JwtReq,
    @Body() dto: AdminCreditDto,
  ) {
    const result = await this.paymentsService.adminCredit(
      driverId,
      req.user!.sub,
      dto,
    );
    // A manual balance adjustment with no request behind it — the single most
    // important admin action to be able to attribute afterwards.
    await this.auditLog.record({
      adminId: req.user!.sub,
      action: 'wallet.credit',
      targetType: 'driver',
      targetId: driverId,
      payload: dto,
    });
    return result;
  }

  @Get('drivers/:driverId/transactions')
  transactions(@Param('driverId', ParseIntPipe) driverId: number) {
    return this.paymentsService.getDriverTransactions(driverId);
  }
}
