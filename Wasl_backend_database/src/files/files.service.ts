import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { existsSync } from 'fs';
import { join, resolve, sep } from 'path';

import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { Order, OrderStatus } from '../orders/entities/order.entity';
import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';

/** Sub-folders under `uploads/` that the app actually writes to. */
const ALLOWED_FOLDERS = ['orders', 'invoices', 'payments'];

/** Multer names files itself, so anything outside this charset is an attack. */
const SAFE_NAME = /^[A-Za-z0-9._-]+$/;

@Injectable()
export class FilesService {
  /** Absolute path of the uploads root — everything served must live inside it. */
  private readonly root = resolve(process.cwd(), 'uploads');

  constructor(
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,
    @InjectRepository(Merchant)
    private readonly merchantRepository: Repository<Merchant>,
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    @InjectRepository(WalletTopUpRequest)
    private readonly topUpRepository: Repository<WalletTopUpRequest>,
  ) {}

  /**
   * Turn the URL segments into the exact relative path stored in the database
   * (`uploads/foo.jpg`, `uploads/orders/bar.jpg`) and the absolute path on disk.
   * Rejects anything that escapes the uploads root.
   */
  resolveUpload(filename: string, folder?: string) {
    if (!SAFE_NAME.test(filename)) {
      throw new BadRequestException('اسم الملف غير صالح');
    }
    if (folder !== undefined && !ALLOWED_FOLDERS.includes(folder)) {
      throw new NotFoundException('الملف غير موجود');
    }

    const relativePath = folder
      ? `uploads/${folder}/${filename}`
      : `uploads/${filename}`;
    const absolutePath = folder
      ? join(this.root, folder, filename)
      : join(this.root, filename);

    // Belt and braces: even with the charset check, never serve outside the root.
    if (
      !resolve(absolutePath).startsWith(this.root + sep) &&
      resolve(absolutePath) !== this.root
    ) {
      throw new BadRequestException('مسار الملف غير صالح');
    }
    if (!existsSync(absolutePath)) {
      throw new NotFoundException('الملف غير موجود');
    }

    return { relativePath, absolutePath };
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
