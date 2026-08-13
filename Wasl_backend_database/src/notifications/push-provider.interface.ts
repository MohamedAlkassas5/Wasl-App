/**
 * One push message, already addressed.
 *
 * `data` carries the few identifiers the app needs to open the right screen
 * when the notification is tapped — an order id, a kind. Never a phone number,
 * an address, a price, a document path or anything else that would sit in a
 * push payload on Google's servers and in the notification shade of an unlocked
 * phone. The body text is written on that assumption too: enough for the driver
 * to know it is worth opening, no more.
 */
export interface PushMessage {
  tokens: string[];
  title: string;
  body: string;
  /** Small, non-sensitive routing hints. Values must be strings for FCM. */
  data?: Record<string, string>;
}

export interface PushResult {
  sent: number;
  /** Tokens the provider rejected as dead — the caller prunes these. */
  invalidTokens: string[];
}

/**
 * Provider-agnostic push delivery contract.
 *
 * Deliberately the same shape as {@link OtpProvider}: business logic depends on
 * this interface and never on a vendor SDK, so swapping FCM for anything else
 * is a change to one module binding.
 *
 * Implementations must **not** throw on delivery failure. A push that does not
 * arrive is a degraded notification, not a failed operation — and the operations
 * that trigger these (an order being offered, an order expiring) must not be
 * rolled back because Google had a bad minute.
 */
export interface PushProvider {
  readonly name: string;
  send(message: PushMessage): Promise<PushResult>;
}

/** DI token used to inject the active PushProvider implementation. */
export const PUSH_PROVIDER = Symbol('PUSH_PROVIDER');
