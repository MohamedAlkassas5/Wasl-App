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
  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('topup-requests')
  list(@Query('status') status?: TopUpStatus) {
    return this.paymentsService.getRequests(status);
  }

  @Patch('topup-requests/:id/approve')
  approve(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: JwtReq,
    @Body() dto: ReviewTopUpDto,
  ) {
    return this.paymentsService.approveRequest(
      id,
      req.user!.sub,
      dto.adminNote,
    );
  }

  @Patch('topup-requests/:id/reject')
  reject(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: JwtReq,
    @Body() dto: ReviewTopUpDto,
  ) {
    return this.paymentsService.rejectRequest(id, req.user!.sub, dto.adminNote);
  }

  @Patch('drivers/:driverId/credit')
  credit(
    @Param('driverId', ParseIntPipe) driverId: number,
    @Req() req: JwtReq,
    @Body() dto: AdminCreditDto,
  ) {
    return this.paymentsService.adminCredit(driverId, req.user!.sub, dto);
  }

  @Get('drivers/:driverId/transactions')
  transactions(@Param('driverId', ParseIntPipe) driverId: number) {
    return this.paymentsService.getDriverTransactions(driverId);
  }
}
