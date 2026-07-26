import type { Readable } from 'stream';
import { StorageProvider } from './storage-provider';

/**
 * ⛔ UNFINISHED adapter — a documented placeholder, not a working backend.
 *
 * Selecting it (`STORAGE_DRIVER=s3`) fails fast on boot rather than silently
 * losing files, so it can't be half-enabled by accident. To make it real:
 *
 * 1. `npm i @aws-sdk/client-s3` (or the Cloudinary SDK).
 * 2. Read config from env: STORAGE_BUCKET, STORAGE_REGION,
 *    AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (or Cloudinary equivalents).
 * 3. Implement the four methods against the SDK:
 *    - save(key, data, contentType) → PutObjectCommand (key WITHOUT the
 *      leading `uploads/`, or keep it as the object prefix — just be
 *      consistent with what canRead() matches on).
 *    - exists(key) → HeadObjectCommand (true unless 404).
 *    - localPath(key) → return null (there is no local file).
 *    - createReadStream(key) → GetObjectCommand(...).Body as a stream.
 * 4. **Also route the write side through this provider.** The multer
 *    `diskStorage` engines in `auth.controller.ts` and `orders.controller.ts`
 *    still write to local disk. For S3 they must switch to `memoryStorage()`
 *    and call `storageProvider.save(key, file.buffer, file.mimetype)` in the
 *    handler; otherwise reads go to S3 while writes go to a disk that the next
 *    deploy wipes. FilesController's read path already goes through this
 *    interface and needs no further change.
 *
 * Until then the default `local-disk` backend is the only supported one.
 */
export class S3StorageProvider implements StorageProvider {
  readonly name = 's3';

  constructor() {
    throw new Error(
      "STORAGE_DRIVER=s3 selected, but the S3 adapter is not implemented yet. " +
        'See src/storage/s3-storage.provider.ts for the steps, or unset ' +
        'STORAGE_DRIVER to use local disk.',
    );
  }

  save(): Promise<void> {
    throw new Error('S3StorageProvider.save not implemented');
  }
  exists(): Promise<boolean> {
    throw new Error('S3StorageProvider.exists not implemented');
  }
  localPath(): string | null {
    return null;
  }
  createReadStream(): Readable {
    throw new Error('S3StorageProvider.createReadStream not implemented');
  }
}
