import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Order } from './entities/order.entity';
import { OrderItem } from './entities/order-item.entity';
import { OrderCancellationRequest } from './entities/order-cancellation-request.entity';
import { WalletTransaction } from '../payments/entities/wallet-transaction.entity';

export interface AdminOrderQuery {
  limit?: number;
  offset?: number;
}

/** Same bounds as the audit log: an unbounded dump is its own outage. */
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

/**
 * Reading orders as an admin.
 *
 * Part 3 lists "order inspection" as an admin MUST-HAVE, and the job it has to
 * do is answering a complaint: what was this order, who took it, what was
 * charged, and was any of it cancelled. So the detail view joins the money and
 * the cancellation record rather than making an admin open three screens and
 * correlate ids by eye.
 *
 * Read-only on purpose — see the controller.
 */
@Injectable()
export class AdminOrdersService {
  constructor(
    @InjectRepository(Order)
    private readonly orders: Repository<Order>,
    @InjectRepository(OrderItem)
    private readonly items: Repository<OrderItem>,
    @InjectRepository(OrderCancellationRequest)
    private readonly cancellations: Repository<OrderCancellationRequest>,
    @InjectRepository(WalletTransaction)
    private readonly ledger: Repository<WalletTransaction>,
  ) {}

  /** Newest first, bounded. */
  async list(query: AdminOrderQuery = {}) {
    // A nonsense limit falls back to the default rather than being clamped —
    // the same reasoning as the audit log, and kept identical so the two admin
    // lists cannot drift into behaving differently on the same bad input.
    const wantLimit = Math.floor(Number(query.limit));
    const take =
      Number.isFinite(wantLimit) && wantLimit > 0
        ? Math.min(wantLimit, MAX_LIMIT)
        : DEFAULT_LIMIT;

    const wantOffset = Math.floor(Number(query.offset));
    const skip = Number.isFinite(wantOffset) && wantOffset > 0 ? wantOffset : 0;

    const [orders, total] = await this.orders.findAndCount({
      order: { createdAt: 'DESC', id: 'DESC' },
      take,
      skip,
    });

    return { total, limit: take, offset: skip, orders };
  }

  /**
   * One order, with what an admin needs to judge it.
   *
   * The ledger is keyed on the order rather than recomputed: what the driver
   * was actually charged is whatever `wallet_transactions` says, and a figure
   * derived a second way here could disagree with the money.
   */
  async detail(id: number) {
    const order = await this.orders.findOne({ where: { id } });
    if (!order) throw new NotFoundException('الطلب غير موجود');

    const [items, cancellations, transactions] = await Promise.all([
      this.items.find({ where: { orderId: id }, order: { id: 'ASC' } }),
      this.cancellations.find({ where: { orderId: id }, order: { id: 'ASC' } }),
      this.ledger.find({ where: { orderId: id }, order: { id: 'ASC' } }),
    ]);

    return { success: true, order, items, cancellations, transactions };
  }
}
