import { Controller, Get } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CategoriesService } from './categories.service';

@Controller('categories') // 🌐 المسار الأساسي: /categories
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  /**
   * Deliberately public: the home screen renders the category strip before the
   * user signs in, and the list carries no user data. Rate-limited only, to
   * keep it from being used as a free DB-load generator.
   */
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Get()
  getCategories() {
    return this.categoriesService.findAll();
  }
}
