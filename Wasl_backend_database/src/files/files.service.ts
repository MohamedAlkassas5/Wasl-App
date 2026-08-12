import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Readable } from 'stream';

import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { Order, OrderStatus } from '../orders/entities/order.entity';
import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';
import { STORAGE_PROVIDER, StorageProvider } from '../storage/storage-provider';

/** Sub-folders under `uploads/` that the app actually writes to. */
const ALLOWED_FOLDERS = ['orders', 'invoices', 'payments'];

/** Multer names files itself, so anything outside this charset is an attack. */
const SAFE_NAME = /^[A-Za-z0-9._-]+$/;

/** How a resolved upload should be sent to the client. */
export type ServePlan =
  { kind: 'local'; localPath: string } | { kind: 'stream'; stream: Readable };

@Injectable()
export class FilesService {
  constructor(
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,
    @InjectRepository(Merchant)
    private readonly merchantRepository: Repository<Merchant>,
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(WalletTopUpRequest)
    private readonly topUpRepository: Repository<WalletTopUpRequest>,
    @Inject(STORAGE_PROVIDER)
    private readonly storage: StorageProvider,
  ) {}

  /**
   * Turn the URL segments into the exact relative path stored in the database
   * (`uploads/foo.jpg`, `uploads/orders/bar.jpg`). Validates the charset and
   * folder, and confirms the object actually exists via the storage backend.
   * Path-traversal safety is enforced by the backend when it resolves the key.
   */
  async resolveUpload(filename: string, folder?: string) {
    if (!SAFE_NAME.test(filename)) {
      throw new BadRequestException('اسم الملف غير صالح');
    }
    if (folder !== undefined && !ALLOWED_FOLDERS.includes(folder)) {
      throw new NotFoundException('الملف غير موجود');
    }

    const relativePath = folder
      ? `uploads/${folder}/${filename}`
      : `uploads/${filename}`;

    if (!(await this.storage.exists(relativePath))) {
      throw new NotFoundException('الملف غير موجود');
    }

    return { relativePath };
  }

  /**
   * How to serve a resolved file: a local filesystem path (so the controller
   * can `res.sendFile` with correct Content-Type and range support) or a
   * readable stream (remote backends that have no local file).
   */
  servePlan(relativePath: string): ServePlan {
    const localPath = this.storage.localPath(relativePath);
    return localPath
      ? { kind: 'local', localPath }
      : { kind: 'stream', stream: this.storage.createReadStream(relativePath) };
  }

  /**
   * Who may read a given upload. Files are matched by the path stored on the
   * owning row, so a file nobody references is readable by nobody but an admin.
   */
  async canRead(user: AuthUser, relativePath: string): Promise<boolean> {
    // Admins review IDs and payment proofs — that is the job.
    if (user.role === UserRole.ADMIN) return true;

    // 🪪 Registration documents: only the partner who uploaded them.
    const partner = await this.deliveryRepository.findOne({
      where: { userId: user.sub },
    });
    if (
      partner &&
      [
        partner.nationalIdFront,
        partner.nationalIdBack,
        partner.selfie,
        partner.vehicleImage,
      ].includes(relativePath)
    ) {
      return true;
    }

    const merchant = await this.merchantRepository.findOne({
      where: { ownerId: user.sub },
    });
    if (
      merchant &&
      (merchant.logo === relativePath || merchant.coverImage === relativePath)
    ) {
      return true;
    }

    // 📦 Item photo on an order: the customer, the assigned driver, and — while
    // the order is still taking offers — any driver, since they need to see what
    // is being requested before pricing it.
    const itemsOrder = await this.orderRepository.findOne({
      where: { itemsImageUrl: relativePath },
    });
    if (itemsOrder) {
      if (itemsOrder.customerId === user.sub) return true;
      if (itemsOrder.acceptedDriverId === user.sub) return true;
      if (
        user.role === UserRole.DELIVERY &&
        itemsOrder.status === OrderStatus.PENDING_OFFERS
      ) {
        return true;
      }
    }

    // 🧾 Purchase receipt: strictly the two parties to that order.
    const invoiceOrder = await this.orderRepository.findOne({
      where: { invoiceImageUrl: relativePath },
    });
    if (
      invoiceOrder &&
      (invoiceOrder.customerId === user.sub ||
        invoiceOrder.acceptedDriverId === user.sub)
    ) {
      return true;
    }

    // 💳 Top-up proof (contains wallet/transfer details): only its author.
    const topUp = await this.topUpRepository.findOne({
      where: { proofImageUrl: relativePath },
    });
    if (topUp && topUp.driverId === user.sub) return true;

    return false;
  }
}
