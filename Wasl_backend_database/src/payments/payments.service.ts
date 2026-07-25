import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  WalletTopUpRequest,
  TopUpStatus,
} from './entities/wallet-topup-request.entity';
import {
  WalletTransaction,
  WalletTxType,
} from './entities/wallet-transaction.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { CreateTopUpRequestDto, AdminCreditDto } from './dto/topup.dto';

@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(WalletTopUpRequest)
    private readonly topUpRepo: Repository<WalletTopUpRequest>,
    @InjectRepository(WalletTransaction)
    private readonly txRepo: Repository<WalletTransaction>,
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepo: Repository<DeliveryPartner>,
    private readonly settings: SettingsService,
  ) {}

  /** The platform's payment handles shown to the driver before they pay. */
  getPaymentAccounts() {
    return {
      vodafoneCash: this.settings.getString(SettingKey.PAY_VODAFONE_NUMBER, ''),
      instapay: this.settings.getString(SettingKey.PAY_INSTAPAY_HANDLE, ''),
      instructions: this.settings.getString(SettingKey.PAY_INSTRUCTIONS, ''),
    };
  }

  /** Driver files a top-up request after paying — starts as PENDING. */
  async createTopUpRequest(driverId: number, dto: CreateTopUpRequestDto) {
    const driver = await this.deliveryRepo.findOne({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('حساب الكابتن غير موجود');

    const request = this.topUpRepo.create({
      driverId,
      amount: dto.amount,
      method: dto.method,
      senderReference: dto.senderReference,
      proofImageUrl: dto.proofImageUrl,
      status: TopUpStatus.PENDING,
    });
    const saved = await this.topUpRepo.save(request);
    return {
      success: true,
      message:
        'تم استلام طلب الشحن، وسيتم تفعيل الرصيد بعد مراجعة الإدارة للتحويل.',
      request: saved,
    };
  }

  getMyRequests(driverId: number) {
    return this.topUpRepo.find({
      where: { driverId },
      order: { createdAt: 'DESC' },
    });
  }

  // ---- Admin operations ----

  getRequests(status?: TopUpStatus) {
    return this.topUpRepo.find({
      where: status ? { status } : {},
      order: { createdAt: 'DESC' },
    });
  }

  /** Verify a payment and credit the driver's wallet (idempotent per request). */
  async approveRequest(id: number, adminId: number, note?: string) {
    const request = await this.topUpRepo.findOne({ where: { id } });
    if (!request) throw new NotFoundException('طلب الشحن غير موجود');
    if (request.status !== TopUpStatus.PENDING) {
      throw new BadRequestException('تمت مراجعة هذا الطلب مسبقاً');
    }

    const newBalance = await this.credit(
      request.driverId,
      Number(request.amount),
      WalletTxType.TOPUP,
      `شحن محفظة معتمد (طلب #${request.id})`,
    );

    request.status = TopUpStatus.APPROVED;
    request.reviewedByAdminId = adminId;
    request.reviewedAt = new Date();
    request.adminNote = note;
    await this.topUpRepo.save(request);

    return { success: true, newBalance, request };
  }

  async rejectRequest(id: number, adminId: number, note?: string) {
    const request = await this.topUpRepo.findOne({ where: { id } });
    if (!request) throw new NotFoundException('طلب الشحن غير موجود');
    if (request.status !== TopUpStatus.PENDING) {
      throw new BadRequestException('تمت مراجعة هذا الطلب مسبقاً');
    }
    request.status = TopUpStatus.REJECTED;
    request.reviewedByAdminId = adminId;
    request.reviewedAt = new Date();
    request.adminNote = note;
    await this.topUpRepo.save(request);
    return { success: true, request };
  }

  /** Direct admin credit/debit (e.g. correction), no request needed. */
  async adminCredit(driverId: number, adminId: number, dto: AdminCreditDto) {
    const newBalance = await this.credit(
      driverId,
      Number(dto.amount),
      WalletTxType.ADJUSTMENT,
      dto.note || `تعديل يدوي من الإدارة (#${adminId})`,
    );
    return { success: true, newBalance };
  }

  getDriverTransactions(driverId: number) {
    return this.txRepo.find({
      where: { driverId },
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Central balance mutator: updates the driver balance and writes a ledger
   * row. Also used by the orders flow to record commission debits.
   */
  async credit(
    driverId: number,
    amount: number,
    type: WalletTxType,
    note: string,
  ): Promise<number> {
    const driver = await this.deliveryRepo.findOne({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('حساب الكابتن غير موجود');

    const newBalance = Number(driver.balance) + amount;
    driver.balance = newBalance;
    await this.deliveryRepo.save(driver);

    await this.txRepo.save(
      this.txRepo.create({
        driverId,
        amount,
        type,
        balanceAfter: newBalance,
        note,
      }),
    );
    return newBalance;
  }
}
