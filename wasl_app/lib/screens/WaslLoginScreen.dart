// import 'package:flutter/material.dart';
// import 'package:country_picker/country_picker.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/core/providers/user_provider.dart';
// import 'package:wasl_app/screens/WaslRegisterScreen.dart';
// import 'package:wasl_app/screens/WaslForgotPasswordScreen.dart';
// import 'package:wasl_app/screens/WaslPendingScreen.dart';
// import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderCategoryScreen.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverHomeScreen.dart';
// import 'package:wasl_app/customer_screen/screens/auth/WaslSocialCompleteDataScreen.dart';
// import 'package:wasl_app/services/auth_service.dart';
// import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';
//
// class WaslLoginScreen extends StatefulWidget {
//   const WaslLoginScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslLoginScreen> createState() => _WaslLoginScreenState();
// }
//
// class _WaslLoginScreenState extends State<WaslLoginScreen> {
//   String _selectedCountryCode = '20';
//   String _selectedCountryFlag = '🇪🇬';
//   bool _obscurePassword = true;
//
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//
//   @override
//   void dispose() {
//     _phoneController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
//
//   // 🎯 التحديث الذكي: فحص الجلسة الاجتماعية وتأمين الدخول السريع أو استكمال البيانات لايف
//   void _handleSocialLogin(String provider) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
//     );
//
//     // 📡 محاكاة استرجاع البيانات من حزمة جوجل أو فيسبوك الحقيقية عبر الفايربيز
//     await Future.delayed(const Duration(seconds: 1));
//     if (!mounted) return;
//     Navigator.pop(context); // إغلاق الـ Loading
//
//     String dummyEmail = provider == 'facebook' ? 'ahmed_fb@wasl.com' : 'ahmed_google@wasl.com';
//     String dummyName = provider == 'facebook' ? 'Ahmed Harfoush (FB)' : 'Ahmed Talaat';
//     String dummyUid = 'social_firebase_uid_123456';
//
//     // 🔍 الفحص الحي والربط المباشر داخل الـ Database عبر الباك إند NestJS
//     final check = await FlutterAuthService().socialLoginCheck(email: dummyEmail, firebaseUid: dummyUid);
//
//     if (check['success'] == true) {
//       if (check['isRegistered'] == true) {
//         // 🎉 العميل مسجل مسبقاً! دخله فوراً واحفظ جلسته تلقائياً
//         final data = check['data'];
//         final userData = data['user'];
//         final String token = data['token'] ?? '';
//
//         // 🎯 [تم التحديث لايف]: التقاط الـ ID التلقائي من الداتابيز للحساب الاجتماعي
//         final int realUserId = int.tryParse(userData['id']?.toString() ?? '') ?? 0;
//
//         if (!mounted) return;
//         Provider.of<UserProvider>(context, listen: false).saveUserSession(
//           id: realUserId,
//           name: userData['name'] ?? dummyName,
//           phone: userData['phone'] ?? '',
//           role: userData['role'] ?? 'customer',
//           token: token,
//         );
//
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setInt('user_id', realUserId);
//         await prefs.setString('user_name', userData['name'] ?? dummyName);
//         await prefs.setString('user_role', userData['role'] ?? 'customer');
//         await prefs.setString('access_token', token);
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('مرحباً بعودتك السريعة يا ${userData['name'] ?? dummyName} 🎉', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF22C55E)),
//         );
//         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslCustomerHomeScreen()));
//       } else {
//         // 🆕 العميل أول مرة يدخل؛ انقله لشاشة استكمال البيانات
//         if (!mounted) return;
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => WaslSocialCompleteDataScreen(
//               name: dummyName,
//               email: dummyEmail,
//               provider: provider,
//               firebaseUid: dummyUid,
//             ),
//           ),
//         );
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(check['message'] ?? 'فشل تسجيل الدخول الاجتماعي', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
//       );
//     }
//   }
//
//   void _handleLogin() async {
//     if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('يرجى ملء كافة الحقول', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
//       );
//       return;
//     }
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
//     );
//
//     String cleanPhone = _phoneController.text.trim();
//     if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
//     String fullPhone = '+$_selectedCountryCode$cleanPhone';
//
//     final result = await FlutterAuthService().login(
//       phone: fullPhone,
//       password: _passwordController.text,
//     );
//
//     if (!mounted) return;
//     Navigator.pop(context); // إغلاق الـ Loading
//
//     if (result['success'] == true) {
//       final data = result['data'];
//       final userData = data['user'];
//       final String token = data['token'] ?? '';
//
//       // 🎯 [تم التحديث لايف]: التقاط الـ ID التلقائي الحقيقي القادم من الـ PostgreSQL فوراً
//       final int realUserId = int.tryParse(userData['id']?.toString() ?? '') ?? 0;
//       final String name = userData['name'] ?? 'مستخدم فلاش';
//       final String phone = userData['phone'] ?? fullPhone;
//       final String role = userData['role'] ?? 'customer';
//       final String status = userData['status'] ?? 'active';
//
//       // ضخ الـ ID الحقيقي داخل الـ Provider ليكون متاحاً لكل المنظومة تلقائياً
//       Provider.of<UserProvider>(context, listen: false).saveUserSession(
//         id: realUserId,
//         name: name,
//         phone: phone,
//         role: role,
//         token: token,
//       );
//
//       // حفظه في الكاش المحلي للتأمين وبقاء الجلسة دافئة
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setInt('user_id', realUserId);
//       await prefs.setString('user_name', name);
//       await prefs.setString('user_phone', phone);
//       await prefs.setString('user_role', role);
//       await prefs.setString('access_token', token);
//
//       if (role == 'delivery' || role == 'merchant') {
//         if (status == 'pending' || status == 'rejected') {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (_) => WaslPendingScreen(
//                 phone: phone,
//                 initialNotes: userData['adminNotes'] ?? 'جاري مراجعة حسابك اللوجستي من قِبل إدارة فلاش.',
//               ),
//             ),
//           );
//           return;
//         }
//       }
//
//       if (role == 'delivery') {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('تم تسجيل دخولك بنجاح يا كابتن $name 🚀', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF22C55E)),
//         );
//         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslDriverHomeScreen()));
//       } else if (role == 'merchant') {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('مرحباً بك يا تاجر $name في لوحة التحكم 🏪', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF22C55E)),
//         );
//         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen()));
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('مرحباً بك في فلاش توصيل $name 🎉', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF22C55E)),
//         );
//         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslCustomerHomeScreen()));
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(result['message'] ?? 'بيانات الدخول غير صحيحة', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
//             physics: const BouncingScrollPhysics(),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 const SizedBox(height: 16),
//                 Center(
//                   child: Container(
//                     width: 120,
//                     height: 120,
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: AppColors.white,
//                       borderRadius: BorderRadius.circular(28),
//                       boxShadow: [
//                         BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))
//                       ],
//                     ),
//                     child: Image.asset(
//                       'images/wasal_logo_new.png',
//                       fit: BoxFit.contain,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Container(
//                           decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(20)),
//                           child: const Icon(Icons.flash_on, size: 48, color: AppColors.white),
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'فلاش توصيل • FLASH',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//                 ),
//                 const SizedBox(height: 4),
//                 const Text(
//                   'أدخل بيانات حسابك اللوجستي للمتابعة السريعة',
//                   style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo'),
//                 ),
//                 const SizedBox(height: 24),
//                 Container(
//                   padding: const EdgeInsets.all(24),
//                   decoration: BoxDecoration(
//                     color: AppColors.white,
//                     borderRadius: BorderRadius.circular(24),
//                     boxShadow: [
//                       BoxShadow(color: AppColors.textPrimary.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 6))
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildLabel('رقم الجوال'),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: SizedBox(
//                               height: 54,
//                               child: TextField(
//                                 controller: _phoneController,
//                                 keyboardType: TextInputType.phone,
//                                 textAlign: TextAlign.left,
//                                 style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
//                                 decoration: InputDecoration(
//                                   fillColor: AppColors.background,
//                                   filled: true,
//                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
//                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16),
//                                   hintText: '1xxxxxxxxx',
//                                   hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           GestureDetector(
//                             onTap: () {
//                               showCountryPicker(
//                                 context: context,
//                                 showPhoneCode: true,
//                                 countryListTheme: CountryListThemeData(borderRadius: BorderRadius.circular(24), bottomSheetHeight: 500),
//                                 onSelect: (Country country) {
//                                   setState(() {
//                                     _selectedCountryCode = country.phoneCode;
//                                     _selectedCountryFlag = country.flagEmoji;
//                                   });
//                                 },
//                               );
//                             },
//                             child: Container(
//                               height: 54,
//                               padding: const EdgeInsets.symmetric(horizontal: 14),
//                               decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
//                               child: Row(
//                                 children: [
//                                   const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
//                                   const SizedBox(width: 4),
//                                   Text('$_selectedCountryFlag +$_selectedCountryCode', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary), textDirection: TextDirection.ltr),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 20),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           _buildLabel('كلمة المرور'),
//                           GestureDetector(
//                             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslForgotPasswordScreen())),
//                             child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                           ),
//                         ],
//                       ),
//                       SizedBox(
//                         height: 54,
//                         child: TextField(
//                           controller: _passwordController,
//                           obscureText: _obscurePassword,
//                           textAlign: TextAlign.left,
//                           style: const TextStyle(color: AppColors.textPrimary),
//                           decoration: InputDecoration(
//                             hintText: '••••••••',
//                             fillColor: AppColors.background,
//                             filled: true,
//                             prefixIcon: IconButton(
//                               icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textSecondary),
//                               onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
//                             ),
//                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
//                             contentPadding: const EdgeInsets.symmetric(horizontal: 16),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 24),
//                       GestureDetector(
//                         onTap: _handleLogin,
//                         child: Container(
//                           height: 54,
//                           decoration: BoxDecoration(
//                             gradient: AppColors.logoGradient,
//                             borderRadius: BorderRadius.circular(14),
//                             boxShadow: [
//                               BoxShadow(color: AppColors.primary.withOpacity(0.24), blurRadius: 16, offset: const Offset(0, 6))
//                             ],
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: const [
//                               Text('تسجيل الدخول', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                               SizedBox(width: 8),
//                               Icon(Icons.bolt, color: Colors.white, size: 20),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 Row(
//                   children: const [
//                     Expanded(child: Divider(color: Color(0xFFCBD5E1), endIndent: 10)),
//                     Text('أو سجل سريعاً عبر', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
//                     Expanded(child: Divider(color: Color(0xFFCBD5E1), indent: 10)),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => _handleSocialLogin('facebook'),
//                         icon: const Icon(Icons.facebook, color: Colors.white, size: 20),
//                         label: const Text('فيسبوك', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFF1877F2),
//                           minimumSize: const Size.fromHeight(48),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           elevation: 0,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => _handleSocialLogin('email'),
//                         icon: const Icon(Icons.email_outlined, color: AppColors.textPrimary, size: 20),
//                         label: const Text('البريد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.white,
//                           minimumSize: const Size.fromHeight(48),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           side: const BorderSide(color: Color(0xFFE2E8F0)),
//                           elevation: 0,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 24),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text('ليس لديك حساب؟ ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Cairo')),
//                     GestureDetector(
//                       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslRegisterScreen())),
//                       child: const Text('إنشاء حساب جديد', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
//                     ),
//                   ],
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLabel(String text) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8.0),
//       child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/providers/user_provider.dart';
import 'package:wasl_app/screens/WaslRegisterScreen.dart';
import 'package:wasl_app/screens/WaslForgotPasswordScreen.dart';
import 'package:wasl_app/screens/WaslPendingScreen.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderCategoryScreen.dart';
import 'package:wasl_app/delivery_screen/WaslDriverHomeScreen.dart';
import 'package:wasl_app/customer_screen/screens/auth/WaslSocialCompleteDataScreen.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';

class WaslLoginScreen extends StatefulWidget {
  const WaslLoginScreen({Key? key}) : super(key: key);

  @override
  State<WaslLoginScreen> createState() => _WaslLoginScreenState();
}

class _WaslLoginScreenState extends State<WaslLoginScreen> {
  String _selectedCountryCode = '20';
  String _selectedCountryFlag = '🇪🇬';
  bool _obscurePassword = true;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSocialLogin(String provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context);

    String dummyEmail = provider == 'facebook' ? 'ahmed_fb@wasl.com' : 'ahmed_google@wasl.com';
    String dummyName = provider == 'facebook' ? 'Ahmed Harfoush (FB)' : 'Ahmed Talaat';
    String dummyUid = 'social_firebase_uid_123456';

    final check = await FlutterAuthService().socialLoginCheck(email: dummyEmail, firebaseUid: dummyUid);

    if (check['success'] == true) {
      if (check['isRegistered'] == true) {
        final data = check['data'];
        final userData = data['user'];
        final String token = data['token'] ?? '';
        final int realUserId = int.tryParse(userData['id']?.toString() ?? '') ?? 0;

        if (!mounted) return;
        Provider.of<UserProvider>(context, listen: false).saveUserSession(
          id: realUserId,
          name: userData['name'] ?? dummyName,
          phone: userData['phone'] ?? '',
          role: userData['role'] ?? 'customer',
          token: token,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', realUserId);
        await prefs.setString('user_name', userData['name'] ?? dummyName);
        await prefs.setString('user_role', userData['role'] ?? 'customer');
        await prefs.setString('access_token', token);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('مرحباً بعودتك السريعة يا ${userData['name'] ?? dummyName} 🎉', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF22C55E)),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslCustomerHomeScreen()));
      } else {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WaslSocialCompleteDataScreen(
              name: dummyName,
              email: dummyEmail,
              provider: provider,
              firebaseUid: dummyUid,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(check['message'] ?? 'فشلت عملية الدخول الاجتماعي', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
      );
    }
  }

  void _handleLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء كافة الحقول', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    String cleanPhone = _phoneController.text.trim();
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    String fullPhone = '+$_selectedCountryCode$cleanPhone';

    final result = await FlutterAuthService().login(
      phone: fullPhone,
      password: _passwordController.text,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      final data = result['data'];
      final userData = data['user'];
      final String token = data['token'] ?? '';

      final int realUserId = int.tryParse(userData['id']?.toString() ?? '') ?? 0;
      final String name = userData['name'] ?? 'مستخدم فلاش';
      final String phone = userData['phone'] ?? fullPhone;
      final String role = userData['role'] ?? 'customer';
      final String status = userData['status'] ?? 'active';

      if (role == 'merchant') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏪 عذراً، لوحة تحكم المتاجر قيد التجهيز وستتوفر في التحديث القادم!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Provider.of<UserProvider>(context, listen: false).saveUserSession(
        id: realUserId,
        name: name,
        phone: phone,
        role: role,
        token: token,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', realUserId);
      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_role', role);
      await prefs.setString('access_token', token);

      if (role == 'delivery') {
        if (status == 'pending' || status == 'rejected') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => WaslPendingScreen(
                phone: phone,
                role: role,
                initialNotes: userData['adminNotes'] ?? 'جاري مراجعة حسابك من قِبل إدارة وصل.',
              ),
            ),
          );
          return;
        }
      }

      if (role == 'delivery') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تسجيل دخولك بنجاح يا كابتن $name 🚀', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF16A34A)),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslDriverHomeScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('مرحباً بك في فلاش توصيل $name 🎉', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF16A34A)),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslCustomerHomeScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'بيانات الدخول غير صحيحة', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 6))
                      ],
                    ),
                    child: Image.asset(
                      'images/wasal_logo_new.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.flash_on_rounded, size: 40, color: Colors.white),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'فلاش توصيل • FLASH',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Cairo', letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'أدخل بيانات حسابك اللوجستي للمتابعة السريعة',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                      boxShadow: [
                        BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 15, offset: const Offset(0, 6))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('رقم الجوال'),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                  decoration: InputDecoration(
                                    fillColor: AppColors.background,
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    hintText: '1xxxxxxxxx',
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  showPhoneCode: true,
                                  countryListTheme: CountryListThemeData(borderRadius: BorderRadius.circular(24), bottomSheetHeight: 500),
                                  onSelect: (Country country) {
                                    setState(() {
                                      _selectedCountryCode = country.phoneCode;
                                      _selectedCountryFlag = country.flagEmoji;
                                    });
                                  },
                                );
                              },
                              child: Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    // 🎯 [تم الإصلاح]: الخاصية الصحيحة للاتجاه هي textDirection بدون إضافات خفية
                                    Text(
                                        '$_selectedCountryFlag +$_selectedCountryCode',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                        textDirection: TextDirection.ltr
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('كلمة المرور'),
                            GestureDetector(
                              // 🎯 [تم الإصلاح]: التوجيه السليم لشاشة استعادة كلمة المرور الرسمية المتاحة لديك
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslForgotPasswordScreen())),
                              child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 50,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textAlign: TextAlign.left,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              fillColor: AppColors.background,
                              filled: true,
                              prefixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textSecondary),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        InkWell(
                          onTap: _handleLogin,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: AppColors.logoGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('تسجيل الدخول', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                SizedBox(width: 6),
                                Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: const [
                      Expanded(child: Divider(color: Color(0xFFF1F5F9), endIndent: 10, thickness: 1.5)),
                      Text('أو سجل سريعاً عبر', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      Expanded(child: Divider(color: Color(0xFFF1F5F9), indent: 10, thickness: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _handleSocialLogin('facebook'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 64,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _handleSocialLogin('email'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 64,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.mail_outline_rounded, color: Color(0xFF64748B), size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('ليس لديك حساب؟ ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.w500)),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslRegisterScreen())),
                        child: const Text('إنشاء حساب جديد', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
    );
  }
}