import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

import {
  PushProvider,
  PushMessage,
  PushResult,
} from '../push-provider.interface';

/** FCM error codes that mean the token is dead for good, not just failing. */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Firebase Cloud Messaging adapter.
 *
 * Credentials come from the environment, never from a committed file:
 *   FIREBASE_PROJECT_ID
 *   FIREBASE_CLIENT_EMAIL
 *   FIREBASE_PRIVATE_KEY   – the service-account key, `\n` escaped
 *
 * With them absent this becomes a safe placeholder that logs what it *would*
 * have sent, so the whole assignment flow is testable end to end without a
 * Firebase project. The production path is fully implemented and activates the
 * moment the variables are set — the same arrangement as the WhatsApp OTP
 * provider, and for the same reason: a half-wired integration that silently
 * does nothing is worse than one that says so.
 *
 * In production, missing credentials are reported loudly at first send rather
 * than quietly dropping every notification for ever.
 */
@Injectable()
export class FcmPushProvider implements PushProvider {
  readonly name = 'firebase-cloud-messaging';
  private readonly logger = new Logger(FcmPushProvider.name);
  private app: App | null = null;
  private initialised = false;

  constructor(private readonly config: ConfigService) {}

  /**
   * Builds the Firebase app on first use.
   *
   * Lazily, because every local run and every test without credentials must not
   * pay for an SDK handshake it will never use.
   */
  private resolveApp(): App | null {
    if (this.initialised) return this.app;
    this.initialised = true;

    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.config
      .get<string>('FIREBASE_PRIVATE_KEY')
      ?.replace(/\\n/g, '\n');

    if (!projectId || !clientEmail || !privateKey) {
      if (this.config.get<string>('NODE_ENV') === 'production') {
        throw new Error(
          'Push notifications are not configured in production. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY.',
        );
      }
      this.logger.warn(
        '📲 [PUSH DEV MODE] Firebase not configured — notifications will be logged, not delivered.',
      );
      return null;
    }

    const existing = getApps();
    this.app = existing.length
      ? existing[0]
      : initializeApp({
          credential: cert({ projectId, clientEmail, privateKey }),
        });
    this.logger.log('📲 Push backend: Firebase Cloud Messaging.');
    return this.app;
  }

  async send(message: PushMessage): Promise<PushResult> {
    if (message.tokens.length === 0) return { sent: 0, invalidTokens: [] };

    let app: App | null;
    try {
      app = this.resolveApp();
    } catch (error) {
      // Misconfiguration in production. Loud, but still not thrown at the
      // caller — the order flow is not this integration's to break.
      this.logger.error(error instanceof Error ? error.message : String(error));
      return { sent: 0, invalidTokens: [] };
    }

    if (!app) {
      this.logger.debug(
        `📲 [PUSH DEV MODE] "${message.title}" → ${message.tokens.length} device(s)`,
      );
      return { sent: 0, invalidTokens: [] };
    }

    try {
      const response = await getMessaging(app).sendEachForMulticast({
        tokens: message.tokens,
        notification: { title: message.title, body: message.body },
        data: message.data,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });

      const invalidTokens = response.responses.flatMap((result, index) =>
        result.error && DEAD_TOKEN_CODES.has(result.error.code)
          ? [message.tokens[index]]
          : [],
      );

      return { sent: response.successCount, invalidTokens };
    } catch (error) {
      this.logger.error(
        'Push delivery failed',
        error instanceof Error ? error.message : String(error),
      );
      return { sent: 0, invalidTokens: [] };
    }
  }
}
