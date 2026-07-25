import 'package:flutter/material.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';

class WaslOrderFailureScreen extends StatelessWidget {
  final String? errorCode;
  final VoidCallback? onRetry;

  const WaslOrderFailureScreen({Key? key, this.errorCode, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // 🎯 تحديث لون الخلفية الموحد لـ FLASH
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(Icons.close, color: AppColors.textPrimary, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.7, end: 1.0),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1), // 🎯 التوافق مع لون الخطأ المعتمد بالهوية
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline, size: 50, color: AppColors.danger),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'عذراً، فشلت العملية',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لم نتمكن من معالجة عملية الدفع لطلبك الحالي. يرجى التحقق من تفاصيل البطاقة أو الرصيد المتاح والمحاولة مرة أخرى.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'رمز الخطأ: ${errorCode ?? 'PAY_ERR_402'}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const Spacer(),

                // 🎯 زر إعادة المحاولة الاحترافي المدعوم بالتدرج اللوني لـ FLASH
                GestureDetector(
                  onTap: onRetry ?? () => Navigator.pop(context),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.logoGradient, // التدرج الرسمي
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'إعادة المحاولة',
                        style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // زر التواصل مع الدعم الفني المصلح تماماً من قيود الـ const لـ فلاتر 3.x
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.headset_mic_outlined, size: 18, color: AppColors.textPrimary),
                  label: const Text(
                    'تواصل مع الدعم',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}