import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThan, Repository } from 'typeorm';

import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { UploadService } from '../storage/upload.service';
import {
  Order,
  OrderStatus,
  PURCHASE_ORDER_TYPES,
} from './entities/order.entity';
import {
  OrderMessage,
  OrderMessageKind,
  OrderMessageSender,
} from './entities/order-message.entity';
import {
  OrderPriceProposal,
  PriceProposalStatus,
} from './entities/order-price-proposal.entity';
import { assertOrderParticipant } from './order-participation';
import { isFinalState } from './order-state-machine';
import { OrdersService } from './orders.service';
import {
  CreatePriceProposalDto,
  ListMessagesDto,
  SendMessageDto,
} from './dto/chat.dto';

/** Sub-folder under `uploads/` that chat attachments are written to. */
export const CHAT_UPLOAD_FOLDER = 'chat';

/** States in which the driver is still at (or heading to) the shop. */
const PRICE_CHANGE_STATES: readonly OrderStatus[] = [
  OrderStatus.ACCEPTED,
  OrderStatus.AT_STORE,
  OrderStatus.ITEMS_BOUGHT,
];

/**
 * The order conversation, shared by every order type.
 *
 * Two rules shape everything here:
 *
 *  1. **Only the two parties talk.** Participation is decided by
 *     `assertOrderParticipant` — the same check the order routes use — so a
 *     driver browsing the marketplace can neither read nor write. Admins may
 *     read (they arbitrate cancellations) but not post: a dispute record is
 *     worth less if a third voice can be added to it afterwards.
 *
 *  2. **History is immutable.** Nothing edits or deletes a message, and once
 *     the order reaches a final state the conversation is frozen. That is what
 *     lets a driver later hand an admin the chat as evidence that the customer
 *     caused a cancellation.
 */
@Injectable()
export class OrderChatService {
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,

    @InjectRepository(OrderMessage)
    private readonly messageRepository: Repository<OrderMessage>,

    @InjectRepository(OrderPriceProposal)
    private readonly proposalRepository: Repository<OrderPriceProposal>,

