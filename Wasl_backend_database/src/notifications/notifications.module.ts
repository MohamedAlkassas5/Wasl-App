import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { InAppNotification } from '../orders/entities/notification.entity';
import { DeviceToken } from './entities/device-token.entity';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { PUSH_PROVIDER } from './push-provider.interface';
import { FcmPushProvider } from './providers/fcm-push.provider';

/**
 * Global so every module that already notifies — orders, chat, cancellation,
 * assignment — can inject the one service rather than each growing its own.
 *
 * 🔌 Swap the PUSH_PROVIDER binding to change vendor; nothing outside this
 * module knows FCM exists.
 */
@Global()
@Module({
  imports: [TypeOrmModule.forFeature([InAppNotification, DeviceToken])],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    { provide: PUSH_PROVIDER, useClass: FcmPushProvider },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
