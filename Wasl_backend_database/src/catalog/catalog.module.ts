import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CatalogController } from './catalog.controller';
import { CatalogService } from './catalog.service';
import { MenuCategory } from './entities/menu-category.entity';
import { Product } from './entities/product.entity';
import { ProductAddon, ProductSize } from './entities/product-option.entity';
import { Merchant } from '../merchant/entities/merchant.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Merchant,
      MenuCategory,
      Product,
      ProductSize,
      ProductAddon,
    ]),
  ],
  controllers: [CatalogController],
  providers: [CatalogService],
  exports: [CatalogService],
})
export class CatalogModule {}
