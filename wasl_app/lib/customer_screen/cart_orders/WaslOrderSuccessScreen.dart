import 'dart:async';
import 'package:flutter/material.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية فلاش الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';
// 🎯 استيراد شاشة عروض الأسعار للانتقال إليها تلقائياً
import 'package:wasl_app/customer_screen/cart_orders/WaslOrderOffersScreen.dart';

class WaslOrderSuccessScreen extends StatefulWidget {
  final String orderId;

  const WaslOrderSuccessScreen({
    Key? key,
    this.orderId = '9082', // 🎯 يُفضل الافتراضي يكون أرقام فقط للتحويل الآمن
  }) : super(key: key);

  @override
  State<WaslOrderSuccessScreen> createState() => _WaslOrderSuccessScreenState();
}

class _WaslOrderSuccessScreenState extends State<WaslOrderSuccessScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // ⏳ مؤقت تلقائي للانتقال لشاشة استقبال العروض بعد 3 ثوانٍ
    _timer = Timer(const Duration(seconds: 3), () {
      _navigateToOffers();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateToOffers() {
    if (!mounted) return;

    // 🎯 الحل السحري: استخراج الأرقام فقط والتحويل إلى int لتفادي أي عوائق في الـ Types
    // في حالة وجود حروف مثل "FL-9082" نقوم بتنظيف النص ليحتوي على أرقام فقط قبل الـ parse
    final cleanIdString = widget.orderId.replaceAll(RegExp(r'[^0-9]'), '');
    final int parsedOrderId = int.tryParse(cleanIdString) ?? 9082;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WaslOrderOffersScreen(orderId: parsedOrderId), // 👈 تم التمرير كـ int بنجاح
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // لون الخلفية الموحد لـ FLASH
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // 🟢 أنيميشن مرن وبسيط يفتح تلقائياً عند ظهور الشاشة لأيقونة النجاح
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7), // خلفية خضراء ناعمة متوافقة مع حالات النجاح
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 56,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'تم إرسال طلبك بنجاح! 🚀',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'رقم الطلب اللوجستي: ${widget.orderId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'تم نشر طلبك الآن في ساحة الكباتن بـ كوم حمادة. جاري تحضير واستقبال عروض الأسعار التنافسية لك حالياً يرجى الانتظار...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 32),

                // مؤشر تحميل دائري صغير يوضح للعميل أن هناك تدفق تلقائي سيحدث
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),

                const Spacer(),

                // زر يدوي اختياري لو العميل مستعجل ومش عايز يستنى الـ 3 ثواني للمؤقت
                GestureDetector(
                  onTap: _navigateToOffers,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.logoGradient, // التدرج الرسمي لـ FLASH
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'الانتقال لعروض الكباتن الآن',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}