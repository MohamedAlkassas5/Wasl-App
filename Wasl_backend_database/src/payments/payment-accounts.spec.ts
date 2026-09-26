import { SettingsService, SettingKey } from '../settings/settings.service';
import { PaymentsService } from './payments.service';
import { AppSetting } from '../settings/entities/app-setting.entity';

/**
 * The destination accounts a driver actually transfers money to.
 *
 * These are the only numbers in the product that cost a driver real money if
 * they are wrong: a typo here sends a top-up to a stranger's wallet, and the
 * driver's proof screenshot will show a payment nobody can match. So they are
 * pinned, and they are pinned at the two places they can go wrong —
 *
 *   1. the seeded default a fresh deployment starts with, and
 *   2. what `GET /wallet/payment-accounts` hands the app for each method.
 *
 * Note what is deliberately NOT asserted: that a *running* installation shows
 * these. `seedDefaults` only inserts keys that are missing, so an instance
 * seeded earlier keeps whatever it has and an admin changes it from the
 * settings screen. That is the existing architecture, and it is why these
 * values live in `app_settings` rather than in the Flutter screen.
 */

const VODAFONE_CASH = '01032919674';
const INSTAPAY = '01220346717';

/** An in-memory `app_settings` table, enough for seed + cache. */
function fakeSettingRepository(existing: Partial<AppSetting>[] = []) {
  const rows: Partial<AppSetting>[] = [...existing];
  return {
    rows,
    repo: {
      findOne: ({ where }: { where: { key: string } }) =>
        Promise.resolve(rows.find((r) => r.key === where.key) ?? null),
      find: () => Promise.resolve(rows),
      create: (row: Partial<AppSetting>) => ({ ...row }),
      save: (row: Partial<AppSetting>) => {
        const at = rows.findIndex((r) => r.key === row.key);
        if (at >= 0) rows[at] = { ...rows[at], ...row };
        else rows.push({ ...row });
        return Promise.resolve(row);
      },
    },
  };
}

describe('driver top-up destination accounts', () => {
  describe('a fresh deployment seeds the real accounts', () => {
    it('seeds the Vodafone Cash number and the InstaPay handle', async () => {
      const { rows, repo } = fakeSettingRepository();
      const settings = new SettingsService(repo as never);

      await settings.onModuleInit();

      expect(rows.find((r) => r.key === SettingKey.PAY_VODAFONE_NUMBER)).toEqual(
        expect.objectContaining({ value: VODAFONE_CASH }),
      );
      expect(rows.find((r) => r.key === SettingKey.PAY_INSTAPAY_HANDLE)).toEqual(
        expect.objectContaining({ value: INSTAPAY }),
      );
    });

    it('leaves an account an admin has already edited alone', async () => {
      // The seeder must never overwrite a live value — an admin changing the
      // platform's wallet number would otherwise be silently reverted on the
      // next deploy, and top-ups would go to the old number.
      const { rows, repo } = fakeSettingRepository([
        { key: SettingKey.PAY_VODAFONE_NUMBER, value: '01099999999' },
      ]);
      const settings = new SettingsService(repo as never);

      await settings.onModuleInit();

      expect(settings.getString(SettingKey.PAY_VODAFONE_NUMBER)).toBe(
        '01099999999',
      );
      // …while the key that was missing still gets its default.
      expect(settings.getString(SettingKey.PAY_INSTAPAY_HANDLE)).toBe(INSTAPAY);
    });
  });

  describe('what the driver app is told', () => {
    const buildService = async () => {
      const { repo } = fakeSettingRepository();
      const settings = new SettingsService(repo as never);
      await settings.onModuleInit();
      return new PaymentsService(
        {} as never,
        {} as never,
        {} as never,
        settings,
        {} as never,
      );
    };

    it('returns the InstaPay account as 01220346717', async () => {
      const service = await buildService();
      expect(service.getPaymentAccounts().instapay).toBe(INSTAPAY);
    });

    it('returns the Vodafone Cash account as 01032919674', async () => {
      const service = await buildService();
      expect(service.getPaymentAccounts().vodafoneCash).toBe(VODAFONE_CASH);
    });

    it('keeps the two methods distinct — the app picks by method', async () => {
      const service = await buildService();
      const accounts = service.getPaymentAccounts();

      // The screen shows `vodafoneCash` for Vodafone and `instapay` for
      // InstaPay. Returning the same string for both would make that choice
      // meaningless and the bug invisible.
      expect(accounts.vodafoneCash).not.toBe(accounts.instapay);
      expect(accounts.vodafoneCash).toMatch(/^01\d{9}$/);
      expect(accounts.instapay).toMatch(/^01\d{9}$/);
    });

    it('ships the transfer instructions and the amount limits with them', async () => {
      const service = await buildService();
      const accounts = service.getPaymentAccounts();

      expect(accounts.instructions).toContain('صورة التحويل');
      expect(accounts.minAmount).toBe(10);
      expect(accounts.maxAmount).toBe(5000);
    });

    it('exposes nothing but the payment details', async () => {
      const service = await buildService();

      // This response is readable by every signed-in driver. It must not grow
      // into a window onto the rest of `app_settings` — commission rates,
      // pricing tiers and radii have no business here.
      expect(Object.keys(service.getPaymentAccounts()).sort()).toEqual([
        'instapay',
        'instructions',
        'maxAmount',
        'minAmount',
        'vodafoneCash',
      ]);
    });
  });
});
