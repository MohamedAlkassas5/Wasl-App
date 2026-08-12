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
import { CreateRestaurantDto } from './dto/create-restaurant.dto';
import { CreateMenuCategoryDto } from './dto/create-menu-category.dto';
import { CreateProductDto } from './dto/create-product.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

@Controller()
export class CatalogController {
  constructor(private readonly service: CatalogService) {}

  @Get('restaurants') list(@Query('all') all?: string) {
    return this.service.listRestaurants(all === 'true');
  }
  @Get('restaurants/:id/menu') menu(@Param('id', ParseIntPipe) id: number) {
    return this.service.getMenu(id);
  }

  @Post('admin/restaurants')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createRestaurant(@Body() dto: CreateRestaurantDto) {
    return this.service.createRestaurant(dto);
  }

  @Patch('admin/restaurants/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  updateRestaurant(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateRestaurantDto>,
  ) {
    return this.service.updateRestaurant(id, dto);
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
}
