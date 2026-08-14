import { StructuredLogger } from './structured-logger';
import { runWithRequestContext } from './request-context';

/**
 * A production log is only useful if a machine can query it and if every line
 * says which request it belongs to. These pin both, and pin that development
 * output is left alone.
 */
describe('StructuredLogger', () => {
  const originalFormat = process.env.LOG_FORMAT;
  let stdout: string[];
  let stderr: string[];
  let writeOut: jest.SpyInstance;
  let writeErr: jest.SpyInstance;

  beforeEach(() => {
    stdout = [];
    stderr = [];
    writeOut = jest
      .spyOn(process.stdout, 'write')
      .mockImplementation((chunk: unknown) => {
        stdout.push(String(chunk));
        return true;
      });
    writeErr = jest
      .spyOn(process.stderr, 'write')
      .mockImplementation((chunk: unknown) => {
        stderr.push(String(chunk));
        return true;
      });
  });

  afterEach(() => {
    writeOut.mockRestore();
    writeErr.mockRestore();
    process.env.LOG_FORMAT = originalFormat;
  });

  const jsonLogger = () => {
    process.env.LOG_FORMAT = 'json';
    return new StructuredLogger();
  };

  const parsed = (lines: string[]) => lines.map((line) => JSON.parse(line));

  it('writes one JSON object per line', () => {
    jsonLogger().log('order created', 'OrdersService');

    expect(stdout).toHaveLength(1);
    expect(stdout[0].endsWith('\n')).toBe(true);
    expect(() => JSON.parse(stdout[0])).not.toThrow();
  });

  it('records level, context and message', () => {
    jsonLogger().log('order created', 'OrdersService');

    expect(parsed(stdout)[0]).toMatchObject({
      level: 'log',
      context: 'OrdersService',
      message: 'order created',
    });
  });

  it('carries the request id — the reason this exists', () => {
    const logger = jsonLogger();
    runWithRequestContext({ requestId: 'req-42' }, () =>
      logger.log('charging the wallet', 'WalletService'),
    );

    expect(parsed(stdout)[0].requestId).toBe('req-42');
  });

  it('omits the request id outside a request rather than inventing one', () => {
    jsonLogger().log('seeding admin', 'AdminSeeder');

    expect(parsed(stdout)[0].requestId).toBeUndefined();
  });

  it('sends warnings and errors to stderr', () => {
    const logger = jsonLogger();
    logger.warn('slow query', 'Db');
    logger.error('boom', undefined, 'Db');

    expect(stdout).toHaveLength(0);
    expect(parsed(stderr).map((line) => line.level)).toEqual(['warn', 'error']);
  });

  it('keeps an object queryable instead of stringifying it', () => {
    jsonLogger().log({ orderId: 7, state: 'delivered' }, 'OrdersService');

    expect(parsed(stdout)[0].message).toEqual({
      orderId: 7,
      state: 'delivered',
    });
  });

  it('survives a value that cannot be serialised', () => {
    const circular: Record<string, unknown> = {};
    circular.self = circular;

    // A logger that throws would take down the request it was describing.
    expect(() => jsonLogger().log(circular, 'Odd')).not.toThrow();
    expect(stdout).toHaveLength(1);
  });

  it('leaves development output in the human-readable format', () => {
    process.env.LOG_FORMAT = 'pretty';
    new StructuredLogger().log('hello', 'Dev');

    // Nest's own renderer, not ours — so it must not parse as our JSON shape.
    expect(stdout.join('')).toContain('hello');
    expect(() => JSON.parse(stdout[0])).toThrow();
  });
});
