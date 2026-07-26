import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderCategoryScreen.dart';

class WaslCustomerOffersScreen extends StatelessWidget {
  const WaslCustomerOffersScreen({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> _promos = [
    {
      'icon': Icons.shopping_bag_rounded,
      'title': 'اطلب من أي مكان',
      'subtitle': 'صيدلية، سوبر ماركت، مكتبة — حتى لو المحل مش مشترك!',
      'color': Color(0xFF1B62E6),
    },
    {
      'icon': Icons.local_pharmacy_rounded,
      'title': 'توصيل صيدليات',
      'subtitle': 'أدوية وروشتات — ارفع صورة الروشتة ونوصلها لك.',
      'color': Color(0xFF0D5BE1),
    },
    {
      'icon': Icons.restaurant_rounded,
      'title': 'مطاعم كوم حمادة',
      'subtitle': 'اطلب من أي مطعم في المدينة بأسعار توصيل تنافسية.',
      'color': Color(0xFF12CFE0),
    },
    {
      'icon': Icons.storefront_rounded,
      'title': 'محلات قريبة منك',
      'subtitle': 'اكتشف المتاجر المشتركة واطلب مباشرة من التطبيق.',
      'color': Color(0xFF8B5CF6),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'العروض والمميزات',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 18,
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B62E6), Color(0xFF1FC4D6)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B62E6).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '📦 اطلب من أي مكان',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'الميزة الأقوى في وصل — اطلب أي حاجة من أي محل في كوم حمادة',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'خدمات مميزة في وصل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._promos.map((promo) => _buildPromoCard(context, promo)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'عروض المحلات والاشتراكات المميزة ستتوفر قريباً بعد إطلاق النسخة الأولى في كوم حمادة.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCard(BuildContext context, Map<String, dynamic> promo) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (promo['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(promo['icon'] as IconData, color: promo['color'] as Color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo['title'] as String,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promo['subtitle'] as String,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