    private readonly uploadService: UploadService,
    private readonly ordersService: OrdersService,
  ) {}

  // ─── Reading ─────────────────────────────────────────────────────────────

  /**
   * The conversation, oldest first. `after` makes the client's poll loop cheap:
   * it asks only for what it has not already seen.
   */
  async listMessages(orderId: number, user: AuthUser, query: ListMessagesDto) {
    const order = await this.loadParticipatingOrder(orderId, user);

    const messages = await this.messageRepository.find({
      where: {
        orderId,
        ...(query.after ? { id: MoreThan(query.after) } : {}),
      },
      order: { id: 'ASC' },
      take: query.limit ?? 100,
    });

    return {
      success: true,
      orderId,
      // The app disables its composer on this, but the server enforces it too.
      closed: isFinalState(order.status),
      messages,
    };
  }

  /** Messages from the *other* party that this caller has not read yet. */
  async unreadCount(orderId: number, user: AuthUser) {
    await this.loadParticipatingOrder(orderId, user);

    const count = await this.messageRepository
      .createQueryBuilder('message')
      .where('message.order_id = :orderId', { orderId })
      .andWhere('message.sender_id != :userId', { userId: user.sub })
      .andWhere('message.read_at IS NULL')
      .getCount();

    return { success: true, orderId, unread: count };
  }

  /** Marks everything the other party sent as read. */
  async markRead(orderId: number, user: AuthUser) {
    await this.loadParticipatingOrder(orderId, user);

    await this.messageRepository
      .createQueryBuilder()
      .update(OrderMessage)
      .set({ readAt: new Date() })
      .where('order_id = :orderId', { orderId })
      .andWhere('sender_id != :userId', { userId: user.sub })
      .andWhere('read_at IS NULL')
      .execute();

    return { success: true };
  }

  // ─── Writing ─────────────────────────────────────────────────────────────

  async sendText(orderId: number, user: AuthUser, dto: SendMessageDto) {
    const order = await this.loadWritableOrder(orderId, user);
    const senderRole = this.senderRoleFor(order, user);

    const message = await this.append(order, {
      senderId: user.sub,
      senderRole,
      kind: OrderMessageKind.TEXT,
      body: dto.body.trim(),
    });

    await this.notifyCounterparty(order, senderRole, 'رسالة جديدة', dto.body);
    return { success: true, data: message };
  }

  async sendImage(
    orderId: number,
    user: AuthUser,
    file: Express.Multer.File | undefined,
    caption?: string,
  ) {
    const order = await this.loadWritableOrder(orderId, user);
    const senderRole = this.senderRoleFor(order, user);

    const attachmentUrl = await this.uploadService.persistImage(
      file,
      CHAT_UPLOAD_FOLDER,
      'chat',
    );
    if (!attachmentUrl) {
      throw new BadRequestException('لم يتم إرفاق صورة');
    }

    const message = await this.append(order, {
      senderId: user.sub,
      senderRole,
      kind: OrderMessageKind.IMAGE,
      body: caption?.trim() || null,
      attachmentUrl,
    });

    await this.notifyCounterparty(
      order,
      senderRole,
      'صورة جديدة',
      'تم إرسال صورة في محادثة الطلب',
    );
    return { success: true, data: message };
  }

  // ─── Price changes ───────────────────────────────────────────────────────

  /**
   * The driver asks to change the purchase price.
   *
   * They cannot simply write the new number: `OrdersService.updateStatus`
   * refuses a differing `itemsPrice` and points here. Only the customer's
   * approval below moves the figure on the order.
   */
  async createProposal(
    orderId: number,
    user: AuthUser,
    dto: CreatePriceProposalDto,
  ) {
    const order = await this.loadWritableOrder(orderId, user);

    if (!isOrderParticipantDriver(order, user)) {
      throw new ForbiddenException('طلب تعديل السعر مخصص للكابتن المسند له');
    }
    if (!PURCHASE_ORDER_TYPES.includes(order.orderType)) {
      throw new BadRequestException('هذا الطلب لا يتضمن شراء منتجات');
    }
    if (!PRICE_CHANGE_STATES.includes(order.status)) {
      throw new BadRequestException(
        'لا يمكن طلب تعديل السعر في هذه المرحلة من الطلب',
      );
    }

    const oldItemsPrice = Number(order.itemsPrice) || 0;
    if (Number(dto.newItemsPrice) === oldItemsPrice) {
      throw new BadRequestException('السعر الجديد مطابق للسعر الحالي');
    }

    // One open request at a time. The partial unique index backs this up in the
    // database, so two taps racing each other cannot both create one.
    const open = await this.proposalRepository.findOne({
      where: { orderId, status: PriceProposalStatus.PENDING },
    });
    if (open) {
      throw new ConflictException(
        'يوجد طلب تعديل سعر بانتظار رد العميل بالفعل',
      );
    }

    let proposal: OrderPriceProposal;
    try {
      proposal = await this.proposalRepository.save(
        this.proposalRepository.create({
          orderId,
          proposedBy: user.sub,
          oldItemsPrice,
          newItemsPrice: dto.newItemsPrice,
          reason: dto.reason?.trim() || null,
          status: PriceProposalStatus.PENDING,
        }),
      );
    } catch {
      // Lost the race on the unique index.
      throw new ConflictException(
        'يوجد طلب تعديل سعر بانتظار رد العميل بالفعل',
      );
    }

    const message = await this.append(order, {
      senderId: user.sub,
      senderRole: OrderMessageSender.DRIVER,
      kind: OrderMessageKind.PRICE_PROPOSAL,
      body:
        `طلب تعديل سعر المشتريات من ${oldItemsPrice} إلى ${dto.newItemsPrice} جنيه` +
        (dto.reason ? ` — ${dto.reason.trim()}` : ''),
      proposalId: proposal.id,
    });

    await this.ordersService.createNotification(
      order.customerId,
      '💰 طلب تعديل سعر',
      `الكابتن طلب تعديل سعر مشتريات الطلب FL-${orderId} إلى ${dto.newItemsPrice} جنيه. راجع الطلب ووافق أو ارفض.`,
    );

    return { success: true, data: { proposal, message } };
  }

  /**
   * The customer answers. This is the **only** path that changes
   * `orders.itemsPrice`, and it is an explicit action — never inferred from
   * something typed in the chat.
   *
   * Approving is idempotent: a repeated tap returns the same result rather
   * than writing the price twice. Rejecting deliberately leaves the order
   * exactly as it was — it does not cancel it and it moves no money. The driver
   * may then cancel and ask an admin to review this conversation.
   */
  async decideProposal(
    orderId: number,
    proposalId: number,
    user: AuthUser,
    approve: boolean,
  ) {
    const order = await this.loadWritableOrder(orderId, user);
    assertOrderParticipant(order, user, 'customer');

    const outcome = await this.proposalRepository.manager.transaction(
      async (manager) => {
        const proposal = await manager.findOne(OrderPriceProposal, {
          where: { id: proposalId },
          lock: { mode: 'pessimistic_write' },
        });
        if (!proposal || proposal.orderId !== orderId) {
          throw new NotFoundException('طلب تعديل السعر غير موجود');
        }

        const wanted = approve
          ? PriceProposalStatus.APPROVED
          : PriceProposalStatus.REJECTED;

        // Already answered: the same answer is a no-op success (the client may
        // simply have lost the first response); a different one is a conflict.
        if (proposal.status !== PriceProposalStatus.PENDING) {
          if (proposal.status === wanted) {
            return { proposal, repeated: true };
          }
          throw new ConflictException('تم الرد على طلب تعديل السعر بالفعل');
        }

        const now = new Date();
        await manager.update(
          OrderPriceProposal,
          { id: proposal.id, status: PriceProposalStatus.PENDING },
          { status: wanted, decidedBy: user.sub, decidedAt: now },
        );

        if (approve) {
          await manager.update(
            Order,
            { id: orderId },
            { itemsPrice: proposal.newItemsPrice },
          );
        }

        proposal.status = wanted;
        proposal.decidedBy = user.sub;
        proposal.decidedAt = now;
        return { proposal, repeated: false };
      },
    );

    if (outcome.repeated) {
      return { success: true, data: { proposal: outcome.proposal } };
    }

    const message = await this.append(order, {
      senderId: user.sub,
      senderRole: OrderMessageSender.CUSTOMER,
      kind: OrderMessageKind.PRICE_DECISION,
      body: approve
        ? `وافق العميل على تعديل السعر إلى ${Number(outcome.proposal.newItemsPrice)} جنيه`
        : 'رفض العميل تعديل السعر',
      proposalId: outcome.proposal.id,
    });

    if (order.acceptedDriverId) {
      await this.ordersService.createNotification(
        order.acceptedDriverId,
        approve ? '✅ تمت الموافقة على السعر' : '❌ تم رفض تعديل السعر',
        approve
          ? `وافق العميل على السعر الجديد للطلب FL-${orderId}.`
          : `رفض العميل تعديل سعر الطلب FL-${orderId}.`,
      );
    }

    return { success: true, data: { proposal: outcome.proposal, message } };
  }

  /** Every proposal on an order, for the chat UI and for admin review. */
  async listProposals(orderId: number, user: AuthUser) {
    await this.loadParticipatingOrder(orderId, user);
    const proposals = await this.proposalRepository.find({
      where: { orderId },
      order: { id: 'ASC' },
    });
    return { success: true, orderId, proposals };
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  /** Loads an order the caller is a party to (read access). */
  private async loadParticipatingOrder(
    orderId: number,
    user: AuthUser,
  ): Promise<Order> {
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });
    if (!order) {
      throw new NotFoundException('الطلب غير موجود');
    }
    assertOrderParticipant(order, user, 'any');
    return order;
  }

  /**
   * Loads an order the caller may *write* to.
   *
   * On top of participation: the conversation needs a counterparty, and a
   * closed order is a historical record.
   */
  private async loadWritableOrder(
    orderId: number,
    user: AuthUser,
  ): Promise<Order> {
    const order = await this.loadParticipatingOrder(orderId, user);

    if (isFinalState(order.status)) {
      throw new BadRequestException(
        order.status === OrderStatus.COMPLETED
          ? 'الطلب مكتمل — المحادثة للعرض فقط'
          : 'الطلب ملغي — المحادثة للعرض فقط',
      );
    }
    if (!order.acceptedDriverId) {
      throw new BadRequestException('المحادثة تبدأ بعد إسناد الطلب لكابتن');
    }
    return order;
  }

  /**
   * Which side is talking. Admins fall through to the refusal on purpose —
   * they read the conversation, they do not join it.
   */
  private senderRoleFor(order: Order, user: AuthUser): OrderMessageSender {
    if (Number(order.customerId) === Number(user.sub)) {
      return OrderMessageSender.CUSTOMER;
    }
    if (isOrderParticipantDriver(order, user)) {
      return OrderMessageSender.DRIVER;
    }
    throw new ForbiddenException(
      user.role === UserRole.ADMIN
        ? 'الإدارة تطّلع على المحادثة ولا تشارك فيها'
        : 'عفواً، هذه المحادثة لا تخصك',
    );
  }

  private append(order: Order, message: Partial<OrderMessage>) {
    return this.messageRepository.save(
      this.messageRepository.create({ ...message, orderId: order.id }),
    );
  }

  /** Puts the message in the other party's notification centre. */
  private async notifyCounterparty(
    order: Order,
    senderRole: OrderMessageSender,
    title: string,
    preview: string,
  ) {
    const recipientId =
      senderRole === OrderMessageSender.CUSTOMER
        ? order.acceptedDriverId
        : order.customerId;
    if (!recipientId) return;

    await this.ordersService.createNotification(
      recipientId,
      `💬 ${title}`,
      `الطلب FL-${order.id}: ${preview.slice(0, 120)}`,
    );
  }
}

/** The caller is the driver this order was actually assigned to. */
function isOrderParticipantDriver(order: Order, user: AuthUser): boolean {
  return (
    order.acceptedDriverId != null &&
    Number(order.acceptedDriverId) === Number(user.sub)
  );
}
