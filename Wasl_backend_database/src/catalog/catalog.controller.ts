import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CatalogService } from './catalog.service';
import { AdminAuditLogService } from '../admin/admin-audit-log.service';
import { CreateMenuCategoryDto } from './dto/create-menu-category.dto';
import { CreateProductDto } from './dto/create-product.dto';
import { SetMerchantAvailabilityDto } from './dto/set-merchant-availability.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser, AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';

@Controller()
export class CatalogController {
  constructor(
    private readonly service: CatalogService,
    private readonly auditLog: AdminAuditLogService,
  ) {}

  /** Approved merchants; `?type=مطاعم` narrows to one store type. */
  @Get('merchants')
  listMerchants(@Query('type') type?: string) {
    return this.service.listMerchants(type);
  }

  @Get('merchants/:id/menu')
  menu(@Param('id', ParseIntPipe) id: number) {
    return this.service.getMenu(id);
  }

  /**
   * @deprecated Aliases kept so app builds already on customers' phones keep
   * working. They now resolve a **merchant** id, which is what those builds
   * were sending all along — the id came from `/stores/nearby` and was only
   * ever mislabelled. Remove once the old builds are out of circulation.
   */
  @Get('restaurants')
  listRestaurantsAlias(@Query('type') type?: string) {
    return this.service.listMerchants(type);
  }

  @Get('restaurants/:id/menu')
  menuAlias(@Param('id', ParseIntPipe) id: number) {
    return this.service.getMenu(id);
  }

  @Post('admin/catalog/categories')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  async createCategory(
    @Body() dto: CreateMenuCategoryDto,
    @CurrentUser() admin: AuthUser,
  ) {
    const result = await this.service.createCategory(dto);
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'catalog.category.create',
      targetType: 'menu_category',
      targetId: (result as { id?: number })?.id ?? '',
      payload: dto,
    });
    return result;
  }

  @Post('admin/catalog/products')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  async createProduct(
    @Body() dto: CreateProductDto,
    @CurrentUser() admin: AuthUser,
  ) {
    const result = await this.service.createProduct(dto);
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'catalog.product.create',
      targetType: 'product',
      targetId: (result as { id?: number })?.id ?? '',
      payload: dto,
    });
    return result;
  }

  @Patch('admin/catalog/products/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  async updateProduct(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateProductDto>,
    @CurrentUser() admin: AuthUser,
  ) {
    const result = await this.service.updateProduct(id, dto);
    // Price edits live here — worth attributing.
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'catalog.product.update',
      targetType: 'product',
      targetId: id,
      payload: dto,
    });
    return result;
  }

  /**
   * Open or close a store for new orders.
   *
   * Separate from the approval workflow in `admin/approvals` on purpose: this
   * is the daily "the kitchen is closed" switch, not a judgement on whether
   * the store belongs on the platform at all.
   */
  @Patch('admin/catalog/merchants/:id/availability')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  async setMerchantAvailability(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: SetMerchantAvailabilityDto,
    @CurrentUser() admin: AuthUser,
  ) {
    const result = await this.service.setAcceptingOrders(
      id,
      dto.isAcceptingOrders,
    );
    await this.auditLog.record({
      adminId: admin.sub,
      action: 'merchant.availability',
      targetType: 'merchant',
      targetId: id,
      payload: { isAcceptingOrders: dto.isAcceptingOrders },
    });
    return result;
  }
}
