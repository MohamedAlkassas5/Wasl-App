/**
 * Provider-agnostic OTP delivery contract.
 *
 * Business logic (OtpService) depends only on this interface, never on a
 * concrete SDK. Swapping Meta WhatsApp Cloud API for Twilio WhatsApp (or SMS)
 * is a one-line change in the module's provider binding — no service edits.
 */
export interface OtpProvider {
  /** Human-readable provider name (for logs/diagnostics). */
  readonly name: string;

  /**
   * Deliver a one-time code to the given phone number.
   * Implementations must throw on hard delivery failure so the caller can
   * surface an error to the user.
   */
  sendOtp(phone: string, code: string): Promise<void>;
}

/** DI token used to inject the active OtpProvider implementation. */
export const OTP_PROVIDER = Symbol('OTP_PROVIDER');
