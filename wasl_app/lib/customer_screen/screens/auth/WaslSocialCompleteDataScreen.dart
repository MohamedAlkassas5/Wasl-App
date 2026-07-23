import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/providers/user_provider.dart';
import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';
import 'package:wasl_app/delivery_screen/WaslDriverHomeScreen.dart';
import 'package:wasl_app/services/auth_service.dart'; // 🎯 استيراد الخدمة لربط الباك إند

class WaslSocialCompleteDataScreen extends StatefulWidget {
  final String name;
  final String email;
  final String provider; // 'facebook' or 'email'
  final String firebaseUid; // 🎯 تم إضافة المعامل هنا لحل خطأ الـ Compilation بالملي

  const WaslSocialCompleteDataScreen({
    Key? key,
    required this.name,
    required this.email,
    required this.provider,
    required this.firebaseUid,
  }) : super(key: key);

  @override
  State<WaslSocialCompleteDataScreen> createState() => _WaslSocialCompleteDataScreenState();
}

class _WaslSocialCompleteDataScreenState extends State<WaslSocialCompleteDataScreen> {
  final _phoneController = TextEditingController();
  String _selectedRole = 'customer'; // القيمة الافتراضية: عميل
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// 📡 ترحيل البيانات الحية إلى سيرفر NestJS وتأمين الجلسة لايف
  void _saveAndProceed() async {
    if (_formKey.currentState!.validate()) {
      // إظهار مؤشر التحميل أثناء إنشاء الحساب في الباك إند
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      // ترحيل الحساب للسيرفر (إرسال كلمة مرور عشوائية أو افتراضية بما أنه دخول اجتماعي مؤمن بفايربيز)
      final result = await FlutterAuthService().register(
        name: widget.name,
        phone: _phoneController.text.trim(),
        password: 'SocialAuth_${widget.firebaseUid.substring(0, 5)}',
        role: _selectedRole,
        firebaseUid: widget.firebaseUid,
      );

      if (!mounted) return;
      Navigator.pop(context); // إغلاق الـ Loading

      if (result['success'] == true) {
        final data = result['data'];
        final userData = data['user'] ?? data;
        final String token = data['token'] ?? data['accessToken'] ?? '';

        // 🎯 ضخ البيانات ديناميكياً في محرك الـ Provider لإلغاء البيانات الثابتة
        Provider.of<UserProvider>(context, listen: false).saveUserSession(
          id: userData['id'] ?? 0,
          name: widget.name,
          phone: _phoneController.text.trim(),
          role: _selectedRole,
          token: token,
        );

        // حفظ البيانات محلياً لضمان بقاء تسجيل الدخول (Persistence)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userData['id'] ?? 0);
        await prefs.setString('user_name', widget.name);
        await prefs.setString('user_role', _selectedRole);
        await prefs.setString('user_phone', _phoneController.text.trim());
        await prefs.setString('access_token', token);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إعداد حسابك بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Color(0xFF22C55E)),
        );

        // التوجيه المباشر والذكي حسب نوع الحساب اللوجستي المختار
        if (_selectedRole == 'customer') {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WaslCustomerHomeScreen()), (route) => false);
        } else {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WaslDriverHomeScreen()), (route) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'فشل حفظ البيانات في السيرفر الرئيسي', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        title: const Text('استكمال بيانات التسجيل اللوجستي', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('مرحباً بك عبر تسجيل ${widget.provider == 'facebook' ? 'فيسبوك' : 'البريد'} 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('يرجى تحديد رغبتك لاستكمال إعدادات حسابك في كوم حمادة', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                  const SizedBox(height: 24),

                  // اختيار نوع الحساب (عميل أم مندوب) بأزرار فخمة
                  const Text('نوع الحساب المطلوب:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'customer'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'customer' ? AppColors.primary.withOpacity(0.08) : AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _selectedRole == 'customer' ? AppColors.primary : const Color(0xFFE2E8F0), width: 2),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.person_outline_rounded, color: _selectedRole == 'customer' ? AppColors.primary : AppColors.textSecondary, size: 28),
                                const SizedBox(height: 6),
                                Text('صاحب طلب (عميل)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: _selectedRole == 'customer' ? AppColors.primary : AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'delivery'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'delivery' ? AppColors.primary.withOpacity(0.08) : AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _selectedRole == 'delivery' ? AppColors.primary : const Color(0xFFE2E8F0), width: 2),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.delivery_dining_rounded, color: _selectedRole == 'delivery' ? AppColors.primary : AppColors.textSecondary, size: 28),
                                const SizedBox(height: 6),
                                Text('كابتن توصيل (مندوب)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: _selectedRole == 'delivery' ? AppColors.primary : AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // إدخال رقم الهاتف إلزاميًا
                  const Text('رقم الجوال لتلقي الإشعارات اللحظية:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    validator: (value) => (value == null || value.trim().length < 10) ? 'برجاء إدخال رقم جوال صحيح' : null,
                    decoration: InputDecoration(
                      hintText: 'مثال: 01023456789',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      fillColor: AppColors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: _saveAndProceed,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Text('حفظ وبدء استخدام فلاش 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverHomeScreen.dart';
//
// class WaslSocialCompleteDataScreen extends StatefulWidget {
//   final String name;
//   final String email;
//   final String provider; // 'facebook' or 'email'
//
//   const WaslSocialCompleteDataScreen({
//     Key? key,
//     required this.name,
//     required this.email,
//     required this.provider,
//   }) : super(key: key);
//
//   @override
//   State<WaslSocialCompleteDataScreen> createState() => _WaslSocialCompleteDataScreenState();
// }
//
// class _WaslSocialCompleteDataScreenState extends State<WaslSocialCompleteDataScreen> {
//   final _phoneController = TextEditingController();
//   String _selectedRole = 'customer'; // القيمة الافتراضية: عميل
//   final _formKey = GlobalKey<FormState>();
//
//   @override
//   void dispose() {
//     _phoneController.dispose();
//     super.dispose();
//   }
//
//   void _saveAndProceed() async {
//     if (_formKey.currentState!.validate()) {
//       // محاكاة حفظ التوكن والبيانات في الشيرد بريفرنسز لضمان الحفظ الدائم (Persistence)
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('access_token', 'social_mock_token_12345');
//       await prefs.setString('user_name', widget.name);
//       await prefs.setString('user_role', _selectedRole);
//       await prefs.setString('user_phone', _phoneController.text.trim());
//
//       if (!mounted) return;
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('تم إعداد حسابك بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Color(0xFF22C55E)),
//       );
//
//       // التوجيه المباشر حسب الاختيار
//       if (_selectedRole == 'customer') {
//         Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WaslCustomerHomeScreen()), (route) => false);
//       } else {
//         Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WaslDriverHomeScreen()), (route) => false);
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         title: const Text('استكمال بيانات التسجيل اللوجستي', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
//         centerTitle: true,
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(24.0),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Text('مرحباً بك عبر تسجيل ${widget.provider == 'facebook' ? 'فيسبوك' : 'البريد'} 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
//                   const SizedBox(height: 4),
//                   Text('يرجى تحديد رغبتك لاستكمال إعدادات حسابك في كوم حمادة', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
//                   const SizedBox(height: 24),
//
//                   // اختيار نوع الحساب (عميل أم مندوب) بأزرار فخمة
//                   const Text('نوع الحساب المطلوب:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: GestureDetector(
//                           onTap: () => setState(() => _selectedRole = 'customer'),
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             decoration: BoxDecoration(
//                               color: _selectedRole == 'customer' ? AppColors.primary.withOpacity(0.08) : AppColors.white,
//                               borderRadius: BorderRadius.circular(14),
//                               border: Border.all(color: _selectedRole == 'customer' ? AppColors.primary : const Color(0xFFE2E8F0), width: 2),
//                             ),
//                             child: Column(
//                               children: [
//                                 Icon(Icons.person_outline_rounded, color: _selectedRole == 'customer' ? AppColors.primary : AppColors.textSecondary, size: 28),
//                                 const SizedBox(height: 6),
//                                 Text('صاحب طلب (عميل)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: _selectedRole == 'customer' ? AppColors.primary : AppColors.textPrimary)),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: GestureDetector(
//                           onTap: () => setState(() => _selectedRole = 'delivery'),
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             decoration: BoxDecoration(
//                               color: _selectedRole == 'delivery' ? AppColors.primary.withOpacity(0.08) : AppColors.white,
//                               borderRadius: BorderRadius.circular(14),
//                               border: Border.all(color: _selectedRole == 'delivery' ? AppColors.primary : const Color(0xFFE2E8F0), width: 2),
//                             ),
//                             child: Column(
//                               children: [
//                                 Icon(Icons.delivery_dining_rounded, color: _selectedRole == 'delivery' ? AppColors.primary : AppColors.textSecondary, size: 28),
//                                 const SizedBox(height: 6),
//                                 Text('كابتن توصيل (مندوب)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: _selectedRole == 'delivery' ? AppColors.primary : AppColors.textPrimary)),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 24),
//
//                   // إدخال رقم الهاتف إلزاميًا
//                   const Text('رقم الجوال لتلقي الإشعارات اللحظية:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
//                   const SizedBox(height: 8),
//                   TextFormField(
//                     controller: _phoneController,
//                     keyboardType: TextInputType.phone,
//                     validator: (value) => (value == null || value.trim().length < 10) ? 'برجاء إدخال رقم جوال صحيح' : null,
//                     decoration: InputDecoration(
//                       hintText: 'مثال: 01023456789',
//                       fillColor: AppColors.white,
//                       filled: true,
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
//                     ),
//                   ),
//                   const SizedBox(height: 40),
//
//                   GestureDetector(
//                     onTap: _saveAndProceed,
//                     child: Container(
//                       height: 54,
//                       decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(16)),
//                       child: const Center(child: Text('حفظ وبدء استخدام فلاش 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15))),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }