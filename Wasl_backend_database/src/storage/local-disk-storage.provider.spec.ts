import { BadRequestException } from '@nestjs/common';
import { existsSync, readFileSync, rmSync } from 'fs';
import { join, resolve } from 'path';

import { LocalDiskStorageProvider } from './local-disk-storage.provider';

/**
 * The local backend is behaviour-preserving for the app, but it also owns the
 * path-traversal guard now that callers pass it raw keys. These tests pin the
 * round-trip and that a key can't escape the uploads root.
 */
describe('LocalDiskStorageProvider', () => {
  const provider = new LocalDiskStorageProvider();
  const root = resolve(process.cwd(), 'uploads');
  const key = 'uploads/storage-spec-test.txt';
  const abs = join(root, 'storage-spec-test.txt');

  afterEach(() => rmSync(abs, { force: true }));

  it('saves, confirms existence, and reads the bytes back', async () => {
    await provider.save(key, Buffer.from('hello wasl'));

    expect(existsSync(abs)).toBe(true);
    expect(readFileSync(abs, 'utf8')).toBe('hello wasl');
    await expect(provider.exists(key)).resolves.toBe(true);

    const chunks: Buffer[] = [];
    for await (const c of provider.createReadStream(key)) {
      chunks.push(c as Buffer);
    }
    expect(Buffer.concat(chunks).toString()).toBe('hello wasl');
  });

  it('reports a missing key as not existing', async () => {
    await expect(provider.exists('uploads/does-not-exist.txt')).resolves.toBe(
      false,
    );
  });

  it('resolves a normal key to a path inside the uploads root', () => {
    expect(provider.localPath(key)).toBe(abs);
  });

  it('refuses a key that escapes the uploads root', () => {
    expect(() => provider.localPath('uploads/../../package.json')).toThrow(
      BadRequestException,
    );
  });
});
