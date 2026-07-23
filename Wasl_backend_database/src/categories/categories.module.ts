import { Module } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CategoriesController } from './categories.controller';

@Module({
  imports: [], // ⚠️ مصفوفة الاستيراد نظيفة تماماً ولا تحتوي على AppModule لمنع الـ Circular Dependency
  controllers: [CategoriesController],
  providers: [CategoriesService],
})
export class CategoriesModule {}
