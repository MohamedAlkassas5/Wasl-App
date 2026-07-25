// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:wasl_app/screens/WaslDeliveryIdentityScreen.dart';
// import 'package:wasl_app/screens/WaslMerchantRegisterScreen.dart';
// import 'package:wasl_app/customer_screen/screens/auth/WaslResetPasswordScreen.dart';
// import 'package:wasl_app/services/auth_service.dart';
// // 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
// import 'package:wasl_app/core/theme/app_colors.dart';
//
// class WaslOtpScreen extends StatefulWidget {
//   final int currentRoleIndex;
//   final String? name;
//   final String? phone;
//   final String? password;
//   final String? role;
//   final bool isFromForgotPassword;
//
//   const WaslOtpScreen({
//     Key? key,
//     this.currentRoleIndex = 0,
//     this.name,
//     this.phone,
//     this.password,
//     this.role,
//     this.isFromForgotPassword = false,
//   }) : super(key: key);
//
//   @override
//   State<WaslOtpScreen> createState() => _WaslOtpScreenState();
// }
//
// class _WaslOtpScreenState extends State<WaslOtpScreen> {
//   Timer? _timer;
//   int _startSeconds = 58;
//   bool _canResend = false;
//   final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
//
//   @override
//   void initState() { super.initState(); _startTimer(); }
//
//   @override
//   void dispose() { _timer?.cancel(); for (var c in _controllers) { c.dispose(); } super.dispose(); }
//
//   void _startTimer() {
//     setState(() { _startSeconds = 58; _canResend = false; });
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_startSeconds == 0) { setState(() { _timer?.cancel(); _canResend = true; }); }
//       else { setState(() { _startSeconds--; }); }
//     });
//   }
//
//   void _verifyOtpAndProceed() async {
//     String code = _controllers.map((c) => c.text).join();
//     if (code.length < 4) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text('يرجى إدخال الرمز كاملاً', style: TextStyle(fontFamily: 'Cairo')),
//             backgroundColor: AppColors.danger
//         ),
//       );
//       return;
//     }
//
//     if (widget.isFromForgotPassword) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const WaslResetPasswordScreen()),
//       );
//       return;
//     }
//
//     if (widget.currentRoleIndex == 0) {
//       showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary))
//       );
//
//       final result = await FlutterAuthService().register(
//         name: widget.name ?? '',
//         phone: widget.phone ?? '',
//         password: widget.password ?? '',
//         role: widget.role ?? 'customer',
//       );
//       if (!mounted) return;
//       Navigator.pop(context);
//
//       if (result['success']) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text('تم إنشاء حساب العميل بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo')),
//               backgroundColor: Color(0xFF22C55E)
//           ),
//         );
//         Navigator.of(context).popUntil((route) => route.isFirst);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text(result['message'] ?? 'حدث خطأ أثناء التسجيل', style: const TextStyle(fontFamily: 'Cairo')),
//               backgroundColor: AppColors.danger
//           ),
//         );
//       }
//     } else if (widget.currentRoleIndex == 1) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslDeliveryIdentityScreen(name: widget.name, phone: widget.phone, password: widget.password, role: widget.role)));
//     } else if (widget.currentRoleIndex == 2) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslMerchantRegisterScreen(name: widget.name, phone: widget.phone, password: widget.password, role: widget.role)));
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     String stepText = widget.currentRoleIndex == 0 ? "الخطوة ٢ من ٢" : "الخطوة ٢ من ٣";
//     double progress = widget.currentRoleIndex == 0 ? 1.0 : 0.66;
//
//     if (widget.isFromForgotPassword) {
//       stepText = "التحقق الآمن";
//       progress = 0.5;
//     }
//
//     return Scaffold(
//       backgroundColor: AppColors.background, // 🎯 تحديث اللون لـ FLASH
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               children: [
//                 Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text('التحقق من الهاتف', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
//                       Text(stepText, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
//                     ]
//                 ),
//                 const SizedBox(height: 8),
//                 LinearProgressIndicator(value: progress, backgroundColor: const Color(0xFFE5E5E5), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
//                 const SizedBox(height: 40),
//
//                 // 🎯 الأيقونة العلوية محاطة بخلفية التدرج لـ FLASH
//                 Container(
//                   width: 90, height: 90,
//                   decoration: BoxDecoration(
//                       gradient: AppColors.logoGradient,
//                       borderRadius: BorderRadius.circular(24),
//                       boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
//                   ),
//                   child: const Icon(Icons.mark_email_read_outlined, size: 44, color: AppColors.white),
//                 ),
//                 const SizedBox(height: 24),
//
//                 Container(
//                   padding: const EdgeInsets.all(24),
//                   decoration: BoxDecoration(
//                       color: AppColors.white,
//                       borderRadius: BorderRadius.circular(24),
//                       boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 15, offset: const Offset(0, 6))]
//                   ),
//                   child: Column(
//                     children: [
//                       const Text('كود التحقق الخاص بك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                       const SizedBox(height: 8),
//                       const Text('أدخل الرمز المكون من 4 أرقام المولد للمحاكاة بنجاح', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
//                       const SizedBox(height: 28),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: List.generate(4, (index) => _buildOtpBox(index)),
//                       ),
//                       const SizedBox(height: 32),
//                       _canResend
//                           ? GestureDetector(onTap: _startTimer, child: const Text('إعادة إرسال الرمز الآن', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', decoration: TextDecoration.underline)))
//                           : Text('إعادة إرسال خلال ${_startSeconds.toString().padLeft(2, '0')} ثانية', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                       const SizedBox(height: 32),
//
//                       // 🎯 زر التأكيد المتجانس مع الـ Gradient الموحد والـ const المصلح
//                       GestureDetector(
//                         onTap: _verifyOtpAndProceed,
//                         child: Container(
//                           height: 54,
//                           decoration: BoxDecoration(
//                             gradient: AppColors.logoGradient,
//                             borderRadius: BorderRadius.circular(14),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: AppColors.primary.withOpacity(0.24),
//                                 blurRadius: 16,
//                                 offset: const Offset(0, 6),
//                               )
//                             ],
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: const [
//                               Text(
//                                 'تأكيد الرمز والمتابعة',
//                                 style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
//                               ),
//                               SizedBox(width: 8),
//                               Icon(Icons.bolt, color: AppColors.white, size: 20),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildOtpBox(int index) {
//     return SizedBox(
//       width: 54, height: 54,
//       child: TextField(
//         controller: _controllers[index], autofocus: index == 0,
//         onChanged: (v) { if (v.length == 1 && index < 3) FocusScope.of(context).nextFocus(); if (v.isEmpty && index > 0) FocusScope.of(context).previousFocus(); },
//         showCursor: false, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
//         keyboardType: TextInputType.number, inputFormatters: [LengthLimitingTextInputFormatter(1), FilteringTextInputFormatter.digitsOnly],
//         decoration: InputDecoration(
//             fillColor: AppColors.background,
//             filled: true,
//             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 1.5)),
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
//         ),
//       ),
//     );
//   }
// }





import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/providers/user_provider.dart';
import 'package:wasl_app/screens/WaslDeliveryIdentityScreen.dart';
import 'package:wasl_app/screens/WaslMerchantRegisterScreen.dart';
import 'package:wasl_app/customer_screen/screens/auth/WaslResetPasswordScreen.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/core/theme/app_colors.dart';

class WaslOtpScreen extends StatefulWidget {
  final int currentRoleIndex;
  final String? name;
  final String? phone;
  final String? password;
  final String? role;
  final bool isFromForgotPassword;
  final String? verificationId; // 🎯 متغير الـ ID الجديد القادم من فايربيز

  const WaslOtpScreen({
    Key? key,
    this.currentRoleIndex = 0,
    this.name,
    this.phone,
    this.password,
    this.role,
    this.isFromForgotPassword = false,
    this.verificationId, // 🎯 استقبال الـ verificationId هنا
  }) : super(key: key);

  @override
  State<WaslOtpScreen> createState() => _WaslOtpScreenState();
}

class _WaslOtpScreenState extends State<WaslOtpScreen> {
  Timer? _timer;
  int _startSeconds = 58;
  bool _canResend = false;

  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final FlutterAuthService _authService = FlutterAuthService();

  @override
  void initState() { super.initState(); _startTimer(); }

  @override
  void dispose() { _timer?.cancel(); for (var c in _controllers) { c.dispose(); } super.dispose(); }

  void _startTimer() {
    setState(() { _startSeconds = 58; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds == 0) { setState(() { _timer?.cancel(); _canResend = true; }); }
      else { setState(() { _startSeconds--; }); }
    });
  }

  // 🎯 الدالة اللوجستية المحدثة بالربط الهجين (Firebase + NestJS)
  void _verifyOtpAndProceed() async {
    String code = _controllers.map((c) => c.text).join();

    if (code.length < 6) {
      _showSnackBar('يرجى إدخال كود التحقق المكون من 6 أرقام كاملاً', AppColors.danger);
      return;
    }

    // إظهار مؤشر تحميل (Loading) لمنع النقرات العشوائية المتكررة
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    // 📡 استدعاء دالة التحقق والدخول الهجينة الجديدة (تتحقق من فايربيز أولاً ثم ترحل الحساب لـ NestJS)
    final result = await _authService.verifyOtpAndRegisterInNest(
      verificationId: widget.verificationId ?? '',
      smsCode: code,
      name: widget.name ?? '',
      phone: widget.phone ?? '',
      password: widget.password ?? '',
      role: widget.role ?? 'customer',
      // ملحوظة: حقول الملفات والصور سيتم رفعها في الخطوات التالية للمناديب والمتاجر
    );

    if (!mounted) return;
    Navigator.pop(context); // إغلاق الـ Loading

    if (result['success'] == true) {
      if (widget.isFromForgotPassword) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaslResetPasswordScreen()));
        return;
      }

      final data = result['data'];
      final userData = data['user'];
      final String token = data['token'] ?? '';

      // إذا كان الحساب "عميل"، تنتهي دائرته اللوجستية هنا ويتم حفظ جلسته فوراً ودخوله للتطبيق
      if (widget.currentRoleIndex == 0) {
        // الحفظ الديناميكي لبيانات العميل بالـ Provider لمنع الـ IDs الثابتة
        Provider.of<UserProvider>(context, listen: false).saveUserSession(
          id: userData['id'] ?? 0,
          name: userData['name'] ?? widget.name,
          phone: userData['phone'] ?? widget.phone,
          role: userData['role'] ?? 'customer',
          token: token,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userData['id'] ?? 0);
        await prefs.setString('user_name', userData['name'] ?? widget.name ?? '');
        await prefs.setString('user_phone', userData['phone'] ?? widget.phone ?? '');
        await prefs.setString('user_role', userData['role'] ?? 'customer');
        await prefs.setString('access_token', token);

        _showSnackBar('تم إنشاء حساب العميل بنجاح! 🎉', const Color(0xFF22C55E));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // إذا كان مندوب أو متجر، نمررهم للمراحل التالية لرفع المستندات (مع تمرير البيانات الموثقة الراجعة)
      else if (widget.currentRoleIndex == 1) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslDeliveryIdentityScreen(name: widget.name, phone: widget.phone, password: widget.password, role: widget.role)));
      } else if (widget.currentRoleIndex == 2) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslMerchantRegisterScreen(name: widget.name, phone: widget.phone, password: widget.password, role: widget.role)));
      }
    } else {
      // 🛑 الكود خاطئ أو فشل السيرفر! السيستم يرفض التمرير ويقفل مكانه لحماية الحساب
      _showSnackBar(result['message'] ?? 'كود التحقق غير صحيح، راجع الرسائل النصية الخاصة بك', AppColors.danger);
    }
  }

  void _showSnackBar(String text, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String stepText = widget.currentRoleIndex == 0 ? "الخطوة ٢ من ٢" : "الخطوة ٢ من ٣";
    double progress = widget.currentRoleIndex == 0 ? 1.0 : 0.66;

    if (widget.isFromForgotPassword) {
      stepText = "التحقق الآمن";
      progress = 0.5;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('التحقق من الهاتف', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
                      Text(stepText, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
                    ]
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress, backgroundColor: const Color(0xFFE5E5E5), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
                const SizedBox(height: 40),
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(24), boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
                  ]),
                  child: const Icon(Icons.mark_email_read_outlined, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(24), boxShadow: [
                    BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 15, offset: const Offset(0, 6))
                  ]),
                  child: Column(
                    children: [
                      const Text('كود التحقق الخاص بك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      const SizedBox(height: 8),
                      const Text('أدخل الرمز المكون من 6 أرقام المرسل إلى هاتف الجوال الخاص بك للتحقق', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                      const SizedBox(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) => _buildOtpBox(index)),
                      ),
                      const SizedBox(height: 32),
                      _canResend
                          ? GestureDetector(onTap: _startTimer, child: const Text('إعادة إرسال الرمز الآن', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', decoration: TextDecoration.underline)))
                          : Text('إعادة إرسال خلال ${_startSeconds.toString().padLeft(2, '0')} ثانية', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _verifyOtpAndProceed,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: AppColors.logoGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.24), blurRadius: 16, offset: const Offset(0, 6))
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('تأكيد الرمز والمتابعة', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              SizedBox(width: 8),
                              Icon(Icons.bolt, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44, height: 48,
      child: TextField(
        controller: _controllers[index], autofocus: index == 0,
        onChanged: (v) {
          if (v.length == 1 && index < 5) FocusScope.of(context).nextFocus();
          if (v.isEmpty && index > 0) FocusScope.of(context).previousFocus();
        },
        showCursor: false, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        keyboardType: TextInputType.number, inputFormatters: [LengthLimitingTextInputFormatter(1), FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
            fillColor: AppColors.background,
            filled: true,
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 1.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
        ),
      ),
    );
  }
}