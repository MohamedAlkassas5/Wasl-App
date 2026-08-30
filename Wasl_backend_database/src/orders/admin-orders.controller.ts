import { Controller, Get, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';
import { AdminOrdersService } from './admin-orders.service';

/**
 * Order inspection for the admin panel — Part 12's `GET /admin/orders`.
 *
 * Read-only, deliberately. Every way an order can change already has its own
 * route with its own rules: completion settles a wallet, cancellation charges
 * a penalty, a refund goes through the appeal queue. Adding a general-purpose
 * admin write here would be a second door into money-moving state that skips
 * all of them.
 *
 * Pagination is `limit`/`offset` and nothing else, matching the audit log. No
 * status, driver or date filters: the Master Plan lists this endpoint without
 * them, and every filter is a query shape that has to stay correct for ever.
 */
@Controller('admin/orders')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminOrdersController {
  constructor(private readonly adminOrders: AdminOrdersService) {}

  /** Newest first, so the page an admin lands on is the one they need. */
  @Get()
  list(@Query('limit') limit?: string, @Query('offset') offset?: string) {
    return this.adminOrders.list({
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  /** One order in full, for inspecting a complaint. */
  @Get(':id')
  detail(@Param('id', ParseIntPipe) id: number) {
    return this.adminOrders.detail(id);
  }
}
