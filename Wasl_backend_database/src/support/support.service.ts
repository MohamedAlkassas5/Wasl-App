import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, MoreThan, Repository } from 'typeorm';

import { AuthUser } from '../auth/current-user';
import { User, UserRole } from '../users/entities/user.entity';
import { UploadService } from '../storage/upload.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  SupportConversation,
  SupportConversationStatus,
} from './entities/support-conversation.entity';
import {
  SupportMessage,
  SupportMessageKind,
  SupportMessageSender,
} from './entities/support-message.entity';
import { ListSupportMessagesDto, SendSupportMessageDto } from './dto/support.dto';

/** Sub-folder under `uploads/` that support attachments are written to. */
export const SUPPORT_UPLOAD_FOLDER = 'support';

/**
 * Driver ↔ admin support.
 *
 * Three rules shape everything here, and each one is a thing that would
 * otherwise go wrong:
 *
 *  1. **A user reaches their own thread and no other.** Every user-facing
 *     method takes the id from the token and resolves the thread from it.
 *     There is no route that accepts a conversation id from a driver, so
 *     "driver reads another driver's support thread" is not a check that can
 *     be forgotten — it is unreachable by construction. Admin routes do take
 *     an id, and they are behind the ADMIN role.
 *
 *  2. **The server decides who is speaking.** `senderRole` comes from the
 *     authenticated role, never from the body. The app renders admin bubbles
 *     differently and a driver who could set this could forge an official
 *     "your wallet has been credited" reply to themselves.
 *
 *  3. **History is append-only.** Nothing edits or deletes a message. Support
 *     conversations are where the platform tells a driver what happened to
 *     their money; a record that can be quietly rewritten afterwards is worth
 *     nothing to either side.
 */
