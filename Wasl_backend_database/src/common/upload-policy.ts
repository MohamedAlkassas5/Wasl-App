import { BadRequestException } from '@nestjs/common';
import { memoryStorage, type Options } from 'multer';

const allowedImageTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

/** The extension we store for each format we accept, keyed by real type. */
export const IMAGE_EXTENSIONS: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

/**
 * Shared Multer limits for every user-controlled image upload.
 *
 * Bytes are buffered in memory instead of being written straight to disk. The
 * upload then goes to whatever `StorageProvider` is configured — local disk in
 * development, R2 in production. `diskStorage` bypassed that seam completely:
 * production is required to run `STORAGE_DRIVER=s3`, so every file was written
 * to the container's ephemeral disk while every read looked for it in the
 * bucket and 404'd. Buffering here is what lets the write and the read agree.
 */
export const imageUploadPolicy: Pick<
  Options,
  'limits' | 'fileFilter' | 'storage'
> = {
  storage: memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 4 },
  fileFilter: (_request, file, callback) => {
    if (!allowedImageTypes.has(file.mimetype)) {
      callback(
        new BadRequestException(
          'Only JPEG, PNG, and WebP image uploads are allowed.',
        ),
      );
      return;
    }
    callback(null, true);
  },
};

/**
 * The real type of an upload, read from its leading bytes.
 *
 * `fileFilter` above can only see the Content-Type the client declared, and
 * forging that header costs an attacker nothing — an HTML page or a script
 * announced as `image/jpeg` sailed through. The signature is the file itself.
 *
 * Returns null when the bytes match none of the formats we accept, which is
 * what callers turn into a rejection.
 */
export function sniffImageType(buffer: Buffer): string | null {
  if (
    buffer.length >= 3 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff
  ) {
    return 'image/jpeg';
  }

  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(png)) {
    return 'image/png';
  }

  // RIFF....WEBP
  if (
    buffer.length >= 12 &&
    buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
    buffer.subarray(8, 12).toString('ascii') === 'WEBP'
  ) {
    return 'image/webp';
  }

  return null;
}
