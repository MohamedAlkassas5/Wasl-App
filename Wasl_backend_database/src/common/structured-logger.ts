import { ConsoleLogger, LogLevel } from '@nestjs/common';

import { currentRequestId } from './request-context';

/**
 * Log format. JSON in production, the familiar coloured Nest output in dev.
 *
 * `LOG_FORMAT` overrides both ways, so a developer can reproduce production
 * log output locally without pretending to be production everywhere else.
 */
function resolveFormat(): 'json' | 'pretty' {
  const configured = process.env.LOG_FORMAT?.trim().toLowerCase();
  if (configured === 'json' || configured === 'pretty') return configured;
  return process.env.NODE_ENV === 'production' ? 'json' : 'pretty';
}

/**
 * The application logger.
 *
 * Extends Nest's own `ConsoleLogger` rather than replacing it, which is what
 * lets this be adopted without touching the ten services that already do
 * `new Logger(SomeService.name)` — they keep calling the same methods, and the
 * output format changes underneath them.
 *
 * In production every line is one JSON object on one line, because that is what
 * a log aggregator can actually query. The field that matters is `requestId`:
 * without it, a production log is a stream of unrelated sentences, and the way
 * you answer "what happened to this user's order" is by guessing at timestamps.
 *
 * Pretty mode is unchanged from stock Nest, so local development looks exactly
 * as it did before this checkpoint.
 */
export class StructuredLogger extends ConsoleLogger {
  private readonly format = resolveFormat();

  protected printMessages(
    messages: unknown[],
    context = '',
    logLevel: LogLevel = 'log',
    writeStreamType?: 'stdout' | 'stderr',
  ): void {
    if (this.format !== 'json') {
      super.printMessages(messages, context, logLevel, writeStreamType);
      return;
    }

    for (const message of messages) {
      const line = JSON.stringify({
        level: logLevel,
        time: new Date().toISOString(),
        context: context || undefined,
        requestId: currentRequestId(),
        message: render(message),
      });

      // Warnings and errors go to stderr so a platform that separates the two
      // streams (Render does) keeps flagging them as problems.
      const stream =
        writeStreamType ??
        (logLevel === 'error' || logLevel === 'warn' ? 'stderr' : 'stdout');
      process[stream].write(`${line}\n`);
    }
  }

  /** Stack traces are their own line so they are not lost inside the message. */
  protected printStackTrace(stack: string): void {
    if (this.format !== 'json') {
      super.printStackTrace(stack);
      return;
    }
    if (!stack) return;

    process.stderr.write(
      `${JSON.stringify({
        level: 'error',
        time: new Date().toISOString(),
        requestId: currentRequestId(),
        stack,
      })}\n`,
    );
  }
}

/**
 * Anything can be handed to a logger. Objects are kept as objects so they stay
 * queryable rather than becoming "[object Object]", and an unserialisable value
 * (a circular structure, most often) degrades to its string form instead of
 * throwing — a logger that can crash the request it is describing is worse than
 * one that logs badly.
 */
function render(message: unknown): unknown {
  if (typeof message === 'string') return message;
  if (message instanceof Error) {
    return { name: message.name, message: message.message };
  }
  try {
    JSON.stringify(message);
    return message;
  } catch {
    return String(message);
  }
}
