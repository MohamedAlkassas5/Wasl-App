import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, In, Repository } from 'typeorm';
import {
  WalletTopUpRequest,
  TopUpStatus,
} from './entities/wallet-topup-request.entity';
import {
  WalletTransaction,
  WalletTxType,
} from './entities/wallet-transaction.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { User } from '../users/entities/user.entity';
import { SettingsService, SettingKey } from '../settings/settings.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateTopUpRequestDto, AdminCreditDto } from './dto/topup.dto';

/**
 * The ledger reference that makes one top-up creditable exactly once.
 *
 * `wallet_transactions.reference` is UNIQUE in the database, so this is not a
 * convention the service is trusted to honour — it is the database refusing a
 * second credit for the same request. Same mechanism as
 * `order-<id>-commission` on settlement.
 */
export const topUpReference = (requestId: number) => `topup-${requestId}`;

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    @InjectRepository(WalletTopUpRequest)
    private readonly topUpRepo: Repository<WalletTopUpRequest>,
    @InjectRepository(WalletTransaction)
    private readonly txRepo: Repository<WalletTransaction>,
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepo: Repository<DeliveryPartner>,
    private readonly settings: SettingsService,
    private readonly notifications: NotificationsService,
  ) {}

  /** The platform's payment handles shown to the driver before they pay. */
  getPaymentAccounts() {
    return {
      vodafoneCash: this.settings.getString(SettingKey.PAY_VODAFONE_NUMBER, ''),
      instapay: this.settings.getString(SettingKey.PAY_INSTAPAY_HANDLE, ''),
      instructions: this.settings.getString(SettingKey.PAY_INSTRUCTIONS, ''),
      minAmount: this.settings.getNumber(SettingKey.TOPUP_MIN_AMOUNT, 10),
      maxAmount: this.settings.getNumber(SettingKey.TOPUP_MAX_AMOUNT, 5000),
    };
  }

  /**
   * The one authoritative wallet balance.
   *
   * `delivery_partners.balance` is the single figure every credit and debit
   * writes through {@link creditWithin}, and this is the only place the driver
   * app is meant to read it from. `balanceAfter` on the newest ledger row is
   * returned beside it so a divergence between the two is visible rather than
   * silent — they are written in the same transaction and must agree.
   */
  async getWalletSummary(driverId: number) {
    const driver = await this.deliveryRepo.findOne({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('حساب الكابتن غير موجود');

    const [latest] = await this.txRepo.find({
      where: { driverId },
      order: { id: 'DESC' },
      take: 1,
    });

    const pending = await this.topUpRepo.find({
      where: { driverId, status: TopUpStatus.PENDING },
    });

    return {
      success: true,
      balance: Number(driver.balance ?? 0),
      // What the ledger says the balance became on its last entry. Null before
      // a driver's first transaction, which is not a disagreement.
      ledgerBalance: latest ? Number(latest.balanceAfter) : null,
      pendingTopUpCount: pending.length,
      pendingTopUpAmount:
        Math.round(
          pending.reduce((sum, r) => sum + Number(r.amount), 0) * 100,
        ) / 100,
      minWalletToGoOnline: this.settings.getNumber(
        SettingKey.MIN_WALLET_TO_GO_ONLINE,
        5,
      ),
    };
  }

  /**
   * Driver files a top-up request after paying — starts as PENDING.
   *
   * 💰 This method deliberately moves no money. The driver has paid a Vodafone
   * Cash / InstaPay account off-platform and nobody has looked at the proof
   * yet; crediting here would let anyone with the app mint balance. The only
   * path from a request to a balance is {@link approveRequest}.
   */
  async createTopUpRequest(driverId: number, dto: CreateTopUpRequestDto) {
    const driver = await this.deliveryRepo.findOne({
      where: { userId: driverId },
    });
    if (!driver) throw new NotFoundException('حساب الكابتن غير موجود');

    // 🔐 The amount is decided here, not by the client. Flutter's own check is
    // a courtesy to the driver; this is the one that counts.
    const amount = this.validateAmount(dto.amount);

    // Without the transfer screenshot there is nothing for an admin to verify,
    // and a request they cannot verify is one they will either reject or —
    // worse — approve on trust.
    if (!dto.proofImageUrl) {
      throw new BadRequestException('يجب إرفاق صورة إيصال التحويل');
    }

    const request = this.topUpRepo.create({
      driverId,
      amount,
      method: dto.method,
      senderReference: dto.senderReference,
      proofImageUrl: dto.proofImageUrl,
      status: TopUpStatus.PENDING,
    });
    const saved = await this.topUpRepo.save(request);
    return {
      success: true,
      message:
        'تم إرسال طلب الشحن للمراجعة. سيتم إضافة المبلغ إلى محفظتك بعد تأكيد التحويل.',
      request: saved,
    };
  }

  /**
   * A top-up amount the server is willing to stand behind.
   *
   * Rounds to piastres rather than trusting an arbitrary float, and holds the
   * request between the admin-configured floor and ceiling.
   */
  private validateAmount(raw: number): number {
    const amount = Math.round(Number(raw) * 100) / 100;
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('مبلغ الشحن غير صالح');
    }

    const min = this.settings.getNumber(SettingKey.TOPUP_MIN_AMOUNT, 10);
    const max = this.settings.getNumber(SettingKey.TOPUP_MAX_AMOUNT, 5000);
    if (amount < min) {
      throw new BadRequestException(`أقل مبلغ للشحن هو ${min} ج.م`);
    }
    if (amount > max) {
      throw new BadRequestException(`أقصى مبلغ للشحن هو ${max} ج.م`);
    }
    return amount;
  }

  getMyRequests(driverId: number) {
    return this.topUpRepo.find({
      where: { driverId },
      order: { createdAt: 'DESC' },
    });
  }

  // ---- Admin operations ----

  /**
   * The review queue, with the driver's name and phone attached.
   *
   * The admin is matching a screenshot against a person, and a bare
   * `driver_id` makes that guesswork.
   */
  async getRequests(status?: TopUpStatus) {
    const requests = await this.topUpRepo.find({
      where: status ? { status } : {},
      order: { createdAt: 'DESC' },
    });
    if (requests.length === 0) return [];

    const users = await this.deliveryRepo.manager.find(User, {
      where: { id: In([...new Set(requests.map((r) => r.driverId))]) },
    });
    const byId = new Map(users.map((u) => [u.id, u]));

    return requests.map((request) => ({
      ...request,
      driverName: byId.get(request.driverId)?.name ?? null,
      driverPhone: byId.get(request.driverId)?.phone ?? null,
    }));
  }

  /**
   * Verify a payment and credit the driver's wallet.
   *
   * 💰 The one place a top-up becomes money. Three things guard it, in order:
   *
   *  1. the request row is locked `FOR UPDATE` before it is read, so a second
   *     approval blocks until the first has committed and then reads the
   *     status the first one wrote;
   *  2. the status change is a **conditional** UPDATE on `status = pending`,
   *     so it patches nothing if the row moved under us;
   *  3. the credit carries `topup-<id>` as its ledger reference, which is
   *     UNIQUE in the database — if both of the above were somehow defeated,
   *     the second insert still collides and its whole transaction, balance
   *     update included, rolls back.
   *
   * Credit and status live in the same transaction: a failed credit cannot
   * leave the request APPROVED, and an APPROVED request cannot exist without
   * its ledger entry.
   *
   * A repeat of an approval that already landed is answered with the same
   * result rather than an error — the admin may simply have lost the first
   * response — but it credits nothing the second time.
   */
  async approveRequest(id: number, adminId: number, note?: string) {
    const outcome = await this.topUpRepo.manager.transaction(
      async (manager) => {
        const request = await manager.findOne(WalletTopUpRequest, {
          where: { id },
          lock: { mode: 'pessimistic_write' },
        });
        if (!request) throw new NotFoundException('طلب الشحن غير موجود');

        if (request.status === TopUpStatus.APPROVED) {
          const driver = await manager.findOne(DeliveryPartner, {
            where: { userId: request.driverId },
          });
          return {
            request,
            repeated: true,
            newBalance: driver ? Number(driver.balance) : null,
          };
        }
        if (request.status !== TopUpStatus.PENDING) {
          throw new BadRequestException('تمت مراجعة هذا الطلب مسبقاً');
        }

        const amount = Number(request.amount);
        const newBalance = await PaymentsService.creditWithin(manager, {
          driverId: request.driverId,
          amount,
          type: WalletTxType.TOPUP,
          note: `شحن محفظة معتمد (طلب #${request.id})`,
          reference: topUpReference(request.id),
        });

        const reviewedAt = new Date();
        const patched = await manager.update(
          WalletTopUpRequest,
          { id: request.id, status: TopUpStatus.PENDING },
          {
            status: TopUpStatus.APPROVED,
            reviewedByAdminId: adminId,
            reviewedAt,
            adminNote: note,
          },
        );
        if (patched.affected !== 1) {
          // Someone reviewed it between the lock and here. Cannot happen with
          // the lock held; if it ever does, the credit must not stand.
          throw new BadRequestException('تمت مراجعة هذا الطلب مسبقاً');
        }

        return {
          request: {
            ...request,
            status: TopUpStatus.APPROVED,
            reviewedByAdminId: adminId,
            reviewedAt,
            adminNote: note,
          },
          repeated: false,
          newBalance,
        };
      },
    );

    // Outside the transaction: a push that fails must not un-credit a wallet.
    if (!outcome.repeated) {
      await this.notifyDriver(
        outcome.request.driverId,
        '💰 تم قبول طلب شحن المحفظة',
        `تم قبول طلب شحن المحفظة وإضافة ${Number(outcome.request.amount).toFixed(0)} جنيه. رصيدك الحالي: ${Number(outcome.newBalance ?? 0).toFixed(2)} ج.م.`,
      );
    }

    return {
      success: true,
      repeated: outcome.repeated,
      newBalance: outcome.newBalance,
      request: outcome.request,
    };
  }

  /**
   * Reject a top-up. Moves no money and writes no ledger row — the wallet is
   * not touched at all, which is the whole point of the state.
   */
  async rejectRequest(id: number, adminId: number, note?: string) {
    const outcome = await this.topUpRepo.manager.transaction(
      async (manager) => {
        const request = await manager.findOne(WalletTopUpRequest, {
          where: { id },
          lock: { mode: 'pessimistic_write' },
        });
        if (!request) throw new NotFoundException('طلب الشحن غير موجود');

        if (request.status === TopUpStatus.REJECTED) {
          return { request, repeated: true };
        }
        if (request.status !== TopUpStatus.PENDING) {
          throw new BadRequestException('تمت مراجعة هذا الطلب مسبقاً');
        }

        const reviewedAt = new Date();
        const patched = await manager.update(
          WalletTopUpRequest,
          { id: request.id, status: TopUpStatus.PENDING },
          {
            status: TopUpStatus.REJECTED,
            reviewedByAdminId: adminId,
            reviewedAt,
            adminNote: note,
          },
        );
        if (patched.affected !== 1) {
          throw new BadRequestException('تمت مراجعة هذا الطلب مسبقاً');
        }

        return {
          request: {
            ...request,
            status: TopUpStatus.REJECTED,
            reviewedByAdminId: adminId,
            reviewedAt,
            adminNote: note,
          },
          repeated: false,
        };
      },
    );

    if (!outcome.repeated) {
      const reason = note?.trim();
      await this.notifyDriver(
        outcome.request.driverId,
        '⚠️ تم رفض طلب شحن المحفظة',
        reason
          ? `تم رفض طلب شحن المحفظة. السبب: ${reason}`
          : 'تم رفض طلب شحن المحفظة. راجع بيانات التحويل وحاول مرة أخرى.',
      );
    }

    return {
      success: true,
      repeated: outcome.repeated,
      request: outcome.request,
    };
  }

  /**
   * Tell the driver what an admin decided, through the one notification
   * service everything else already uses.
   *
   * Never throws: the money has already moved and the decision is recorded.
   */
  private async notifyDriver(driverId: number, title: string, message: string) {
    try {
      await this.notifications.notify(driverId, title, message);
    } catch (error) {
      this.logger.error(
        'Top-up decision notification failed',
        error instanceof Error ? error.message : String(error),
      );
    }
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
   * second, independent transaction that could commit on its own. Top-up
   * approval leans on the same property for the opposite direction: the credit
   * and the APPROVED status stand or fall together.
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
