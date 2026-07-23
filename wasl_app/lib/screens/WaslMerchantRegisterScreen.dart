import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/auth_service.dart'; // 🎯 استيراد الـ Service المحدثة
import 'package:wasl_app/screens/WaslPendingScreen.dart';

class WaslMerchantRegisterScreen extends StatefulWidget {
  final String? name;
  final String? phone;
  final String? password;
  final String? role;

  const WaslMerchantRegisterScreen({Key? key, this.name, this.phone, this.password, this.role}) : super(key: key);

  @override
  State<WaslMerchantRegisterScreen> createState() => _WaslMerchantRegisterScreenState();
}

class _WaslMerchantRegisterScreenState extends State<WaslMerchantRegisterScreen> {
  int _selectedCategoryIndex = 0;
  final ImagePicker _picker = ImagePicker();
  File? _storeLogo;

  final TextEditingController _storeNameController = TextEditingController();
  String _locationStatus = "جاري التقاط إحداثيات GPS تلقائياً... ⏳";
  bool _isLocationDetected = false;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'مطاعم', 'icon': Icons.restaurant},
    {'title': 'بقالة', 'icon': Icons.shopping_basket_outlined},
    {'title': 'صيدليات', 'icon': Icons.local_pharmacy_outlined},
    {'title': 'مقاهي', 'icon': Icons.coffee_outlined},
  ];

  @override
  void initState() { super.initState(); _getCurrentLocation(); }

  @override
  void dispose() { _storeNameController.dispose(); super.dispose(); }

  Future<void> _getCurrentLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) { setState(() { _locationStatus = "يرجى تفعيل الـ GPS بالهاتف 📍"; }); return; }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) { setState(() { _locationStatus = "تم رفض صلاحية الموقع ❌"; }); return; }
    }
    try {
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _isLocationDetected = true; _locationStatus = "تم تحديد موقع منشأتك المعتمد نجاحاً ✅"; });
    } catch (_) {
      setState(() { _locationStatus = "فشل التقاط الإحداثيات اللحظية ❌"; });
    }
  }

  // 🚀 الدالة اللوجستية المحدثة لإرسال بيانات ومستندات المتجر للسيرفر الهجين
  void _submitMerchantData() async {
    if (_storeNameController.text.isEmpty || _storeLogo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة اسم المتجر ورفع الشعار للمتابعة', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));

    // 📡 استدعاء دالة الـ register النظيفة والمحدثة المتوافقة مع NestJS
    final result = await FlutterAuthService().register(
      name: widget.name ?? '',
      phone: widget.phone ?? '',
      password: widget.password ?? '',
      role: widget.role ?? 'merchant',
      storeName: _storeNameController.text.trim(),
      storeType: _categories[_selectedCategoryIndex]['title'],
      storeLogo: _storeLogo,
    );

    if (!mounted) return;
    Navigator.pop(context); // إغلاق مؤشر التحميل

    if (result['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WaslPendingScreen(phone: widget.phone ?? '', role: 'merchant', initialNotes: 'جاري مراجعة السجل التجاري وموقع منشأتك من قبل الإدارة.')),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'فشلت عملية إنشاء حساب شريك المتجر، يرجى إعادة المحاولة لاحقاً.', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('إعداد النشاط التجاري', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('بيانات النشاط واللوجو', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13)),
                    Text('الخطوة ٣ من ٣', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: 1.0, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
                const SizedBox(height: 24),

                _buildCardSection('الهوية التجارية للمنشأة', Icons.storefront, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اسم المتجر / العلامة التجارية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _storeNameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'مثال: شاورما على الفحم',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo'),
                        fillColor: AppColors.background,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 1.2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _categories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.3, crossAxisSpacing: 12, mainAxisSpacing: 12),
                      itemBuilder: (context, idx) {
                        bool isSel = _selectedCategoryIndex == idx;
                        return InkWell(
                          onTap: () => setState(() => _selectedCategoryIndex = idx),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isSel ? AppColors.logoGradient : null,
                              color: isSel ? null : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSel ? Colors.transparent : const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_categories[idx]['icon'], color: isSel ? AppColors.white : AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  _categories[idx]['title'],
                                  style: TextStyle(color: isSel ? AppColors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  ],
                )),
                const SizedBox(height: 16),

                _buildCardSection('الشعار الرسمي المعتمد', Icons.image_outlined, InkWell(
                  onTap: () async {
                    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
                    if (file != null) setState(() { _storeLogo = File(file.path); });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _storeLogo != null ? const Color(0xFFF0FDF4) : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _storeLogo != null ? AppColors.success.withOpacity(0.4) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_storeLogo != null ? Icons.check_circle : Icons.add_a_photo_outlined, color: _storeLogo != null ? AppColors.success : AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          _storeLogo != null ? 'تم اختيار الشعار بنجاح 🎉' : 'اضغط لرفع لوجو المتجر',
                          style: TextStyle(color: _storeLogo != null ? AppColors.success : AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                        )
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 16),

                _buildCardSection('الموقع الجغرافي للنشاط', Icons.location_on_outlined, Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        _locationStatus,
                        style: TextStyle(fontSize: 13, color: _isLocationDetected ? AppColors.success : AppColors.warning, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 28),

                GestureDetector(
                  onTap: _submitMerchantData,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.logoGradient,
                      borderRadius: BorderRadius.circular(14),
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
                        'إكمال التسجيل وإرسال الطلب',
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
    );
  }

  Widget _buildCardSection(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 14)),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          child,
        ],
      ),
    );
  }
}