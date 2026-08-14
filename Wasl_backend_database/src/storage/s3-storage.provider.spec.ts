import { Readable } from 'stream';

const send = jest.fn();
const clientConfigs: unknown[] = [];

jest.mock('@aws-sdk/client-s3', () => {
  const actual = jest.requireActual('@aws-sdk/client-s3');
  return {
    ...actual,
    // Commands stay real so their `input` can be asserted; only the transport
    // is faked. A mocked command would test the mock rather than the request
    // that would actually reach the bucket.
    S3Client: jest.fn().mockImplementation((config: unknown) => {
      clientConfigs.push(config);
      return { send };
    }),
  };
});

import { S3StorageProvider } from './s3-storage.provider';

/**
 * The R2 backend, exercised without a bucket.
 *
 * These cover the request this code *would* send and how it reads the replies.
 * They cannot prove anything about Cloudflare itself — that a bucket exists, is
 * private, or accepts these credentials — which is why the live verification in
 * `scripts/verify-r2.js` is a separate, still-outstanding step.
 */
describe('S3StorageProvider', () => {
  const R2_VARS = [
    'R2_ENDPOINT',
    'R2_ACCESS_KEY_ID',
    'R2_SECRET_ACCESS_KEY',
    'R2_BUCKET',
    'R2_REGION',
    'S3_ENDPOINT',
    'S3_ACCESS_KEY_ID',
    'S3_SECRET_ACCESS_KEY',
    'S3_BUCKET',
    'S3_REGION',
  ];
  const saved: Record<string, string | undefined> = {};

  const configure = (values: Record<string, string>) => {
    for (const [key, value] of Object.entries(values)) process.env[key] = value;
  };

  const validR2 = {
    R2_ENDPOINT: 'https://acct.r2.cloudflarestorage.com',
    R2_ACCESS_KEY_ID: 'test-key-id',
    R2_SECRET_ACCESS_KEY: 'test-secret',
    R2_BUCKET: 'wasl-uploads',
  };

  beforeAll(() => {
    for (const key of R2_VARS) saved[key] = process.env[key];
  });

  beforeEach(() => {
    for (const key of R2_VARS) delete process.env[key];
    send.mockReset();
    clientConfigs.length = 0;
  });

  afterAll(() => {
    for (const key of R2_VARS) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  });

  describe('configuration', () => {
    it('refuses to start with nothing configured', () => {
      // Fail at boot rather than at the first upload — a provider that
      // constructs happily and throws on save loses the file instead.
      expect(() => new S3StorageProvider()).toThrow(/requires/i);
    });

    it.each([
      'R2_ENDPOINT',
      'R2_ACCESS_KEY_ID',
      'R2_SECRET_ACCESS_KEY',
      'R2_BUCKET',
    ])('refuses to start when %s is missing', (missing) => {
      configure(validR2);
      delete process.env[missing];

      expect(() => new S3StorageProvider()).toThrow();
    });

    it('accepts the S3_* aliases', () => {
      configure({
        S3_ENDPOINT: 'https://minio.local',
        S3_ACCESS_KEY_ID: 'k',
        S3_SECRET_ACCESS_KEY: 's',
        S3_BUCKET: 'b',
      });

      expect(() => new S3StorageProvider()).not.toThrow();
    });

    it('prefers R2_* over S3_* when both are set', () => {
      configure({
        ...validR2,
        S3_ENDPOINT: 'https://wrong.example',
        S3_ACCESS_KEY_ID: 'wrong',
        S3_SECRET_ACCESS_KEY: 'wrong',
        S3_BUCKET: 'wrong-bucket',
      });

      new S3StorageProvider();

      // Worth pinning: setting both to different values silently uses R2_*,
      // which is a confusing way to spend an afternoon if it were the reverse.
      expect(clientConfigs[0]).toMatchObject({
        endpoint: 'https://acct.r2.cloudflarestorage.com',
      });
    });

    it('defaults the region to auto, which is what R2 expects', () => {
      configure(validR2);
      new S3StorageProvider();

      expect(clientConfigs[0]).toMatchObject({ region: 'auto' });
    });

    it('uses path-style addressing', () => {
      configure(validR2);
      new S3StorageProvider();

      // R2's S3 endpoint is per-account, with the bucket in the path.
      expect(clientConfigs[0]).toMatchObject({ forcePathStyle: true });
    });

    it('reports itself as r2 for logs', () => {
      configure(validR2);
      expect(new S3StorageProvider().name).toBe('r2');
    });
  });

  describe('save', () => {
    beforeEach(() => configure(validR2));

    it('puts the bytes at the key, in the configured bucket', async () => {
      send.mockResolvedValue({});
      const data = Buffer.from('image-bytes');

      await new S3StorageProvider().save(
        'uploads/orders/order-1.jpg',
        data,
        'image/jpeg',
      );

      expect(send).toHaveBeenCalledTimes(1);
      expect(send.mock.calls[0][0].input).toMatchObject({
        Bucket: 'wasl-uploads',
        Key: 'uploads/orders/order-1.jpg',
        Body: data,
        ContentType: 'image/jpeg',
      });
    });

    it('marks objects private and uncacheable', async () => {
      send.mockResolvedValue({});

      await new S3StorageProvider().save('uploads/a.jpg', Buffer.from('x'));

      // These are national IDs and payment proofs; they must not land in a
      // shared or CDN cache even for a moment.
      expect(send.mock.calls[0][0].input).toMatchObject({
        CacheControl: 'private, no-store',
      });
    });

    it('strips leading slashes so one file cannot become two objects', async () => {
      send.mockResolvedValue({});

      await new S3StorageProvider().save('/uploads/a.jpg', Buffer.from('x'));

      expect(send.mock.calls[0][0].input.Key).toBe('uploads/a.jpg');
    });

    it('propagates a failed write rather than reporting success', async () => {
      send.mockRejectedValue(new Error('AccessDenied'));

      // Swallowing this would tell the user their document uploaded and leave
      // the row pointing at an object that does not exist.
      await expect(
        new S3StorageProvider().save('uploads/a.jpg', Buffer.from('x')),
      ).rejects.toThrow('AccessDenied');
    });
  });

  describe('exists', () => {
    beforeEach(() => configure(validR2));

    it('is true when the object is there', async () => {
      send.mockResolvedValue({ ContentLength: 12 });

      await expect(
        new S3StorageProvider().exists('uploads/a.jpg'),
      ).resolves.toBe(true);
    });

    it('is false on a 404', async () => {
      send.mockRejectedValue({ $metadata: { httpStatusCode: 404 } });

      await expect(
        new S3StorageProvider().exists('uploads/missing.jpg'),
      ).resolves.toBe(false);
    });

    it('is false on a NotFound error name', async () => {
      // The SDK reports a missing object either way depending on version.
      send.mockRejectedValue({ name: 'NotFound' });

      await expect(
        new S3StorageProvider().exists('uploads/missing.jpg'),
      ).resolves.toBe(false);
    });

    it('rethrows a 403 instead of calling it missing', async () => {
      send.mockRejectedValue({ $metadata: { httpStatusCode: 403 } });

      // This distinction matters: `resolveUpload` turns a false into "file not
      // found". Misreading broken credentials as "missing" would present a
      // total outage as thousands of individually-deleted files.
      await expect(
        new S3StorageProvider().exists('uploads/a.jpg'),
      ).rejects.toBeDefined();
    });
  });

  describe('localPath', () => {
    it('is always null, so the controller streams instead of sendFile', () => {
      configure(validR2);
      expect(new S3StorageProvider().localPath()).toBeNull();
    });
  });

  describe('createReadStream', () => {
    beforeEach(() => configure(validR2));

    const collect = (stream: NodeJS.ReadableStream): Promise<Buffer> =>
      new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        stream.on('data', (chunk: Buffer) => chunks.push(chunk));
        stream.on('end', () => resolve(Buffer.concat(chunks)));
        stream.on('error', reject);
      });

    it('pipes a streaming body through', async () => {
      send.mockResolvedValue({ Body: Readable.from([Buffer.from('hello r2')]) });

      const out = new S3StorageProvider().createReadStream('uploads/a.jpg');

      await expect(collect(out)).resolves.toEqual(Buffer.from('hello r2'));
    });

    it('handles a body that only offers transformToByteArray', async () => {
      // Which branch the SDK takes depends on the runtime, so both are pinned;
      // getting this wrong means every download hangs.
      send.mockResolvedValue({
        transformToByteArray: undefined,
        Body: {
          transformToByteArray: () =>
            Promise.resolve(new Uint8Array([104, 105])),
        },
      });

      const out = new S3StorageProvider().createReadStream('uploads/a.jpg');

      await expect(collect(out)).resolves.toEqual(Buffer.from('hi'));
    });

    it('errors the stream when the object cannot be fetched', async () => {
      send.mockRejectedValue(new Error('NoSuchKey'));

      const out = new S3StorageProvider().createReadStream('uploads/gone.jpg');

      await expect(collect(out)).rejects.toThrow('NoSuchKey');
    });

    it('errors rather than hanging on an unreadable body', async () => {
      send.mockResolvedValue({ Body: {} });

      const out = new S3StorageProvider().createReadStream('uploads/a.jpg');

      await expect(collect(out)).rejects.toThrow(/no readable body/i);
    });
  });
});
