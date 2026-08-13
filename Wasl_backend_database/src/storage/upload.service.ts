import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { randomBytes } from 'crypto';

import { IMAGE_EXTENSIONS, sniffImageType } from '../common/upload-policy';
import { STORAGE_PROVIDER, StorageProvider } from './storage-provider';

/**
 * The one place an uploaded file becomes a stored object.
 *
 * Every upload route hands its buffer here and gets back the DB-relative key
 * (`uploads/chat/chat-….jpg`) to persist on the owning row. Routing all writes
 * through `StorageProvider` is what makes the local-disk → R2 switch real: with
 * `diskStorage`, files landed on the container's disk no matter what
 * `STORAGE_DRIVER` said, and `FilesController` then could not find them.
 *
 * The stored name is generated here, never taken from the client. It matches
 * `FilesService.SAFE_NAME` by construction, and the extension comes from the
 * verified signature rather than from `originalname`.
 */
@Injectable()
export class UploadService {
  constructor(
    @Inject(STORAGE_PROVIDER)
    private readonly storage: StorageProvider,
  ) {}

  /**
   * Persists one image and returns its key, or `undefined` when no file was
   * sent (most upload fields are optional).
   *
   * @param folder sub-folder under `uploads/`, or '' for the root
   * @param prefix leading token of the filename, e.g. `chat`
   */
  async persistImage(
    file: Express.Multer.File | undefined,
    folder: string,
    prefix: string,
  ): Promise<string | undefined> {
    if (!file?.buffer?.length) return undefined;

    // 🔐 Trust the bytes, not the Content-Type the client claimed.
    const contentType = sniffImageType(file.buffer);
    if (!contentType) {
      throw new BadRequestException('الملف المرفوع ليس صورة صالحة');
    }

    const unique = `${Date.now()}-${randomBytes(6).toString('hex')}`;
    const key = folder
      ? `uploads/${folder}/${prefix}-${unique}${IMAGE_EXTENSIONS[contentType]}`
      : `uploads/${prefix}-${unique}${IMAGE_EXTENSIONS[contentType]}`;

    await this.storage.save(key, file.buffer, contentType);
    return key;
  }
}
