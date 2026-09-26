import {
  Controller,
  Post,
  Get,
  Body,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';
import { PaymentsService } from './payments.service';
import { CreateTopUpRequestDto } from './dto/topup.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { imageUploadPolicy } from '../common/upload-policy';
import { UploadService } from '../storage/upload.service';

interface JwtReq extends Request {
  user?: { sub: number; role: string };
}

/**
 * Driver-facing wallet endpoints. The driver id always comes from the JWT
 * (`sub`), never from the request body, so a driver can only act on their own
 * wallet.
 */
@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
  constructor(
    private readonly paymentsService: PaymentsService,
    private readonly uploadService: UploadService,
  ) {}

  @Get('payment-accounts')
  getAccounts() {
    return this.paymentsService.getPaymentAccounts();
  }

  /**
   * The single balance the driver app reads.
   *
   * Deliberately takes no driver id: the wallet is whoever the token says it
   * is. The app previously read its balance from
   * `/orders/driver/:id/dashboard-stats`, which needs an id the app keeps in
   * `SharedPreferences` — when that id was stale or absent the screen fell
   * back to a made-up number instead of failing. Both routes read the same
   * `delivery_partners.balance` column; this one cannot be pointed at the
   * wrong row.
   */
  @Get('summary')
  summary(@Req() req: JwtReq) {
    return this.paymentsService.getWalletSummary(req.user!.sub);
  }

  @Post('topup-requests')
  @UseInterceptors(FileInterceptor('proofImage', imageUploadPolicy))
  async createTopUp(
    @Req() req: JwtReq,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: CreateTopUpRequestDto,
  ) {
    // The stored key is produced here from the verified bytes. Anything the
    // client put in `proofImageUrl` is discarded — otherwise a driver could
    // name someone else's file, or a path that is not a file at all.
    dto.proofImageUrl = await this.uploadService.persistImage(
      file,
      'payments',
      'proof',
    );
    return this.paymentsService.createTopUpRequest(req.user!.sub, dto);
  }

  @Get('topup-requests/mine')
  myRequests(@Req() req: JwtReq) {
    return this.paymentsService.getMyRequests(req.user!.sub);
  }

  @Get('transactions/mine')
  myTransactions(@Req() req: JwtReq) {
    return this.paymentsService.getDriverTransactions(req.user!.sub);
  }
}
