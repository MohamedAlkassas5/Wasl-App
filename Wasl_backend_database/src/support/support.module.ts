import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { SupportConversation } from './entities/support-conversation.entity';
import { SupportMessage } from './entities/support-message.entity';
import { User } from '../users/entities/user.entity';
import { SupportService } from './support.service';
import { SupportController } from './support.controller';
import { AdminSupportController } from './admin-support.controller';

/**
 * Driver ↔ admin support chat.
 *
 * `StorageModule`, `NotificationsModule` and `AdminAuditLogModule` are all
 * @Global, so the upload service, the notifier and the audit log are injected
 * without importing them — the same way OrdersModule and PaymentsModule get
 * them.
 *
 * Exported so `FilesModule` can ask whether a caller may read a support
 * attachment without duplicating the ownership rule.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([SupportConversation, SupportMessage, User]),
  ],
  controllers: [SupportController, AdminSupportController],
  providers: [SupportService],
  exports: [SupportService],
})
export class SupportModule {}
