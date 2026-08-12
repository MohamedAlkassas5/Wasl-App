import { BadRequestException } from '@nestjs/common';
import type { Options } from 'multer';

const allowedImageTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

/** Shared Multer limits for every user-controlled image upload. */
export const imageUploadPolicy: Pick<Options, 'limits' | 'fileFilter'> = {
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
