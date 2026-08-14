import * as Sentry from '@sentry/node';

import {
  initSentry,
  isSentryEnabled,
  reportError,
  resetSentryForTesting,
} from './sentry';

/**
 * The property that matters most here is the disabled one.
 *
 * Every local checkout, every test run and CI has no DSN, and in that state
 * this module must be completely inert — no init, no capture, no network call.
 * A monitoring integration that quietly phones home from a developer's laptop
 * is worse than no monitoring at all.
 */
describe('Sentry integration', () => {
  const originalDsn = process.env.SENTRY_DSN;
  let init: jest.SpyInstance;
  let capture: jest.SpyInstance;

  beforeEach(() => {
    resetSentryForTesting();
    init = jest.spyOn(Sentry, 'init').mockImplementation(() => undefined);
    capture = jest
      .spyOn(Sentry, 'captureException')
      .mockImplementation(() => 'event-id');
  });

  afterEach(() => {
    jest.restoreAllMocks();
    if (originalDsn === undefined) delete process.env.SENTRY_DSN;
    else process.env.SENTRY_DSN = originalDsn;
    resetSentryForTesting();
  });

  describe('with no DSN configured', () => {
    beforeEach(() => {
      delete process.env.SENTRY_DSN;
    });

    it('does not initialise', () => {
      expect(initSentry()).toBe(false);
      expect(init).not.toHaveBeenCalled();
    });

    it('reports itself as disabled', () => {
      initSentry();
      expect(isSentryEnabled()).toBe(false);
    });

    it('swallows reports rather than sending them', () => {
      initSentry();
      reportError(new Error('boom'));

      expect(capture).not.toHaveBeenCalled();
    });

    it('treats a blank DSN as unset', () => {
      process.env.SENTRY_DSN = '   ';
      expect(initSentry()).toBe(false);
    });
  });

  describe('with a DSN configured', () => {
    beforeEach(() => {
      process.env.SENTRY_DSN = 'https://key@example.ingest.sentry.io/1';
    });

    it('initialises once', () => {
      expect(initSentry()).toBe(true);
      expect(init).toHaveBeenCalledTimes(1);
    });

    it('leaves performance tracing off, so the quota is spent on errors', () => {
      initSentry();
      expect(init.mock.calls[0][0]).toMatchObject({ tracesSampleRate: 0 });
    });

    it('sends an error through', () => {
      initSentry();
      const error = new Error('connection terminated');
      reportError(error);

      expect(capture).toHaveBeenCalledWith(error);
    });

    it('never lets a reporting failure become a second error', () => {
      initSentry();
      capture.mockImplementation(() => {
        throw new Error('sentry is down');
      });

      // The caller is already handling an error; throwing here would replace a
      // useful 500 with an unhandled rejection.
      expect(() => reportError(new Error('original'))).not.toThrow();
    });
  });
});
