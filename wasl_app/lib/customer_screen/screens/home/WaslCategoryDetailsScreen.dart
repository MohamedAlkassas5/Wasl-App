import 'package:flutter/material.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية فلاش الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';

class WaslCategoryDetailsScreen extends StatelessWidget {
  const WaslCategoryDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // 🎯 تحديث لون الخلفية الموحد
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'المطاعم والمتاجر',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // شريط الفلترة العلوي
            Container(
              color: AppColors.white,
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  _buildFilterChip('الكل', true),
                  _buildFilterChip('الأقرب إليك', false),
                  _buildFilterChip('الأعلى تقييماً', false),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: const [
                  // 🎯 تم إصلاح الـ const هنا لتجنب تحذيرات الـ Linter
                  Text(
                    'تم العثور على 24 موقعاً ممتازاً',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ),

            // قائمة المطاعم والمتاجر
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildRestaurantCard('ذا برجر هاوس', 'برجر • وجبات سريعة • أمريكي', '4.8', '25-35 دقيقة', 'توصيل مجاني', 'خصم 20%'),
                  _buildRestaurantCard('باستا وبيتزا', 'إيطالي • بيتزا • باستا', '4.5', '15-20 دقيقة', '15 ج.م', null),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 🎯 تطوير الفلتر ليدعم التدرج اللوني الاحترافي لـ FLASH عند الاختيار
  Widget _buildFilterChip(String text, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        gradient: isSelected ? AppColors.logoGradient : null,
        color: isSelected ? null : AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(String name, String subtitle, String rate, String time, String fee, String? promo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Container(
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Icon(Icons.storefront_outlined, size: 40, color: Colors.grey),
                ),
              ),
              // 🎯 كارت التخفيضات يعتمد الآن على لون الخطورة أو التنبيهات المعتمد بالهوية
              if (promo != null)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(8)),
                    child: Text(promo, style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                ),
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      Text(' $rate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    const Icon(Icons.favorite_border, color: AppColors.textSecondary, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'Cairo')),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(width: 20),
                    const Icon(Icons.delivery_dining_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(fee, style: TextStyle(fontSize: 12, color: fee == 'توصيل مجاني' ? AppColors.success : AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}