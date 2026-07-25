import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { OtpProvider } from '../otp-provider.interface';

/**
 * Meta WhatsApp Cloud API adapter.
 *
 * Production credentials come from the environment (never hardcoded):
 *   WHATSAPP_TOKEN            – permanent/system-user access token
 *   WHATSAPP_PHONE_NUMBER_ID  – the sender phone-number id
 *   WHATSAPP_OTP_TEMPLATE     – (optional) approved template name
 *   WHATSAPP_TEMPLATE_LANG    – (optional) template language, default ar
 *
 * When credentials are absent (local dev / MVP), this becomes a safe
 * placeholder: it logs the code to the server console instead of sending,
 * so the whole OTP flow is testable end-to-end without a live WhatsApp
 * account. The production HTTP call is fully implemented and activates the
 * moment the env vars are set.
 */
@Injectable()
export class MetaWhatsAppProvider implements OtpProvider {
  readonly name = 'meta-whatsapp-cloud';
  private readonly logger = new Logger(MetaWhatsAppProvider.name);

  constructor(
    private readonly config: ConfigService,
    private readonly http: HttpService,
  ) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    const token = this.config.get<string>('WHATSAPP_TOKEN');
    const phoneNumberId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID');

    // 🧪 Placeholder mode — no credentials configured yet.
    if (!token || !phoneNumberId) {
      this.logger.warn(
        `📲 [OTP DEV MODE] WhatsApp not configured. Code for ${phone} is: ${code}`,
      );
      return;
    }

    const templateName = this.config.get<string>('WHATSAPP_OTP_TEMPLATE');
    const lang = this.config.get<string>('WHATSAPP_TEMPLATE_LANG') ?? 'ar';
    const url = `https://graph.facebook.com/v20.0/${phoneNumberId}/messages`;

    // Prefer an approved template (required for business-initiated messages);
    // fall back to a plain text message when no template name is provided.
    const payload = templateName
      ? {
          messaging_product: 'whatsapp',
          to: phone,
          type: 'template',
          template: {
            name: templateName,
            language: { code: lang },
            components: [
              {
                type: 'body',
                parameters: [{ type: 'text', text: code }],
              },
            ],
          },
        }
      : {
          messaging_product: 'whatsapp',
          to: phone,
          type: 'text',
          text: { body: `رمز التحقق الخاص بك في وصل هو: ${code}` },
        };

    try {
      await firstValueFrom(
        this.http.post(url, payload, {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        }),
      );
      this.logger.log(`📤 [OTP] WhatsApp code sent to ${phone}`);
    } catch (error) {
      this.logger.error(
        `💥 [OTP] WhatsApp delivery failed for ${phone}`,
        error instanceof Error ? error.message : String(error),
      );
      throw new Error('تعذّر إرسال رمز التحقق عبر واتساب، حاول لاحقاً');
    }
  }
}
