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
import { CreateMenuCategoryDto } from './dto/create-menu-category.dto';
import { CreateProductDto } from './dto/create-product.dto';
import { SetMerchantAvailabilityDto } from './dto/set-merchant-availability.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

@Controller()
export class CatalogController {
  constructor(private readonly service: CatalogService) {}

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
  createCategory(@Body() dto: CreateMenuCategoryDto) {
    return this.service.createCategory(dto);
  }

  @Post('admin/catalog/products')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createProduct(@Body() dto: CreateProductDto) {
    return this.service.createProduct(dto);
  }

  @Patch('admin/catalog/products/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  updateProduct(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateProductDto>,
  ) {
    return this.service.updateProduct(id, dto);
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
  setMerchantAvailability(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: SetMerchantAvailabilityDto,
  ) {
    return this.service.setAcceptingOrders(id, dto.isAcceptingOrders);
  }
}
