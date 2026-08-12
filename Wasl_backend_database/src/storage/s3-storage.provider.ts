/* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-argument */
import type { Readable } from 'stream';
import { PassThrough } from 'stream';
import {
  S3Client,
  PutObjectCommand,
  HeadObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { StorageProvider } from './storage-provider';

/** Cloudflare R2 (or any S3-compatible object store) implementation. */
export class S3StorageProvider implements StorageProvider {
  readonly name = 'r2';
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor() {
    const endpoint = process.env.R2_ENDPOINT || process.env.S3_ENDPOINT;
    const accessKeyId = process.env.R2_ACCESS_KEY_ID || process.env.S3_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY || process.env.S3_SECRET_ACCESS_KEY;
    this.bucket = process.env.R2_BUCKET || process.env.S3_BUCKET || '';
    if (!endpoint || !accessKeyId || !secretAccessKey || !this.bucket) {
      throw new Error(
        'STORAGE_DRIVER=s3 requires R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY and R2_BUCKET',
      );
    }
    this.client = new S3Client({
      region: process.env.R2_REGION || process.env.S3_REGION || 'auto',
      endpoint,
      forcePathStyle: true,
      credentials: { accessKeyId, secretAccessKey },
    });
  }

  private key(key: string): string {
    return key.replace(/^\/+/, '');
  }

  async save(key: string, data: Buffer, contentType?: string): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: this.key(key),
        Body: data,
        ContentType: contentType,
        CacheControl: 'private, no-store',
      }),
    );
  }

  async exists(key: string): Promise<boolean> {
    try {
      await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: this.key(key) }),
      );
      return true;
    } catch (error: any) {
      if (
        error?.$metadata?.httpStatusCode === 404 ||
        error?.name === 'NotFound'
      )
        return false;
      throw error;
    }
  }

  localPath(): string | null {
    return null;
  }

  createReadStream(key: string): Readable {
    const output = new PassThrough();
    this.client
      .send(new GetObjectCommand({ Bucket: this.bucket, Key: this.key(key) }))
      .then((result: any) => {
        if (result.Body?.pipe) result.Body.pipe(output);
        else if (result.Body?.transformToByteArray)
          result.Body.transformToByteArray().then((bytes: Uint8Array) => {
            output.end(Buffer.from(bytes));
          });
        else output.destroy(new Error('R2 response has no readable body'));
      })
      .catch((error) => output.destroy(error));
    return output;
  }
}
