import { Global, Logger, Module } from '@nestjs/common';

import { STORAGE_PROVIDER, StorageProvider } from './storage-provider';
import { LocalDiskStorageProvider } from './local-disk-storage.provider';
import { S3StorageProvider } from './s3-storage.provider';
import { UploadService } from './upload.service';

/**
 * Global so any module can inject STORAGE_PROVIDER or UploadService without
 * re-importing. The backend is chosen once at boot by STORAGE_DRIVER
 * (default `local`).
 */
@Global()
@Module({
  providers: [
    {
      provide: STORAGE_PROVIDER,
      useFactory: (): StorageProvider => {
        const driver = (process.env.STORAGE_DRIVER || 'local').toLowerCase();
        const logger = new Logger('StorageModule');

        if (process.env.NODE_ENV === 'production' && driver === 'local') {
          throw new Error(
            'Local disk storage is disabled in production; configure STORAGE_DRIVER=s3 for R2',
          );
        }

        if (driver === 's3' || driver === 'cloudinary') {
          // Throws until the adapter is implemented — fail fast rather than
          // silently write to a disk the next deploy wipes.
          return new S3StorageProvider();
        }

        logger.log('📁 Storage backend: local-disk (uploads/).');
        return new LocalDiskStorageProvider();
      },
    },
    UploadService,
  ],
  exports: [STORAGE_PROVIDER, UploadService],
})
export class StorageModule {}
