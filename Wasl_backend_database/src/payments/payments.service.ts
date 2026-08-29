import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, Repository } from 'typeorm';
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
    return this.deliveryRepo.manager.transaction((manager) =>
      PaymentsService.creditWithin(manager, { driverId, amount, type, note }),
    );
  }

  /**
   * The same movement, inside a caller-supplied transaction.
   *
   * Order settlement needs the commission debit and the order's own state
   * change to be one atomic act — either the driver is charged and the order
   * is marked settled, or neither happened. Passing the manager in is what
   * allows that; calling {@link credit} from inside settlement would open a
   * second, independent transaction that could commit on its own.
   *
   * The row is locked before it is read. The previous implementation read the
   * balance, added to it in JavaScript and wrote it back with no lock at all,
   * so two concurrent debits both starting from 100 would each write their own
   * result and one would simply vanish.
   *
   * `reference` is the idempotency key. It is UNIQUE in the database, so a
   * repeated settlement raises a conflict here rather than quietly charging
   * twice — see the note on `WalletTransaction.reference`.
   */
  static async creditWithin(
    manager: EntityManager,
    entry: {
      driverId: number;
      amount: number;
      type: WalletTxType;
      note: string;
      reference?: string;
      orderId?: number;
    },
  ): Promise<number> {
    const driver = await manager.findOne(DeliveryPartner, {
      where: { userId: entry.driverId },
      lock: { mode: 'pessimistic_write' },
    });
    if (!driver) throw new NotFoundException('حساب الكابتن غير موجود');

    // 💰 CP-E / S5 — a balance is allowed to go negative, by decision (Q-B2,
    // option A). There is no floor here and that is deliberate, not an
    // oversight.
    //
    // The debits that can cross zero are the completion commission and the
    // cancellation penalty, and both are charged for work that already
    // happened. Refusing the debit because the wallet is short would hand the
    // driver a free delivery and leave the platform with no way to collect;
    // clamping at zero would silently forgive the difference, which is the
    // same thing with worse bookkeeping. Letting the balance go negative keeps
    // the ledger honest about what is owed.
    //
    // What stops it becoming free work is the *other* half of the policy: a
    // driver below `min_wallet_to_go_online` cannot go online or accept, which
    // a negative balance always is. So the debt is carried until they top up,
    // and is settled by that top-up rather than written off. Enforcement lives
    // in `OrdersService.setDriverOnlineStatus`, pinned by
    // `negative-balance.spec.ts`.
    const newBalance =
      Math.round((Number(driver.balance) + entry.amount) * 100) / 100;

    await manager.update(
      DeliveryPartner,
      { userId: entry.driverId },
      { balance: newBalance },
    );

    await manager.insert(WalletTransaction, {
      driverId: entry.driverId,
      amount: entry.amount,
      type: entry.type,
      balanceAfter: newBalance,
      note: entry.note,
      reference: entry.reference ?? null,
      orderId: entry.orderId ?? null,
    });

    return newBalance;
  }
}
