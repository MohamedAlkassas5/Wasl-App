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
import { diskStorage } from 'multer';
import { extname } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { Request } from 'express';
import { PaymentsService } from './payments.service';
import { CreateTopUpRequestDto } from './dto/topup.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { imageUploadPolicy } from '../common/upload-policy';

interface JwtReq extends Request {
  user?: { sub: number; role: string };
}

const proofUploadPath = './uploads/payments';

/**
 * Driver-facing wallet endpoints. The driver id always comes from the JWT
 * (`sub`), never from the request body, so a driver can only act on their own
 * wallet.
 */
@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('payment-accounts')
  getAccounts() {
    return this.paymentsService.getPaymentAccounts();
  }

  @Post('topup-requests')
  @UseInterceptors(
    FileInterceptor('proofImage', {
      ...imageUploadPolicy,
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          if (!existsSync(proofUploadPath)) {
            mkdirSync(proofUploadPath, { recursive: true });
          }
          cb(null, proofUploadPath);
        },
        filename: (_req, file, cb) => {
          const suffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
          cb(null, `proof-${suffix}${extname(file.originalname)}`);
        },
      }),
    }),
  )
  createTopUp(
    @Req() req: JwtReq,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: CreateTopUpRequestDto,
  ) {
    if (file?.filename) {
      dto.proofImageUrl = `uploads/payments/${file.filename}`;
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
