import type { Readable } from 'stream';

/** DI token for the active storage backend. */
export const STORAGE_PROVIDER = Symbol('STORAGE_PROVIDER');

/**
 * Where uploaded files (ID scans, selfies, order photos, receipts, payment
 * proofs) physically live. The rest of the app only knows the DB-relative
 * "key" of a file — e.g. `uploads/orders/order-123.jpg` — and never touches
 * `fs` directly, so the same code runs whether files sit on local disk or in
 * object storage.
 *
 * Why this exists: Render/Railway disks are **ephemeral** — every deploy wipes
 * `uploads/`, taking approved partners' national-ID documents with it. Moving
 * to S3/Cloudinary is just a matter of providing another implementation of this
 * interface; nothing else changes. (AUDIT §2.8 / §4 item 7.)
 */
export interface StorageProvider {
  /** Human-readable name for logs. */
  readonly name: string;

  /** Persist bytes under `key`. Overwrites if it already exists. */
  save(key: string, data: Buffer, contentType?: string): Promise<void>;

  /** Whether an object exists at `key`. */
  exists(key: string): Promise<boolean>;

  /**
   * The absolute filesystem path for `key` **if it is a local file**, else
   * null. Lets the local backend keep using `res.sendFile` (correct
   * Content-Type, range requests) while a remote backend falls back to
   * `createReadStream`.
   */
  localPath(key: string): string | null;

  /** A readable stream of the object's bytes (used when there is no localPath). */
  createReadStream(key: string): Readable;
}
