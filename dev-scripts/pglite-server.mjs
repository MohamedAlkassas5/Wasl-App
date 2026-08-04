// Local Postgres for development, over the real wire protocol, without needing
// Docker. The NestJS backend connects to it unmodified on 127.0.0.1:5432.
// Data persists in ./pgdata next to this file.
import { PGlite } from '@electric-sql/pglite';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const here = dirname(fileURLToPath(import.meta.url));
const db = await PGlite.create({ dataDir: join(here, 'pgdata') });
const server = new PGLiteSocketServer({ db, port: 5432, host: '127.0.0.1' });
await server.start();
console.log('PGlite database is up on 127.0.0.1:5432');

process.on('SIGINT', async () => {
  await server.stop();
  await db.close();
  process.exit(0);
});
