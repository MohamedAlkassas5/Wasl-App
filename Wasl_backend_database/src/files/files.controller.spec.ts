import { INestApplication } from '@nestjs/common';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { mkdirSync, rmSync, writeFileSync } from 'fs';
import { join } from 'path';
import * as request from 'supertest';

import { FilesController } from './files.controller';
import { FilesService } from './files.service';
import { STORAGE_PROVIDER } from '../storage/storage-provider';
import { LocalDiskStorageProvider } from '../storage/local-disk-storage.provider';
import { JWT_SECRET } from '../auth/jwt.constants';
import { UserRole } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { Order } from '../orders/entities/order.entity';
import { OrderMessage } from '../orders/entities/order-message.entity';
import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';
import { AccountAccessService } from '../auth/account-access.service';

/**
 * `uploads/` holds national IDs, selfies and payment proofs. These tests pin the
 * rule that made it safe: a token is required, and the token's owner must be the
 * one the document belongs to.
 */
describe('FilesController (uploads access control)', () => {
  const uploadsRoot = join(process.cwd(), 'uploads');
  const idFile = 'idFront-test-spec.jpg';
  const proofFile = 'proof-test-spec.jpg';

  const DRIVER_ID = 7;
  const OTHER_ID = 99;

  let app: INestApplication;
  let jwt: JwtService;

  const tokenFor = (sub: number, role: UserRole) => jwt.sign({ sub, role });

  beforeAll(async () => {
    mkdirSync(join(uploadsRoot, 'payments'), { recursive: true });
    writeFileSync(join(uploadsRoot, idFile), 'fake-id-scan');
    writeFileSync(join(uploadsRoot, 'payments', proofFile), 'fake-proof');

    // Driver #7 owns the ID scan; nobody owns the payment proof.
    const deliveryRepo = {
      findOne: ({ where }: { where: { userId: number } }) =>
        Promise.resolve(
          where.userId === DRIVER_ID
            ? {
                userId: DRIVER_ID,
                nationalIdFront: `uploads/${idFile}`,
                nationalIdBack: 'uploads/pending_back.jpg',
                selfie: 'uploads/pending_selfie.jpg',
                vehicleImage: 'uploads/pending_vehicle.jpg',
              }
            : null,
        ),
    };
    const emptyRepo = { findOne: () => Promise.resolve(null) };

    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [JwtModule.register({ secret: JWT_SECRET })],
      controllers: [FilesController],
      providers: [
        FilesService,
        { provide: STORAGE_PROVIDER, useClass: LocalDiskStorageProvider },
        {
          provide: getRepositoryToken(DeliveryPartner),
          useValue: deliveryRepo,
        },
        { provide: getRepositoryToken(Merchant), useValue: emptyRepo },
        { provide: getRepositoryToken(Order), useValue: emptyRepo },
        {
          provide: getRepositoryToken(WalletTopUpRequest),
          useValue: emptyRepo,
        },
        { provide: getRepositoryToken(OrderMessage), useValue: emptyRepo },
        // These tests exercise the guard for real, so the account lookup has to
        // answer: every account here is live.
        {
          provide: AccountAccessService,
          useValue: { isClosed: () => Promise.resolve(false) },
        },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    jwt = moduleRef.get(JwtService);
    await app.init();
  });

  afterAll(async () => {
    rmSync(join(uploadsRoot, idFile), { force: true });
    rmSync(join(uploadsRoot, 'payments', proofFile), { force: true });
    await app.close();
  });

  it('refuses an anonymous request (this used to be public static hosting)', async () => {
    await request(app.getHttpServer()).get(`/uploads/${idFile}`).expect(401);
  });

  it('refuses a logged-in user who does not own the document', async () => {
    await request(app.getHttpServer())
      .get(`/uploads/${idFile}`)
      .set('Authorization', `Bearer ${tokenFor(OTHER_ID, UserRole.DELIVERY)}`)
      .expect(403);
  });

  it('serves the document to the partner it belongs to', async () => {
    const res = await request(app.getHttpServer())
      .get(`/uploads/${idFile}`)
      .set('Authorization', `Bearer ${tokenFor(DRIVER_ID, UserRole.DELIVERY)}`)
      .buffer(true)
      .expect(200);

    // Served as image/jpeg, so supertest hands back a Buffer rather than text.
    expect(Buffer.from(res.body as Buffer).toString()).toBe('fake-id-scan');
    expect(res.headers['cache-control']).toBe('private, no-store');
  });

  it('serves any document to an admin, since approvals require review', async () => {
    await request(app.getHttpServer())
      .get(`/uploads/payments/${proofFile}`)
      .set('Authorization', `Bearer ${tokenFor(OTHER_ID, UserRole.ADMIN)}`)
      .expect(200);
  });

  it('rejects an unreferenced payment proof for a non-admin', async () => {
    await request(app.getHttpServer())
      .get(`/uploads/payments/${proofFile}`)
      .set('Authorization', `Bearer ${tokenFor(DRIVER_ID, UserRole.DELIVERY)}`)
      .expect(403);
  });

  it('rejects folders it does not own', async () => {
    await request(app.getHttpServer())
      .get('/uploads/secrets/anything.jpg')
      .set('Authorization', `Bearer ${tokenFor(DRIVER_ID, UserRole.ADMIN)}`)
      .expect(404);
  });

  it('rejects path traversal in the filename', async () => {
    await request(app.getHttpServer())
      .get('/uploads/..%2F..%2Fpackage.json')
      .set('Authorization', `Bearer ${tokenFor(DRIVER_ID, UserRole.ADMIN)}`)
      .expect(400);
  });
});
