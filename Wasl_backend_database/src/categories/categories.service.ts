import { Injectable } from '@nestjs/common';

@Injectable()
export class CategoriesService {
  // 📦 دالة مخصصة لترجيع التصنيفات الحقيقية المتوافقة مع الـ UI في فلاتر
  findAll() {
    return [
      { id: 1, name: 'مطاعم', iconName: 'restaurant', color: '#EBF3FF' },
      { id: 2, name: 'تموينك', iconName: 'shopping', color: '#E8F5E9' },
      { id: 3, name: 'صيدليات', iconName: 'pharmacy', color: '#FFFFEBEE' },
      { id: 4, name: 'مخابز', iconName: 'bakery', color: '#E3F2FD' },
      { id: 5, name: 'إلكترونيات', iconName: 'devices', color: '#F0F4F8' },
      { id: 6, name: 'قرطاسية', iconName: 'edit_note', color: '#F1F5F9' },
      { id: 7, name: 'هدايا', iconName: 'gift', color: '#FFF8E1' },
      { id: 8, name: 'منزل', iconName: 'home', color: '#E0F7FA' },
    ];
  }
}
