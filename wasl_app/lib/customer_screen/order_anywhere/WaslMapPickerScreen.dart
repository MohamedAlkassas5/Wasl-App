import 'package:flutter/material.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية فلاش الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderAnyplaceDetailsScreen.dart';

class WaslMapPickerScreen extends StatefulWidget {
  const WaslMapPickerScreen({Key? key}) : super(key: key);

  @override
  State<WaslMapPickerScreen> createState() => _WaslMapPickerScreenState();
}

class _WaslMapPickerScreenState extends State<WaslMapPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isConfirming = false;

  static const String _selectedLocationName = 'حي الملك فهد';
  static const String _selectedLocationAddress = 'شارع الأمير نايف بن عبدالعزيز، الرياض، المملكة العربية السعودية';

  Future<void> _confirmLocation() async {
    setState(() => _isConfirming = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isConfirming = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WaslOrderAnyplaceDetailsScreen(
          selectedAddress: '$_selectedLocationName Extracted، $_selectedLocationAddress',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // واجهة الخريطة التمثيلية بنظام ألوان فلاش البارد والمريح للعين
          Container(
            color: const Color(0xFFE2E8F0),
            child: const Center(child: Icon(Icons.map_outlined, size: 80, color: Color(0xFF94A3B8))),
          ),

          // شريط البحث العلوي وزر العودة المطور
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textPrimary.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textPrimary.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                                decoration: const InputDecoration(
                                  hintText: 'ابحث عن مكان، حي، أو معلم...',
                                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo'),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // دبوس تحديد الموقع الأنيق بمنتصف الشاشة تماشياً مع لون البراند الأساسي
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'توصيل الطلب هنا',
                    style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.location_pin, color: AppColors.primary, size: 46), // 🎯 الأيقونة تتبع الأزرق الأساسي لفلاش
              ],
            ),
          ),

          // اللوحة السفلية العصرية
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08), // 🎯 خلفية ناعمة من الأزرق الفخم
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.location_on, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              // 🎯 تم إصلاح الـ const هنا لتجنب قيود الـ Linter وتهيئة البيانات الديناميكية مستقبلاً
                              Text(
                                _selectedLocationName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _selectedLocationAddress,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 🎯 زر تأكيد الموقع الاحترافي المدعوم بالتدرج اللوني السريع لـ FLASH
                    GestureDetector(
                      onTap: _isConfirming ? null : _confirmLocation,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _isConfirming ? null : AppColors.logoGradient, // التدرج الرسمي الأزرق والسماوي
                          color: _isConfirming ? Colors.grey.shade300 : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isConfirming ? null : [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Center(
                          child: _isConfirming
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                          )
                              : const Text(
                            'تأكيد الموقع',
                            style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}