@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  constructor(
    @InjectRepository(SupportConversation)
    private readonly conversationRepository: Repository<SupportConversation>,

    @InjectRepository(SupportMessage)
    private readonly messageRepository: Repository<SupportMessage>,

    @InjectRepository(User)
    private readonly userRepository: Repository<User>,

    private readonly uploadService: UploadService,
    private readonly notifications: NotificationsService,
  ) {}

  // ─── The user's own thread ───────────────────────────────────────────────

  /**
   * The caller's conversation, oldest message first.
   *
   * Returns an empty thread rather than creating one: opening the screen is
   * not the same as contacting support, and a row per curious tap would fill
   * the admin's inbox with silence. The thread is created by the first
   * message.
   */
  async listMyMessages(user: AuthUser, query: ListSupportMessagesDto) {
    const conversation = await this.conversationRepository.findOne({
      where: { userId: user.sub },
    });

    if (!conversation) {
      return {
        success: true,
        conversationId: null,
        status: SupportConversationStatus.OPEN,
        messages: [],
      };
    }

    const messages = await this.messageRepository.find({
      where: {
        conversationId: conversation.id,
        ...(query.after ? { id: MoreThan(query.after) } : {}),
      },
      order: { id: 'ASC' },
      take: query.limit ?? 100,
    });

    return {
      success: true,
      conversationId: conversation.id,
      status: conversation.status,
      messages,
    };
  }

  /** Admin replies this caller has not read yet. Drives the badge. */
  async myUnreadCount(user: AuthUser) {
    const conversation = await this.conversationRepository.findOne({
      where: { userId: user.sub },
    });
    if (!conversation) return { success: true, unread: 0 };

    const unread = await this.messageRepository.count({
      where: {
        conversationId: conversation.id,
        senderRole: SupportMessageSender.ADMIN,
        readAt: IsNull(),
      },
    });

    return { success: true, unread };
  }

  /** Marks the admin's replies as read. */
  async markMyRead(user: AuthUser) {
    const conversation = await this.conversationRepository.findOne({
      where: { userId: user.sub },
    });
    if (!conversation) return { success: true };

    await this.markRead(conversation.id, SupportMessageSender.ADMIN);
    return { success: true };
  }

  /** The user writes to support. Creates the thread if this is the first one. */
  async sendMyMessage(user: AuthUser, dto: SendSupportMessageDto) {
    const conversation = await this.openConversationFor(user.sub);

    const message = await this.append(conversation, {
      senderId: user.sub,
      senderRole: SupportMessageSender.USER,
      kind: SupportMessageKind.TEXT,
      body: dto.body.trim(),
    });

    return { success: true, conversationId: conversation.id, data: message };
  }

  /** The user attaches a screenshot — usually the transfer behind a complaint. */
  async sendMyImage(
    user: AuthUser,
    file: Express.Multer.File | undefined,
    caption?: string,
  ) {
    const attachmentUrl = await this.uploadService.persistImage(
      file,
      SUPPORT_UPLOAD_FOLDER,
      'support',
    );
    if (!attachmentUrl) {
      throw new BadRequestException('لم يتم إرفاق صورة');
    }

    const conversation = await this.openConversationFor(user.sub);
    const message = await this.append(conversation, {
      senderId: user.sub,
      senderRole: SupportMessageSender.USER,
      kind: SupportMessageKind.IMAGE,
      body: caption?.trim() || null,
      attachmentUrl,
    });

    return { success: true, conversationId: conversation.id, data: message };
  }

  // ─── The admin side ──────────────────────────────────────────────────────

  /**
   * The inbox: threads with someone waiting, most recent first.
   *
   * Carries the person's name, phone and role so the admin knows who they are
   * answering without opening every thread, plus the count of messages still
   * unanswered.
   */
  async listConversations(status?: SupportConversationStatus) {
    const conversations = await this.conversationRepository.find({
      where: status ? { status } : {},
      order: { lastMessageAt: 'DESC' },
      take: 200,
    });
    if (conversations.length === 0) return [];

    const users = await this.userRepository.find({
      where: { id: In(conversations.map((c) => c.userId)) },
    });
    const byId = new Map(users.map((u) => [u.id, u]));

    const summaries = await Promise.all(
      conversations.map(async (conversation) => {
        const [last] = await this.messageRepository.find({
          where: { conversationId: conversation.id },
          order: { id: 'DESC' },
          take: 1,
        });
        const unread = await this.messageRepository.count({
          where: {
            conversationId: conversation.id,
            senderRole: SupportMessageSender.USER,
            readAt: IsNull(),
          },
        });

        const person = byId.get(conversation.userId);
        return {
          id: conversation.id,
          userId: conversation.userId,
          userName: person?.name ?? null,
          userPhone: person?.phone ?? null,
          userRole: person?.role ?? null,
          status: conversation.status,
          lastMessageAt: conversation.lastMessageAt,
          lastMessagePreview: last?.body?.slice(0, 120) ?? null,
          lastMessageFrom: last?.senderRole ?? null,
          unread,
        };
      }),
    );

    return summaries;
  }

  async listConversationMessages(
    conversationId: number,
    query: ListSupportMessagesDto,
  ) {
    const conversation = await this.loadConversation(conversationId);
    const person = await this.userRepository.findOne({
      where: { id: conversation.userId },
    });

    const messages = await this.messageRepository.find({
      where: {
        conversationId,
        ...(query.after ? { id: MoreThan(query.after) } : {}),
      },
      order: { id: 'ASC' },
      take: query.limit ?? 200,
    });

    return {
      success: true,
      conversation: {
        id: conversation.id,
        userId: conversation.userId,
        userName: person?.name ?? null,
        userPhone: person?.phone ?? null,
        userRole: person?.role ?? null,
        status: conversation.status,
      },
      messages,
    };
  }

  /** Admin replies. The driver gets the existing notification + push. */
  async replyAsAdmin(
    conversationId: number,
    admin: AuthUser,
    dto: SendSupportMessageDto,
  ) {
    const conversation = await this.loadConversation(conversationId);

    const message = await this.append(conversation, {
      senderId: admin.sub,
      senderRole: SupportMessageSender.ADMIN,
      kind: SupportMessageKind.TEXT,
      body: dto.body.trim(),
    });

    // A reply reopens a thread an admin had closed — otherwise the driver
    // would see an answer in a conversation the panel says is finished.
    if (conversation.status === SupportConversationStatus.CLOSED) {
      await this.conversationRepository.update(
        { id: conversation.id },
        { status: SupportConversationStatus.OPEN },
      );
    }

    // Outside the write: a failed push must not lose the reply.
    await this.notifyUser(
      conversation.userId,
      '💬 رد من الدعم الفني',
      dto.body.trim().slice(0, 120),
    );

    return { success: true, data: message };
  }

  async markConversationRead(conversationId: number) {
    await this.loadConversation(conversationId);
    await this.markRead(conversationId, SupportMessageSender.USER);
    return { success: true };
  }

  async setStatus(conversationId: number, status: SupportConversationStatus) {
    const conversation = await this.loadConversation(conversationId);
    await this.conversationRepository.update({ id: conversation.id }, { status });
    return { success: true, id: conversation.id, status };
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  /**
   * The caller's thread, created on first use.
   *
   * `user_id` is UNIQUE, so two simultaneous first messages cannot produce two
   * threads: the loser's insert is rejected by the database and it re-reads
   * the row the winner wrote, rather than both quietly succeeding.
   */
  private async openConversationFor(
    userId: number,
  ): Promise<SupportConversation> {
    const existing = await this.conversationRepository.findOne({
      where: { userId },
    });
    if (existing) return existing;

    try {
      return await this.conversationRepository.save(
        this.conversationRepository.create({
          userId,
          status: SupportConversationStatus.OPEN,
        }),
      );
    } catch {
      const raced = await this.conversationRepository.findOne({
        where: { userId },
      });
      if (!raced) throw new BadRequestException('تعذّر فتح محادثة الدعم');
      return raced;
    }
  }

  private async loadConversation(id: number): Promise<SupportConversation> {
    const conversation = await this.conversationRepository.findOne({
      where: { id },
    });
    if (!conversation) throw new NotFoundException('محادثة الدعم غير موجودة');
    return conversation;
  }

  /** Appends a message and moves the thread to the top of the inbox. */
  private async append(
    conversation: SupportConversation,
    fields: Partial<SupportMessage>,
  ): Promise<SupportMessage> {
    const saved = await this.messageRepository.save(
      this.messageRepository.create({
        conversationId: conversation.id,
        ...fields,
      }),
    );

    await this.conversationRepository.update(
      { id: conversation.id },
      { lastMessageAt: saved.createdAt ?? new Date() },
    );

    return saved;
  }

  /** Marks everything written by `from` in this thread as read. */
  private async markRead(conversationId: number, from: SupportMessageSender) {
    await this.messageRepository
      .createQueryBuilder()
      .update(SupportMessage)
      .set({ readAt: new Date() })
      .where('conversation_id = :conversationId', { conversationId })
      .andWhere('sender_role = :from', { from })
      .andWhere('read_at IS NULL')
      .execute();
  }

  private async notifyUser(userId: number, title: string, message: string) {
    try {
      await this.notifications.notify(userId, title, message);
    } catch (error) {
      this.logger.error(
        'Support reply notification failed',
        error instanceof Error ? error.message : String(error),
      );
    }
  }

  /**
   * Whether this user may read a support attachment — used by
   * `FilesService.canRead`, which is the only way the bytes are served.
   */
  async canReadAttachment(user: AuthUser, key: string): Promise<boolean> {
    if (user.role === UserRole.ADMIN) return true;

    const message = await this.messageRepository.findOne({
      where: { attachmentUrl: key },
    });
    if (!message) return false;

    const conversation = await this.conversationRepository.findOne({
      where: { id: message.conversationId },
    });
    return conversation?.userId === user.sub;
  }
}
