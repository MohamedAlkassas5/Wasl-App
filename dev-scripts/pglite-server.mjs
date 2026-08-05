// Local Postgres for development, over the real wire protocol, without Docker.
// The NestJS backend connects to it unmodified on 127.0.0.1:5432.
//
// Runs IN MEMORY on purpose: PGlite's on-disk persistence proved fragile on
// this machine (files under the data dir would go missing mid-session, giving
// "could not open file base/..." and 500s). In memory there are no files to
// corrupt. The tradeoff is that data resets when this stops — which is why
// `2-seed-data` repopulates the test accounts and restaurants after startup.
import { PGlite } from '@electric-sql/pglite';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';

const db = await PGlite.create(); // no dataDir => in-memory
const server = new PGLiteSocketServer({ db, port: 5432, host: '127.0.0.1' });
await server.start();
console.log('PGlite (in-memory) is up on 127.0.0.1:5432');

process.on('SIGINT', async () => {
  await server.stop();
  await db.close();
  process.exit(0);
});
