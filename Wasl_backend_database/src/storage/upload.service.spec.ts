import { BadRequestException } from '@nestjs/common';

import { UploadService } from './upload.service';
import { sniffImageType } from '../common/upload-policy';

/** Real bytes for each format we accept. */
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
const WEBP = Buffer.concat([
  Buffer.from('RIFF', 'ascii'),
  Buffer.from([0x00, 0x00, 0x00, 0x00]),
  Buffer.from('WEBP', 'ascii'),
]);

describe('sniffImageType', () => {
  it('recognises the formats the policy accepts', () => {
    expect(sniffImageType(JPEG)).toBe('image/jpeg');
    expect(sniffImageType(PNG)).toBe('image/png');
    expect(sniffImageType(WEBP)).toBe('image/webp');
  });

  it('rejects content that merely claims to be an image', () => {
    expect(sniffImageType(Buffer.from('<html><script>'))).toBeNull();
    expect(sniffImageType(Buffer.from('%PDF-1.7'))).toBeNull();
    expect(sniffImageType(Buffer.from([]))).toBeNull();
    // RIFF, but a WAV rather than a WebP.
    expect(
      sniffImageType(
        Buffer.concat([
          Buffer.from('RIFF', 'ascii'),
          Buffer.from([0, 0, 0, 0]),
          Buffer.from('WAVE', 'ascii'),
        ]),
      ),
    ).toBeNull();
  });
});

describe('UploadService', () => {
  const build = () => {
    const storage = {
      name: 'fake',
      save: jest.fn().mockResolvedValue(undefined),
      exists: jest.fn(),
      localPath: jest.fn(),
      createReadStream: jest.fn(),
    };
    return { storage, service: new UploadService(storage) };
  };

  const fileOf = (buffer: Buffer, originalname = 'photo.jpg') =>
    ({ buffer, originalname }) as Express.Multer.File;

  it('writes through the storage backend rather than to disk directly', async () => {
    const { service, storage } = build();

    const key = await service.persistImage(fileOf(JPEG), 'chat', 'chat');

    expect(storage.save).toHaveBeenCalledWith(key, JPEG, 'image/jpeg');
    expect(key).toMatch(/^uploads\/chat\/chat-\d+-[0-9a-f]{12}\.jpg$/);
  });

  it('puts root-folder uploads directly under uploads/', async () => {
    const { service } = build();
    const key = await service.persistImage(fileOf(PNG), '', 'idFront');
    expect(key).toMatch(/^uploads\/idFront-\d+-[0-9a-f]{12}\.png$/);
  });

  it('names the file from the verified type, never from what was uploaded', async () => {
    const { service } = build();

    // A PNG announced as .jpg.exe by its original name.
    const key = await service.persistImage(
      fileOf(PNG, 'payload.jpg.exe'),
      'chat',
      'chat',
    );

    expect(key!.endsWith('.png')).toBe(true);
    expect(key).not.toContain('exe');
  });

  it('produces names the file server will accept', async () => {
    const { service } = build();
    const key = await service.persistImage(
      fileOf(WEBP, '../../etc/passwd'),
      'chat',
      'chat',
    );

    // FilesService.SAFE_NAME
    expect(key!.split('/').pop()).toMatch(/^[A-Za-z0-9._-]+$/);
  });

  it('refuses a file whose bytes are not an image, whatever it claimed to be', async () => {
    const { service, storage } = build();

    await expect(
      service.persistImage(fileOf(Buffer.from('<html>')), 'chat', 'chat'),
    ).rejects.toThrow(BadRequestException);
    expect(storage.save).not.toHaveBeenCalled();
  });

  it('returns undefined when nothing was uploaded', async () => {
    const { service, storage } = build();

    await expect(
      service.persistImage(undefined, 'chat', 'chat'),
    ).resolves.toBeUndefined();
    expect(storage.save).not.toHaveBeenCalled();
  });

  it('does not collide when two uploads land in the same millisecond', async () => {
    const { service } = build();
    const now = jest.spyOn(Date, 'now').mockReturnValue(1_700_000_000_000);

    const keys = await Promise.all([
      service.persistImage(fileOf(JPEG), 'chat', 'chat'),
      service.persistImage(fileOf(JPEG), 'chat', 'chat'),
    ]);

    expect(keys[0]).not.toBe(keys[1]);
    now.mockRestore();
  });
});
