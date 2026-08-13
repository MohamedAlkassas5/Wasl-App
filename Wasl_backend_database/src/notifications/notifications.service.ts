import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';

import { InAppNotification } from '../orders/entities/notification.entity';
import { DeviceToken, DevicePlatform } from './entities/device-token.entity';
import { PUSH_PROVIDER, PushProvider } from './push-provider.interface';

/**
 * What the app should do when a notification is tapped.
 *
 * Sent as FCM `data`, so it must stay free of anything personal — these are
 * routing hints, not content.
 */
export enum NotificationKind {
  ORDER_OFFER = 'order_offer',
  OFFER_EXPIRED = 'offer_expired',
  ORDER_EXPIRED = 'order_expired',
  ORDER_UPDATE = 'order_update',
}

export interface NotifyOptions {
  kind?: NotificationKind;
  orderId?: number;
}

/**
 * One notification, delivered twice: as a row the app can list, and as a push
 * the phone can wake up for.
 *
 * Every notification in the system goes through here. `OrdersService`,
 * `OrderChatService`, `OrderCancellationService` and `OrderAssignmentService`
 * all funnel into this one method rather than each writing their own rows and
 * each deciding whether to push — which is precisely how a codebase ends up
 * with two notification systems that disagree.
 *
 * Delivery is best-effort by design. A push that fails must never roll back the
 * thing that triggered it: an order really was offered, really did expire, and
 * the in-app row is the durable record either way. Nothing in here throws.
 */
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(InAppNotification)
    private readonly notificationRepository: Repository<InAppNotification>,
    @InjectRepository(DeviceToken)
    private readonly deviceRepository: Repository<DeviceToken>,
    @Inject(PUSH_PROVIDER) private readonly push: PushProvider,
  ) {}

  // ─── Device registration ─────────────────────────────────────────────────

  /**
   * Claims a device for a user.
   *
   * Re-registering an existing token moves it to whoever is signed in now. That
   * matters on a shared phone: without it the previous driver would keep
   * getting offers on a device they no longer hold.
   */
  async registerDevice(
    userId: number,
    token: string,
    platform: DevicePlatform = DevicePlatform.ANDROID,
  ) {
    const now = new Date();
    const existing = await this.deviceRepository.findOne({ where: { token } });

    if (existing) {
      existing.userId = userId;
      existing.platform = platform;
      existing.lastSeenAt = now;
      await this.deviceRepository.save(existing);
    } else {
      await this.deviceRepository.save(
        this.deviceRepository.create({
          userId,
          token,
          platform,
          lastSeenAt: now,
        }),
      );
    }

    return { success: true };
  }

  /** Sign-out, or the app being uninstalled politely. */
  async unregisterDevice(userId: number, token: string) {
    await this.deviceRepository.delete({ userId, token });
    return { success: true };
  }

  // ─── Sending ─────────────────────────────────────────────────────────────

  /**
   * Records a notification and pushes it.
   *
   * Returns the saved row so callers that want it (the existing
   * `OrdersService.createNotification` contract) keep working unchanged.
   */
  async notify(
    userId: number,
    title: string,
    message: string,
    options: NotifyOptions = {},
  ): Promise<InAppNotification> {
    const saved = await this.notificationRepository.save(
      this.notificationRepository.create({ userId, title, message }),
    );

    // Push is a courtesy on top of the row that was just written. Deliberately
    // not awaited into the caller's failure path.
    await this.pushToUser(userId, title, message, options);

    return saved;
  }

  /** Same message to several people — one query for their devices. */
  async notifyMany(
    userIds: number[],
    title: string,
    message: string,
    options: NotifyOptions = {},
  ): Promise<void> {
    if (userIds.length === 0) return;

    await this.notificationRepository.save(
      userIds.map((userId) =>
        this.notificationRepository.create({ userId, title, message }),
      ),
    );

    const devices = await this.deviceRepository.find({
      where: { userId: In(userIds) },
    });
    await this.dispatch(devices, title, message, options);
  }

  private async pushToUser(
    userId: number,
    title: string,
    body: string,
    options: NotifyOptions,
  ): Promise<void> {
    const devices = await this.deviceRepository.find({ where: { userId } });
    await this.dispatch(devices, title, body, options);
  }

  private async dispatch(
    devices: DeviceToken[],
    title: string,
    body: string,
    options: NotifyOptions,
  ): Promise<void> {
    if (devices.length === 0) return;

    try {
      const data: Record<string, string> = {};
      if (options.kind) data.kind = options.kind;
      if (options.orderId != null) data.orderId = String(options.orderId);

      const result = await this.push.send({
        tokens: devices.map((d) => d.token),
        title,
        body,
        data,
      });

      // Dead tokens are pruned rather than retried for ever.
      if (result.invalidTokens.length > 0) {
        await this.deviceRepository.delete({
          token: In(result.invalidTokens),
        });
        this.logger.debug(
          `Pruned ${result.invalidTokens.length} dead device token(s).`,
        );
      }
    } catch (error) {
      // Never propagate: the caller's operation already succeeded.
      this.logger.error(
        'Notification dispatch failed',
        error instanceof Error ? error.message : String(error),
      );
    }
  }
}
