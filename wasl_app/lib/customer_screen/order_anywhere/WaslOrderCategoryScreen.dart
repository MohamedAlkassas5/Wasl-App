import 'package:flutter/material.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية فلاش الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';
// 🎯 تأكد من استيراد شاشة تفاصيل الطلب التالية في الـ Flow لتوجيه المستخدم إليها
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderDetailsFormScreen.dart';

class WaslOrderCategoryScreen extends StatelessWidget {
  const WaslOrderCategoryScreen({Key? key}) : super(key: key);

  // قائمة التصنيفات والبطاقات الكبيرة المحددة لـ V1 بحسب نموذج العمل
  final List<Map<String, dynamic>> _categories = const [
    {
      'title': '🍔 مطاعم',
      'desc': 'اطلب وجبتك المفضلة من أي مطعم بالمدينة',
      'value': 'مطاعم'
    },
    {
      'title': '🛒 سوبر ماركت',
      'desc': 'طلبات البيت، بقالة، أجبان، ومستلزمات يومية',
      'value': 'سوبر ماركت'
    },
    {
      'title': '💊 صيدلية',
      'desc': 'أدوية، مستحضرات تجميل، ورعاية صحية',
      'value': 'صيدلية'
    },
    {
      'title': '🍰 حلويات ومخابز',
      'desc': 'كيك، معجنات، خبز طازج، وحلويات شرقية وغربية',
      'value': 'حلويات ومخابز'
    },
    {
      'title': '📚 مكتبات',
      'desc': 'أدوات مكتبية، تصوير أوراق، ومستلزمات دراسية',
      'value': 'مكتبات'
    },
    {
      'title': '📱 إلكترونيات',
      'desc': 'شواحن، سماعات، إكسسوارات هواتف وصيانة سريعة',
      'value': 'إلكترونيات'
    },
    {
      'title': '📦 أي مكان آخر',
      'desc': 'طلب خاص من أي محل أو مكان غير مدرج بالقائمة',
      'value': 'أي مكان آخر'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // خلفية التطبيق الرسمية الناعمة
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'ماذا تريد طلبه؟',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, // دعم الواجهة العربية بالكامل
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _categories.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final category = _categories[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withOpacity(0.015),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  // الانتقال التلقائي للصفحة رقم 2: تفاصيل الطلب مع تمرير اسم التصنيف
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaslOrderDetailsFormScreen(category: category['value']),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category['desc'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}