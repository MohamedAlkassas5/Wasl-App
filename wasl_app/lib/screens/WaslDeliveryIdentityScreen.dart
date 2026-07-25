import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/screens/WaslPendingScreen.dart';

class WaslDeliveryIdentityScreen extends StatefulWidget {
  final String? name;
  final String? phone;
  final String? password;
  final String? role;

  const WaslDeliveryIdentityScreen({Key? key, this.name, this.phone, this.password, this.role}) : super(key: key);

  @override
  State<WaslDeliveryIdentityScreen> createState() => _WaslDeliveryIdentityScreenState();
}

class _WaslDeliveryIdentityScreenState extends State<WaslDeliveryIdentityScreen> {
  File? _idFront;
  File? _idBack;
  File? _vehicleImage;
  String _selectedVehicleType = 'motorcycle'; // car, motorcycle, scooter, bicycle
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(int type) async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() {
        if (type == 1) _idFront = File(file.path);
        else if (type == 2) _idBack = File(file.path);
        else _vehicleImage = File(file.path);
      });
    }
  }

  // 🚀 استدعاء دالة التسجيل مع الفحص الصريح والمأمن للـ Boolean الراجع من السيرفر الهجين
  void _submitDeliveryData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final result = await FlutterAuthService().register(
      name: widget.name ?? '',
      phone: widget.phone ?? '',
      password: widget.password ?? '',
      role: widget.role ?? 'delivery',
      idFront: _idFront,
      idBack: _idBack,
      vehicleType: _selectedVehicleType,
      vehicleImage: _vehicleImage,
    );

    if (!mounted) return;
    Navigator.pop(context); // إغلاق مؤشر التحميل

    if (result['success'] == true) { // 🎯 التعديل المأمن والصريح لمنع أي تعارض في الـ Types
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WaslPendingScreen(
            phone: widget.phone ?? '',
            role: 'delivery',
            initialNotes: 'جاري فحص وتدقيق مستندات القيادة والمركبة من قِبل إدارة وصل.',
          ),
        ),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'فشلت عملية رفع البيانات، يرجى المحاولة لاحقاً', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // التحقق من رفع الكابتن لجميع الوثائق الإجبارية لتفعيل زر المتابعة
    bool canProceed = _idFront != null && _idBack != null && _vehicleImage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'وثائق شريك التوصيل',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('إثبات الهوية والنقل', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo')),
                        Text('الخطوة ٣ من ٣', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: 1.0, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('رفع المستندات الرسمية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      const SizedBox(height: 20),
                      _buildUploadBox('الوجه الأمامي للهوية الوطنية', _idFront, () => _pickImage(1), Icons.badge_outlined),
                      const SizedBox(height: 16),
                      _buildUploadBox('الوجه الخلفي للهوية الوطنية', _idBack, () => _pickImage(2), Icons.credit_card),

                      const Divider(height: 40, thickness: 1, color: Color(0xFFE2E8F0)),
                      const Text('تحديد وسيلة النقل الحالية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildVehicleOption('سيارة توصيل', 'car', Icons.directions_car),
                          const SizedBox(width: 12),
                          _buildVehicleOption('دراجة نارية', 'motorcycle', Icons.delivery_dining),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildUploadBox('صورة مركبة التنقل الخاصة بك', _vehicleImage, () => _pickImage(3), Icons.camera_alt_outlined),
                      const SizedBox(height: 32),

                      GestureDetector(
                        onTap: canProceed ? _submitDeliveryData : null,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: canProceed ? AppColors.logoGradient : null,
                            color: canProceed ? null : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: canProceed ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.24),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ] : null,
                          ),
                          child: Center(
                            child: Text(
                              'إرسال المستندات للمراجعة',
                              style: TextStyle(
                                fontSize: 16,
                                color: canProceed ? AppColors.white : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadBox(String title, File? file, VoidCallback onTap, IconData icon) {
    bool hasFile = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF0FDF4) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasFile ? AppColors.success.withOpacity(0.5) : const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasFile ? const Color(0xFFDCFCE7) : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(hasFile ? Icons.check_circle : icon, color: hasFile ? AppColors.success : AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo'))),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOption(String label, String value, IconData icon) {
    bool isSel = _selectedVehicleType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedVehicleType = value),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: isSel ? AppColors.logoGradient : null,
            color: isSel ? null : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? Colors.transparent : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSel ? AppColors.white : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSel ? AppColors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
        ),
      ),
    );
  }
}