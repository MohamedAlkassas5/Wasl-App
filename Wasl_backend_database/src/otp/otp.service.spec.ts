import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';

import { OtpService } from './otp.service';
import { OtpVerification } from './entities/otp-verification.entity';
import { OTP_PROVIDER, OtpProvider } from './otp-provider.interface';

/**
 * A successful OTP is the *only* server-side proof that a caller owns a phone
 * number — registration and password reset both stand on it. These tests pin
 * the properties that make it worth standing on: the code is never accepted
 * twice past its window, and a spent verification is gone.
 */
describe('OtpService (proof of phone ownership)', () => {
  const PHONE = '201001234567';
  const THIRTY_ONE_MINUTES = 31 * 60 * 1000;

  let service: OtpService;
  let stored: OtpVerification | null;
  let deliveredCode: string;

  // Single-row in-memory stand-in for the otp_verifications table.
  const repository = {
    findOne: ({ where }: { where: { phone: string } }) =>
      Promise.resolve(stored?.phone === where.phone ? stored : null),
    create: (data: Partial<OtpVerification>) => ({ ...data }) as OtpVerification,
    save: (record: OtpVerification) => {
      stored = record;
      return Promise.resolve(record);
    },
    delete: ({ phone }: { phone: string }) => {
      if (stored?.phone === phone) stored = null;
      return Promise.resolve({ affected: 1 });
    },
  };

  const provider: OtpProvider = {
    name: 'test-provider',
    sendOtp: (_phone: string, code: string) => {
      deliveredCode = code;
      return Promise.resolve();
    },
  };

  beforeEach(async () => {
    stored = null;
    deliveredCode = '';

    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        OtpService,
        { provide: getRepositoryToken(OtpVerification), useValue: repository },
        { provide: OTP_PROVIDER, useValue: provider },
      ],
    }).compile();

    service = moduleRef.get(OtpService);
  });

  /** Send a code and hand back whatever the provider was asked to deliver. */
  const issueCode = async (): Promise<string> => {
    await service.sendOtp(PHONE);
    return deliveredCode;
  };

  it('accepts the delivered code and marks the phone verified', async () => {
    const code = await issueCode();

    await expect(service.verifyOtp(PHONE, code)).resolves.toBe(true);
    await expect(service.isPhoneVerified(PHONE)).resolves.toBe(true);
  });

  it('rejects a wrong code without verifying the phone', async () => {
    const code = await issueCode();
    const wrong = code === '000000' ? '111111' : '000000';

    await expect(service.verifyOtp(PHONE, wrong)).resolves.toBe(false);
    await expect(service.isPhoneVerified(PHONE)).resolves.toBe(false);
  });

  it('ignores separators, so +20 100 123 4567 is the same number', async () => {
    const code = await issueCode();

    await expect(service.verifyOtp('+20 100 123 4567', code)).resolves.toBe(
      true,
    );
  });

  it('stops honouring a verification once its window has passed', async () => {
    const code = await issueCode();
    await service.verifyOtp(PHONE, code);

    // Backdate the verification past the 30-minute window.
    stored!.verifiedAt = new Date(Date.now() - THIRTY_ONE_MINUTES);

    await expect(service.isPhoneVerified(PHONE)).resolves.toBe(false);
    // Re-submitting the same code must not resurrect it either.
    await expect(service.verifyOtp(PHONE, code)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('forgets the verification once it has been consumed', async () => {
    const code = await issueCode();
    await service.verifyOtp(PHONE, code);

    await service.consumeVerification(PHONE);

    await expect(service.isPhoneVerified(PHONE)).resolves.toBe(false);
  });

  it('clears a previous verification when a new code is sent', async () => {
    const first = await issueCode();
    await service.verifyOtp(PHONE, first);

    // Resend is rate-limited by wall clock; step around the cooldown.
    stored!.lastSentAt = new Date(Date.now() - 2 * 60 * 1000);
    await issueCode();

    await expect(service.isPhoneVerified(PHONE)).resolves.toBe(false);
    await expect(service.verifyOtp(PHONE, first)).resolves.toBe(false);
  });

  it('refuses to verify a phone that never requested a code', async () => {
    await expect(service.verifyOtp(PHONE, '123456')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });
});
