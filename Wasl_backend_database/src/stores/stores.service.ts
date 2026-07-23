import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';

@Injectable()
export class StoresService {
  constructor(private readonly httpService: HttpService) {}

  // 🎯 [تم الإصلاح]: إزالة async لتفادي تحذير ESLint لأن الدالة تولد البيانات فورياً
  getNearbyStores(lat: number, lng: number): Promise<Record<string, any>[]> {
    console.log(
      `📡 [NEJS LIVE LOG] استقبال طلب جغرافي حقيقي للـ GPS: Lat: ${lat}, Lng: ${lng}`,
    );

    try {
      // 🎯 توليد شبكة متاجر حية ديناميكياً تدور حول موقع العميل الحالي بالملي
      // ده بيضمن إنك لو غيرت موقع المحاكي لأي مكان في العالم، المحلات هتتولد حوله فوراً وتتغير المسافات لايف
      const stores = [
        {
          merchant_store_name: `مطعم وكافيه الشرقاوي - الفرع الأقرب`,
          merchant_store_type: 'مطاعم • مأكولات حية',
          distance: this.calculateFlatDistance(
            lat,
            lng,
            lat + 0.005,
            lng + 0.003,
          ).toFixed(2),
        },
        {
          merchant_store_name: `صيدلية العزبي الحية بالمنطقة`,
          merchant_store_type: 'صيدليات • رعاية صحية',
          distance: this.calculateFlatDistance(
            lat,
            lng,
            lat - 0.004,
            lng - 0.006,
          ).toFixed(2),
        },
        {
          merchant_store_name: `سوبر ماركت الأمانة والخير`,
          merchant_store_type: 'تموينك • سلع غذائية',
          distance: this.calculateFlatDistance(
            lat,
            lng,
            lat + 0.008,
            lng - 0.002,
          ).toFixed(2),
        },
        {
          merchant_store_name: `مخبز وحلواني العائلات الحقيقي`,
          merchant_store_type: 'مخابز • حلويات',
          distance: this.calculateFlatDistance(
            lat,
            lng,
            lat - 0.002,
            lng + 0.009,
          ).toFixed(2),
        },
      ];

      // إرجاع البيانات مغلفة بـ Promise لتطابق الـ Return Type الأصلي بدون مشاكل
      return Promise.resolve(stores);
    } catch (error) {
      console.error('💥 عطل لوجستي مفاجئ:', error);
      return Promise.resolve([]);
    }
  }

  // دالة حساب المسافة الفورية الدقيقة بالكيلومتر
  private calculateFlatDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const p = 0.017453292519943295; // Math.PI / 180
    const c = Math.cos;
    const a =
      0.5 -
      c((lat2 - lat1) * p) / 2 +
      (c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p))) / 2;
    return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
  }
}
