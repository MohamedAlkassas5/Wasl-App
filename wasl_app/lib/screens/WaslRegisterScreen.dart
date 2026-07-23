// import 'package:flutter/material.dart';
// import 'package:country_picker/country_picker.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:wasl_app/screens/WaslLoginScreen.dart';
// import 'package:wasl_app/screens/WaslOtpScreen.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/core/providers/user_provider.dart';
// import 'package:wasl_app/services/auth_service.dart';
// import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';
// import 'package:wasl_app/customer_screen/screens/auth/WaslSocialCompleteDataScreen.dart';
//
// class WaslRegisterScreen extends StatefulWidget {
//   const WaslRegisterScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslRegisterScreen> createState() => _WaslRegisterScreenState();
// }
//
// class _WaslRegisterScreenState extends State<WaslRegisterScreen> {
//   String _selectedCountryCode = '20';
//   String _selectedCountryFlag = '🇪🇬';
//   int _currentRoleIndex = 0;
//
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _confirmPasswordController = TextEditingController();
//
//   int _passwordStrength = 0;
//   bool _obscurePassword = true;
//   bool _obscureConfirmPassword = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _passwordController.addListener(() {
//       setState(() {
//         _passwordStrength = _checkPasswordStrength(_passwordController.text);
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _nameController.dispose();
//     _phoneController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }
//
//   int _checkPasswordStrength(String password) {
//     if (password.isEmpty) return 0;
//     int points = 0;
//     if (password.length >= 8) points++;
//     if (password.contains(RegExp(r'[A-Z]'))) points++;
//     if (password.contains(RegExp(r'[0-9]'))) points++;
//     if (password.contains(RegExp(r'[!@#\$&*~.+-/\\=_]'))) points++;
//     return points;
//   }
//
//   // 🎯 الدالة الذكية المحدثة لطلب الـ OTP الحي من Firebase وتمرير الـ VerificationId لشاشة الـ OTP
//   void _handleRegistrationNext() async {
//     if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _passwordController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('يرجى ملء الحقول الأساسية للمتابعة', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
//       );
//       return;
//     }
//     if (_passwordController.text != _confirmPasswordController.text) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('كلمات المرور غير متطابقة', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
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
//     String role = _currentRoleIndex == 0 ? 'customer' : _currentRoleIndex == 1 ? 'delivery' : 'merchant';
//     String cleanPhone = _phoneController.text.trim();
//     if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
//     String fullPhone = '+$_selectedCountryCode$cleanPhone';
//
//     // 🔥 طلب الـ OTP الحي من Firebase
//     await FlutterAuthService().sendFirebaseOtp(
//       phone: fullPhone,
//       onCodeSent: (String verificationId) {
//         Navigator.pop(context); // إغلاق الـ Loading
//
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => WaslOtpScreen(
//               currentRoleIndex: _currentRoleIndex,
//               name: _nameController.text.trim(),
//               phone: fullPhone,
//               password: _passwordController.text,
//               role: role,
//               verificationId: verificationId,
//             ),
//           ),
//         );
//       },
//       onFailed: (FirebaseAuthException e) {
//         Navigator.pop(context); // إغلاق الـ Loading
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('فشل إرسال الرمز: ${e.message}', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
//         );
//       },
//     );
//   }
//
//   // 🎯 2️⃣ ثانياً: معالجة التسجيل وفحص الحساب الاجتماعي المباشر عبر الباك إند NestJS
//   void _handleRegisterSocial(String provider) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
//     );
//
//     // 📡 محاكاة جلب البيانات الموثقة من SDK فيسبوك أو جوجل
//     await Future.delayed(const Duration(seconds: 1));
//     if (!mounted) return;
//     Navigator.pop(context); // إغلاق الـ Loading
//
//     String dummyEmail = provider == 'facebook' ? 'ahmed_fb@wasl.com' : 'ahmed_google@wasl.com';
//     String dummyName = provider == 'facebook' ? 'Ahmed Harfoush (FB)' : 'Ahmed Talaat';
//     String dummyUid = 'social_firebase_uid_123456';
//
//     // 🔍 الفحص اللحظي والدخول التلقائي السريع بدون طلب OTP
//     final check = await FlutterAuthService().socialLoginCheck(email: dummyEmail, firebaseUid: dummyUid);
//
//     if (check['success'] == true) {
//       if (check['isRegistered'] == true) {
//         final data = check['data'];
//         final userData = data['user'];
//         final String token = data['token'] ?? '';
//
//         if (!mounted) return;
//         Provider.of<UserProvider>(context, listen: false).saveUserSession(
//           id: userData['id'] ?? 0,
//           name: userData['name'] ?? dummyName,
//           phone: userData['phone'] ?? '',
//           role: userData['role'] ?? 'customer',
//           token: token,
//         );
//
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setInt('user_id', userData['id'] ?? 0);
//         await prefs.setString('user_name', userData['name'] ?? dummyName);
//         await prefs.setString('access_token', token);
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('مرحباً بعودتك السريعة يا ${userData['name'] ?? dummyName} 🎉', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: const Color(0xFF22C55E)),
//         );
//         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslCustomerHomeScreen()));
//       } else {
//         // إذا كان الحساب جديداً، يتم نقله لاستكمال البيانات الأساسية مثل الهاتف ونوع الحساب
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
//         SnackBar(content: Text(check['message'] ?? 'فشل الاتصال الموثق الاجتماعي', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
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
//             physics: const BouncingScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
//             child: Column(
//               children: [
//                 const SizedBox(height: 10),
//                 Center(
//                   child: Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, boxShadow: [
//                       BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
//                     ]),
//                     child: const Icon(Icons.bolt_rounded, size: 42, color: AppColors.primary),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 const Text('منصة فلاش اللوجستية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                 const SizedBox(height: 6),
//                 const Text('سوق التوصيل المحلي الأسرع والأكثر أماناً', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontFamily: 'Cairo')),
//                 const SizedBox(height: 32),
//                 Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(16)),
//                   child: Row(
//                     children: [
//                       _buildRoleTab(0, 'عميل', Icons.person_rounded),
//                       _buildRoleTab(1, 'مندوب', Icons.delivery_dining_rounded),
//                       _buildRoleTab(2, 'متجر', Icons.storefront_rounded),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 Container(
//                   padding: const EdgeInsets.all(24),
//                   decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(24), boxShadow: [
//                     BoxShadow(color: AppColors.textPrimary.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))
//                   ]),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         _currentRoleIndex == 0 ? 'إنشاء حساب عميل جديد' : _currentRoleIndex == 1 ? 'انضمام كشريك توصيل محترف' : 'تسجيل منشأة تجارية شريكة',
//                         style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//                       ),
//                       const SizedBox(height: 24),
//                       _buildLabel('الاسم الكامل'),
//                       _buildInputField('أحمد محمد عصام', Icons.person_outline_rounded, false, _nameController),
//                       const SizedBox(height: 18),
//                       _buildLabel('رقم الجوال'),
//                       _buildPhoneField(),
//                       const SizedBox(height: 18),
//                       _buildLabel('كلمة المرور'),
//                       _buildInputField('••••••••', Icons.lock_outline_rounded, true, _passwordController, obscure: _obscurePassword, onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
//                       _buildStrengthBar(),
//                       const SizedBox(height: 18),
//                       _buildLabel('تأكيد كلمة المرور'),
//                       _buildInputField('••••••••', Icons.lock_outline_rounded, true, _confirmPasswordController, obscure: _obscureConfirmPassword, onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
//                       const SizedBox(height: 32),
//                       GestureDetector(
//                         onTap: _handleRegistrationNext,
//                         child: Container(
//                           height: 56,
//                           decoration: BoxDecoration(
//                             gradient: AppColors.logoGradient,
//                             borderRadius: BorderRadius.circular(16),
//                             boxShadow: [
//                               BoxShadow(color: AppColors.primary.withOpacity(0.24), blurRadius: 16, offset: const Offset(0, 6))
//                             ],
//                           ),
//                           child: Center(
//                             child: Text(
//                               _currentRoleIndex == 0 ? 'تأكيد وإنشاء الحساب' : 'التالي والمتابعة ➔',
//                               style: const TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       // 🎯 إضافة مصفوفة أزرار الترحيل الاجتماعي لفيسبوك والبريد الإلكتروني الموحد
//                       const SizedBox(height: 24),
//                       Row(
//                         children: const [
//                           Expanded(child: Divider(color: Color(0xFFCBD5E1), endIndent: 10)),
//                           Text('أو سجل سريعاً عبر', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
//                           Expanded(child: Divider(color: Color(0xFFCBD5E1), indent: 10)),
//                         ],
//                       ),
//                       const SizedBox(height: 16),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               onPressed: () => _handleRegisterSocial('facebook'),
//                               icon: const Icon(Icons.facebook, color: Colors.white, size: 20),
//                               label: const Text('فيسبوك', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFF1877F2),
//                                 minimumSize: const Size.fromHeight(48),
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                                 elevation: 0,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               onPressed: () => _handleRegisterSocial('email'),
//                               icon: const Icon(Icons.email_outlined, color: AppColors.textPrimary, size: 20),
//                               label: const Text('البريد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: AppColors.white,
//                                 minimumSize: const Size.fromHeight(48),
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                                 side: const BorderSide(color: Color(0xFFE2E8F0)),
//                                 elevation: 0,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 24),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Text('لديك حساب بالفعل؟ ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Cairo')),
//                           GestureDetector(
//                             onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslLoginScreen())),
//                             child: const Text('تسجيل الدخول', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
//                           ),
//                         ],
//                       )
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRoleTab(int index, String label, IconData icon) {
//     bool isSelected = _currentRoleIndex == index;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => setState(() => _currentRoleIndex = index),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.fastOutSlowIn,
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           decoration: BoxDecoration(gradient: isSelected ? AppColors.logoGradient : null, borderRadius: BorderRadius.circular(12)),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 18, color: isSelected ? AppColors.white : AppColors.textSecondary),
//               const SizedBox(width: 6),
//               Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? AppColors.white : AppColors.textSecondary, fontFamily: 'Cairo')),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLabel(String text) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
//       child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//     );
//   }
//
//   Widget _buildInputField(String hint, IconData icon, bool isPass, TextEditingController controller, {bool obscure = false, VoidCallback? onToggle}) {
//     return SizedBox(
//       height: 54,
//       child: TextField(
//         controller: controller,
//         obscureText: isPass ? obscure : false,
//         textAlign: isPass ? TextAlign.left : TextAlign.right,
//         style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
//         decoration: InputDecoration(
//           hintText: hint,
//           hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
//           fillColor: AppColors.background,
//           filled: true,
//           prefixIcon: isPass
//               ? IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textSecondary), onPressed: onToggle)
//               : Icon(icon, size: 20, color: AppColors.textSecondary),
//           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPhoneField() {
//     return Row(
//       children: [
//         Expanded(
//           child: SizedBox(
//             height: 54,
//             child: TextField(
//               controller: _phoneController,
//               keyboardType: TextInputType.phone,
//               textAlign: TextAlign.left,
//               style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
//               decoration: InputDecoration(
//                 fillColor: AppColors.background,
//                 filled: true,
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
//                 hintText: '5xxxxxxxxx',
//                 hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 16),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         GestureDetector(
//           onTap: () {
//             showCountryPicker(
//               context: context,
//               countryListTheme: CountryListThemeData(borderRadius: BorderRadius.circular(20), bottomSheetHeight: 500),
//               onSelect: (Country c) => setState(() {
//                 _selectedCountryCode = c.phoneCode;
//                 _selectedCountryFlag = c.flagEmoji;
//               }),
//             );
//           },
//           child: Container(
//             height: 54,
//             padding: const EdgeInsets.symmetric(horizontal: 14),
//             decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0), width: 1)),
//             child: Row(
//               children: [
//                 const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
//                 const SizedBox(width: 4),
//                 Text('$_selectedCountryFlag +$_selectedCountryCode', textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
//               ],
//             ),
//           ),
//         )
//       ],
//     );
//   }
//
//   Widget _buildStrengthBar() {
//     if (_passwordStrength == 0) return const SizedBox(height: 4);
//     bool isStrong = _passwordStrength >= 3;
//     return Padding(
//       padding: const EdgeInsets.only(top: 8.0, right: 4.0),
//       child: Row(
//         children: [
//           Icon(isStrong ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 14, color: isStrong ? AppColors.success : AppColors.danger),
//           const SizedBox(width: 6),
//           Text(isStrong ? 'كلمة مرور قوية ومؤمنة تماماً 🟢' : 'كلمة المرور ضعيفة (استخدم أرقام وحروف كبيرة) 🔴', style: TextStyle(fontSize: 12, color: isStrong ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';
import 'package:wasl_app/screens/WaslOtpScreen.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/providers/user_provider.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';
import 'package:wasl_app/customer_screen/screens/auth/WaslSocialCompleteDataScreen.dart';

class WaslRegisterScreen extends StatefulWidget {
  const WaslRegisterScreen({Key? key}) : super(key: key);

  @override
  State<WaslRegisterScreen> createState() => _WaslRegisterScreenState();
}

class _WaslRegisterScreenState extends State<WaslRegisterScreen> {
  String _selectedCountryCode = '20';
  String _selectedCountryFlag = '🇪🇬';
  int _currentRoleIndex = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  int _passwordStrength = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() {
        _passwordStrength = _checkPasswordStrength(_passwordController.text);
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _checkPasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int points = 0;
    if (password.length >= 8) points++;
    if (password.contains(RegExp(r'[A-Z]'))) points++;
    if (password.contains(RegExp(r'[0-9]'))) points++;
    if (password.contains(RegExp(r'[!@#\$&*~.+-/\\=_]'))) points++;
    return points;
  }

  // 🎯 طلب الـ OTP الحي من Firebase وتمرير الـ VerificationId لشاشة الـ OTP
  void _handleRegistrationNext() async {
    if (_currentRoleIndex == 2) {
      _showMerchantBlockSnackBar();
      return;
    }

    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء الحقول الأساسية للمتابعة', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمات المرور غير متطابقة', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    String role = _currentRoleIndex == 0 ? 'customer' : 'delivery';
    String cleanPhone = _phoneController.text.trim();
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    String fullPhone = '+$_selectedCountryCode$cleanPhone';

    await FlutterAuthService().sendFirebaseOtp(
      phone: fullPhone,
      onCodeSent: (String verificationId) {
        Navigator.pop(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WaslOtpScreen(
              currentRoleIndex: _currentRoleIndex,
              name: _nameController.text.trim(),
              phone: fullPhone,
              password: _passwordController.text,
              role: role,
              verificationId: verificationId,
            ),
          ),
        );
      },
      onFailed: (FirebaseAuthException e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال الرمز: ${e.message}', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      },
    );
  }

  // 🎯 معالجة التسجيل وفحص الحساب الاجتماعي المباشر عبر الباك إند NestJS
  void _handleRegisterSocial(String provider) async {
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

        if (!mounted) return;
        Provider.of<UserProvider>(context, listen: false).saveUserSession(
          id: userData['id'] ?? 0,
          name: userData['name'] ?? dummyName,
          phone: userData['phone'] ?? '',
          role: userData['role'] ?? 'customer',
          token: token,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userData['id'] ?? 0);
        await prefs.setString('user_name', userData['name'] ?? dummyName);
        await prefs.setString('user_phone', userData['phone'] ?? '');
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
        SnackBar(content: Text(check['message'] ?? 'فشل الاتصال الموثق الاجتماعي', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showMerchantBlockSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Store registration is currently disabled and will open in the next update! 🏪', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMerchantLocked = _currentRoleIndex == 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
                    ]),
                    child: const Icon(Icons.bolt_rounded, size: 42, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('منصة فلاش اللوجستية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Cairo', letterSpacing: -0.5)),
                const SizedBox(height: 2),
                const Text('سوق التوصيل المحلي الأسرع والأكثر أماناً', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontFamily: 'Cairo')),
                const SizedBox(height: 28),

                // 🧱 أزرار التبويبات الثلاثية
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      _buildRoleTab(0, 'عميل', Icons.person_rounded),
                      _buildRoleTab(1, 'مندوب', Icons.delivery_dining_rounded),
                      _buildRoleTab(2, 'متجر 🔒', Icons.storefront_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                    boxShadow: [
                      BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentRoleIndex == 0
                            ? 'إنشاء حساب عميل جديد'
                            : _currentRoleIndex == 1
                            ? 'انضمام كشريك توصيل محترف'
                            : 'سجل منشأتك (قيد التجهيز والتطوير)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('الاسم الكامل'),
                      _buildInputField('أحمد محمد عصام', Icons.person_outline_rounded, false, _nameController),
                      const SizedBox(height: 18),
                      _buildLabel('رقم الجوال'),
                      _buildPhoneField(),
                      const SizedBox(height: 18),
                      _buildLabel('كلمة المرور'),
                      _buildInputField('••••••••', Icons.lock_outline_rounded, true, _passwordController, obscure: _obscurePassword, onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
                      _buildStrengthBar(),
                      const SizedBox(height: 18),
                      _buildLabel('تأكيد كلمة المرور'),
                      _buildInputField('••••••••', Icons.lock_outline_rounded, true, _confirmPasswordController, obscure: _obscureConfirmPassword, onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                      const SizedBox(height: 32),

                      InkWell(
                        onTap: isMerchantLocked ? _showMerchantBlockSnackBar : _handleRegistrationNext,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: isMerchantLocked ? null : AppColors.logoGradient,
                            color: isMerchantLocked ? Colors.grey.shade300 : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (!isMerchantLocked)
                                BoxShadow(color: AppColors.primary.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isMerchantLocked
                                  ? '🔒 التسجيل معلق حالياً'
                                  : (_currentRoleIndex == 0 ? 'تأكيد وإنشاء الحساب' : 'التالي والمتابعة ➔'),
                              style: TextStyle(
                                  fontSize: 15,
                                  color: isMerchantLocked ? Colors.grey.shade600 : AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo'
                              ),
                            ),
                          ),
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
                            onTap: () => _handleRegisterSocial('facebook'),
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
                            onTap: () => _handleRegisterSocial('email'),
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
                          const Text('لديك حساب بالفعل؟ ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.w500)),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslLoginScreen())),
                            child: const Text('تسجيل الدخول', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(int index, String label, IconData icon) {
    bool isSelected = _currentRoleIndex == index;
    return Expanded(
      child: GestureDetector(
        // 🎯 [تم الإصلاح]: استدعاء اسم الميثود الصحيح المتوافق مع الكلاس _showMerchantBlockSnackBar
        onTap: () {
          setState(() => _currentRoleIndex = index);
          if (index == 2) _showMerchantBlockSnackBar();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              gradient: isSelected ? AppColors.logoGradient : null,
              borderRadius: BorderRadius.circular(12)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                  label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.white : AppColors.textSecondary,
                      fontFamily: 'Cairo'
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, right: 4.0),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
    );
  }

  Widget _buildInputField(String hint, IconData icon, bool isPass, TextEditingController controller, {bool obscure = false, VoidCallback? onToggle}) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        obscureText: isPass ? obscure : false,
        textAlign: isPass ? TextAlign.left : TextAlign.right,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          fillColor: AppColors.background,
          filled: true,
          prefixIcon: isPass
              ? IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textSecondary), onPressed: onToggle)
              : Icon(icon, size: 18, color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                fillColor: AppColors.background,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                hintText: '5xxxxxxxxx',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            showCountryPicker(
              context: context,
              countryListTheme: CountryListThemeData(borderRadius: BorderRadius.circular(24), bottomSheetHeight: 500),
              onSelect: (Country c) => setState(() {
                _selectedCountryCode = c.phoneCode;
                _selectedCountryFlag = c.flagEmoji;
              }),
            );
          },
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)),
            child: Row(
              children: [
                const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('$_selectedCountryFlag +$_selectedCountryCode', textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildStrengthBar() {
    if (_passwordStrength == 0) return const SizedBox(height: 4);
    bool isStrong = _passwordStrength >= 3;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, right: 4.0),
      child: Row(
        children: [
          Icon(isStrong ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 14, color: isStrong ? AppColors.success : AppColors.danger),
          const SizedBox(width: 6),
          Text(isStrong ? 'كلمة مرور قوية ومؤمنة تماماً 🟢' : 'كلمة المرور ضعيفة (استخدم أرقام وحروف كبيرة) 🔴', style: TextStyle(fontSize: 11, color: isStrong ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}