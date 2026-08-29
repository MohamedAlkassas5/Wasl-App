import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { AdminAuditLog } from './entities/admin-audit-log.entity';

/**
 * Keys whose values never belong in an audit log.
 *
 * Matched case-insensitively against the *key*, as a substring, so
 * `newPassword`, `password_confirmation` and `PASSWORD` are all caught without
 * enumerating every spelling. Part 14 of the plan is explicit about the set:
 * never log OTPs, JWTs, passwords or document paths.
 *
 * Document paths are in here because they are capability URLs in practice —
 * `GET /uploads/:filename` authorizes by ownership, but a national-ID path
 * sitting in a log read by support staff widens who can go looking.
 */
const REDACTED_KEYS = [
  'password',
  'token',
  'secret',
  'otp',
  'code',
  'authorization',
  'apikey',
  'api_key',
  'credential',
  // document paths
  'image',
  'selfie',
  'nationalid',
  'national_id',
  'proof',
  'logo',
  'photo',
  'document',
];

const REDACTED = '[redacted]';

/** Depth cap: a hostile or accidental deep object should not be walked forever. */
const MAX_DEPTH = 6;

function isRedactedKey(key: string): boolean {
  const k = key.toLowerCase();
  return REDACTED_KEYS.some((needle) => k.includes(needle));
}

/**
 * Copies a request payload with sensitive values replaced.
 *
 * Redacts on the key, not the value: a value-based rule ("does this look like
 * a JWT") fails open on anything it has not seen, and failing open is the
 * wrong direction for this. Unknown keys are kept — an audit entry with no
 * detail is not much of an audit entry — so the key list is what must stay
 * current as DTOs grow.
 */
export function redactAuditPayload(
  input: unknown,
  depth = 0,
): Record<string, unknown> | null {
  if (input == null || typeof input !== 'object') return null;
  if (depth > MAX_DEPTH) return { truncated: true };

  const out: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(input as Record<string, unknown>)) {
    if (isRedactedKey(key)) {
      out[key] = REDACTED;
      continue;
    }

    if (Array.isArray(value)) {
      out[key] = value.map((item) =>
        item != null && typeof item === 'object'
          ? redactAuditPayload(item, depth + 1)
          : item,
      );
      continue;
    }

    if (value != null && typeof value === 'object') {
      out[key] = redactAuditPayload(value, depth + 1);
      continue;
    }

    out[key] = value;
  }

  return out;
}

export interface AuditEntry {
  adminId: number;
  action: string;
  targetType: string;
  targetId: string | number;
  /** Raw request detail; redacted here, never by the caller. */
  payload?: unknown;
}

/**
 * Paging only.
 *
 * There is deliberately no filtering by action, target or actor: the Master
 * Plan's contract is `GET /admin/audit-log` and nothing more, and query
 * parameters are API surface that has to be supported once it exists. The
 * bound below is not a feature — it is what stops a growing table being
 * returned whole.
 */
export interface AuditQuery {
  limit?: number;
  offset?: number;
}

/** Bounds on the read endpoint — an unbounded log dump is its own outage. */
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

@Injectable()
export class AdminAuditLogService {
  private readonly logger = new Logger(AdminAuditLogService.name);

  constructor(
    @InjectRepository(AdminAuditLog)
    private readonly repo: Repository<AdminAuditLog>,
  ) {}

  /**
   * Writes one entry. **Never throws.**
   *
   * The action being audited has already happened — the wallet was credited,
   * the partner approved — and a failure to write the note about it must not
   * turn a completed operation into a 500 the admin will retry. Retrying a
   * credit because the *log* failed is a much worse outcome than a missing log
   * line, so this swallows and reports instead.
   *
   * That trade is only acceptable because the log is evidence, not a control:
   * nothing authorizes off it.
   */
  async record(entry: AuditEntry): Promise<void> {
    try {
      const row = new AdminAuditLog();
      row.adminId = entry.adminId;
      row.action = entry.action;
      row.targetType = entry.targetType;
      row.targetId = String(entry.targetId);
      // Built field by field rather than as an object literal: TypeORM's
      // DeepPartial typing cannot express a free-form jsonb column, and
      // casting it away would hide real mistakes in the fields around it.
      row.payload = redactAuditPayload(entry.payload);

      await this.repo.save(row);
    } catch (error) {
      this.logger.error(
        `Failed to write audit entry ${entry.action} on ${entry.targetType}#${String(entry.targetId)}`,
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  /** Newest first, bounded. */
  async list(query: AuditQuery = {}) {
    // A nonsense limit falls back to the default rather than being clamped:
    // clamping `?limit=-5` to 1 would silently answer a malformed request with
    // a single row, which reads as "there is almost nothing here".
    const wantLimit = Math.floor(Number(query.limit));
    const take =
      Number.isFinite(wantLimit) && wantLimit > 0
        ? Math.min(wantLimit, MAX_LIMIT)
        : DEFAULT_LIMIT;

    const wantOffset = Math.floor(Number(query.offset));
    const skip =
      Number.isFinite(wantOffset) && wantOffset > 0 ? wantOffset : 0;

    const [entries, total] = await this.repo.findAndCount({
      order: { createdAt: 'DESC', id: 'DESC' },
      take,
      skip,
    });

    return { total, limit: take, offset: skip, entries };
  }
}
