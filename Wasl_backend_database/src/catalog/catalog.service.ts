import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Restaurant } from './entities/restaurant.entity';
import { MenuCategory } from './entities/menu-category.entity';
import { Product } from './entities/product.entity';
import { CreateRestaurantDto } from './dto/create-restaurant.dto';
import { CreateMenuCategoryDto } from './dto/create-menu-category.dto';
import { CreateProductDto } from './dto/create-product.dto';

@Injectable()
export class CatalogService {
  constructor(
    @InjectRepository(Restaurant)
    private readonly restaurants: Repository<Restaurant>,
    @InjectRepository(MenuCategory)
    private readonly categories: Repository<MenuCategory>,
    @InjectRepository(Product) private readonly products: Repository<Product>,
  ) {}

  listRestaurants(includeInactive = false) {
    return this.restaurants.find({
      where: includeInactive ? {} : { isActive: true },
      order: { name: 'ASC' },
    });
  }

  async getMenu(id: number) {
    const restaurant = await this.restaurants.findOne({
      where: { id, isActive: true },
    });
    if (!restaurant) throw new NotFoundException('Restaurant not found');
    const [categories, products] = await Promise.all([
      this.categories.find({
        where: { restaurantId: id, isActive: true },
        order: { sortOrder: 'ASC', name: 'ASC' },
      }),
      this.products.find({
        where: { restaurantId: id, isAvailable: true },
        order: { name: 'ASC' },
      }),
    ]);
    return { restaurant, categories, products };
  }

  createRestaurant(dto: CreateRestaurantDto) {
    return this.restaurants.save(this.restaurants.create(dto));
  }
  async updateRestaurant(id: number, dto: Partial<CreateRestaurantDto>) {
    const entity = await this.restaurants.preload({ id, ...dto });
    if (!entity) throw new NotFoundException('Restaurant not found');
    return this.restaurants.save(entity);
  }
  async createCategory(dto: CreateMenuCategoryDto) {
    const restaurant = await this.restaurants.findOneBy({
      id: dto.restaurantId,
    });
    if (!restaurant) throw new NotFoundException('Restaurant not found');
    return this.categories.save(this.categories.create(dto));
  }
  async createProduct(dto: CreateProductDto) {
    const restaurant = await this.restaurants.findOneBy({
      id: dto.restaurantId,
    });
    if (!restaurant) throw new NotFoundException('Restaurant not found');
    return this.products.save(
      this.products.create({ ...dto, isAvailable: dto.isAvailable ?? true }),
    );
  }
  async updateProduct(id: number, dto: Partial<CreateProductDto>) {
    const entity = await this.products.preload({ id, ...dto });
    if (!entity) throw new NotFoundException('Product not found');
    return this.products.save(entity);
  }
}
