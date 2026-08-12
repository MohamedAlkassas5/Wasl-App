import { BadRequestException, Injectable } from '@nestjs/common';
import { createReadStream, existsSync, promises as fsp } from 'fs';
import { dirname, join, resolve, sep } from 'path';
import type { Readable } from 'stream';

import { StorageProvider } from './storage-provider';

/**
 * Default backend: files live under `<cwd>/uploads`. Keys are the DB-relative
 * paths the app already stores, e.g. `uploads/orders/order-1.jpg`. This
 * preserves the original on-disk behaviour exactly; the abstraction is what
 * lets a remote backend replace it without touching callers.
 */
@Injectable()
export class LocalDiskStorageProvider implements StorageProvider {
  readonly name = 'local-disk';

  /** Absolute uploads root — every resolved path must stay inside it. */
  private readonly root = resolve(process.cwd(), 'uploads');

  /**
   * Map a `uploads/...` key to an absolute path, refusing anything that would
   * escape the uploads root (path traversal). Callers upstream already validate
   * the charset; this is defence in depth.
   */
  private toAbsolute(key: string): string {
    const relative = key.startsWith('uploads/')
      ? key.slice('uploads/'.length)
      : key;
    const abs = resolve(join(this.root, relative));
    if (abs !== this.root && !abs.startsWith(this.root + sep)) {
      throw new BadRequestException('مسار الملف غير صالح');
    }
    return abs;
  }

  localPath(key: string): string | null {
    return this.toAbsolute(key);
  }

  exists(key: string): Promise<boolean> {
    return Promise.resolve(existsSync(this.toAbsolute(key)));
  }

  async save(key: string, data: Buffer): Promise<void> {
    const abs = this.toAbsolute(key);
    await fsp.mkdir(dirname(abs), { recursive: true });
    await fsp.writeFile(abs, data);
  }

  createReadStream(key: string): Readable {
    return createReadStream(this.toAbsolute(key));
  }
}
