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

  @Post('topup-requests')
  @UseInterceptors(FileInterceptor('proofImage', imageUploadPolicy))
  async createTopUp(
    @Req() req: JwtReq,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: CreateTopUpRequestDto,
  ) {
    const proofImageUrl = await this.uploadService.persistImage(
      file,
      'payments',
      'proof',
    );
    if (proofImageUrl) {
      dto.proofImageUrl = proofImageUrl;
    }
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
