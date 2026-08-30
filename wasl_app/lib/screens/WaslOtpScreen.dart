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
import 'package:wasl_app/services/push_service.dart';
import 'package:wasl_app/screens/WaslDeliveryIdentityScreen.dart';
import 'package:wasl_app/screens/WaslMerchantRegisterScreen.dart';
import 'package:wasl_app/customer_screen/screens/auth/WaslResetPasswordScreen.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/services/whatsapp_otp_service.dart';
import 'package:wasl_app/core/session/wasl_session.dart';
import 'package:wasl_app/core/theme/app_colors.dart';

/// Phone verification step. The code is generated, delivered and checked by the
/// backend (`/auth/otp/*`) — this screen only collects the digits. Nothing here
/// decides whether a phone is verified; the server does, and `/auth/register`
/// refuses any phone it hasn't cleared.
class WaslOtpScreen extends StatefulWidget {
  final int currentRoleIndex;
  final String? name;
  final String? phone;
  final String? password;
  final String? role;
  final bool isFromForgotPassword;

  /// The area the customer picked on the previous screen. Carried through
  /// because the account is only created here, once the code checks out.
  final int? customerZoneId;

  const WaslOtpScreen({
    Key? key,
    this.currentRoleIndex = 0,
    this.name,
    this.phone,
    this.password,
    this.role,
    this.isFromForgotPassword = false,
    this.customerZoneId,
  }) : super(key: key);

  @override
  State<WaslOtpScreen> createState() => _WaslOtpScreenState();
}

class _WaslOtpScreenState extends State<WaslOtpScreen> {
  Timer? _timer;
  int _startSeconds = 58;
  bool _canResend = false;
  bool _isBusy = false;

  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final FlutterAuthService _authService = FlutterAuthService();
  final WhatsappOtpService _otpService = WhatsappOtpService();

  @override
  void initState() { super.initState(); _startTimer(); }

  @override
  void dispose() { _timer?.cancel(); for (var c in _controllers) { c.dispose(); } super.dispose(); }

  void _startTimer() {
    _timer?.cancel();
    setState(() { _startSeconds = 58; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds == 0) { setState(() { _timer?.cancel(); _canResend = true; }); }
      else { setState(() { _startSeconds--; }); }
    });
  }

  // 🔁 الزرار ده كان بيصفّر العدّاد وبس من غير ما يطلب كود جديد من السيرفر.
  void _resendOtp() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final result = await _otpService.sendOtp(widget.phone ?? '');

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result['success'] == true) {
      for (final c in _controllers) { c.clear(); }
      _startTimer();
      _showSnackBar('تم إرسال رمز جديد عبر واتساب 📲', const Color(0xFF22C55E));
    } else {
      _showSnackBar(result['message'] ?? 'تعذّر إرسال رمز جديد', AppColors.danger);
    }
  }

  // 📡 التحقق بيتم على السيرفر: لو الكود صح، السيرفر بيفكّر الرقم كمُتحقَّق منه
  // لمدة محدودة، وبعدين التسجيل بيعدّي. لو الرقم له حساب بالفعل، السيرفر بيرجّع
  // توكن جاهز بدل ما نسجّل من جديد.
  void _verifyOtpAndProceed() async {
    if (_isBusy) return;

    String code = _controllers.map((c) => c.text).join();

    if (code.length < 6) {
      _showSnackBar('يرجى إدخال كود التحقق المكون من 6 أرقام كاملاً', AppColors.danger);
      return;
    }

    // إظهار مؤشر تحميل (Loading) لمنع النقرات العشوائية المتكررة
    setState(() => _isBusy = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final verification = await _otpService.verifyOtp(
      phone: widget.phone ?? '',
      code: code,
    );

    if (!mounted) return;

    if (verification['success'] != true) {
      Navigator.pop(context); // إغلاق الـ Loading
      setState(() => _isBusy = false);
      // 🛑 الكود خاطئ أو انتهت صلاحيته — السيستم يقفل مكانه ولا يمرّر أي حاجة
      _showSnackBar(verification['message'] ?? 'كود التحقق غير صحيح، راجع رسائل واتساب', AppColors.danger);
      return;
    }

    final bool alreadyRegistered = verification['data']?['registered'] == true;

    // 🔑 مسار استعادة كلمة المرور: الرقم اتأكد، نروح نحط كلمة مرور جديدة.
    // الكود بيتمرر معانا لأن السيرفر بيطلبه تاني مع كلمة المرور الجديدة.
    if (widget.isFromForgotPassword) {
      Navigator.pop(context); // إغلاق الـ Loading
      setState(() => _isBusy = false);

      if (!alreadyRegistered) {
        _showSnackBar('لا يوجد حساب مرتبط بهذا الرقم، أنشئ حساباً جديداً', AppColors.danger);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaslResetPasswordScreen(
            phone: widget.phone ?? '',
            code: code,
          ),
        ),
      );
      return;
    }

    // الرقم متسجل قبل كده — التسجيل هيترفض من السيرفر، فنوجّهه لتسجيل الدخول.
    if (alreadyRegistered) {
      Navigator.pop(context); // إغلاق الـ Loading
      setState(() => _isBusy = false);
      _showSnackBar('هذا الرقم مسجل بالفعل، سجّل الدخول بكلمة المرور', AppColors.danger);
      return;
    }

    // 🚚 المندوب والمتجر بيكمّلوا رفع المستندات الأول، والتسجيل بيحصل هناك —
    // التحقق صالح لنص ساعة فده وقت كفاية للخطوة اللي جاية.
    if (widget.currentRoleIndex != 0) {
      Navigator.pop(context); // إغلاق الـ Loading
      setState(() => _isBusy = false);

      if (widget.currentRoleIndex == 1) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslDeliveryIdentityScreen(name: widget.name, phone: widget.phone, password: widget.password, role: widget.role)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslMerchantRegisterScreen(name: widget.name, phone: widget.phone, password: widget.password, role: widget.role)));
      }
      return;
    }

    // 👤 العميل: مفيش مستندات، فالحساب بيتعمل هنا على طول
    final result = await _authService.register(
      name: widget.name ?? '',
      phone: widget.phone ?? '',
      password: widget.password ?? '',
      role: widget.role ?? 'customer',
      customerZoneId: widget.customerZoneId,
    );

    if (!mounted) return;
    Navigator.pop(context); // إغلاق الـ Loading
    setState(() => _isBusy = false);

    if (result['success'] != true) {
      _showSnackBar(result['message'] ?? 'تعذّر إنشاء الحساب، حاول مرة أخرى', AppColors.danger);
      return;
    }

    final data = result['data'];
    final userData = data['user'];
    final String token = data['token'] ?? '';

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
    // Both tokens, together — the fifteen-minute access token is useless on its
    // own once it expires, and this is a fresh signup that should not have to
    // sign in again before the user has placed an order.
    await const WaslSession().save(
      accessToken: token,
      refreshToken: data['refreshToken']?.toString(),
    );
    // 🔔 الجلسة بقت موجودة، يبقى ينفع نسجّل الجهاز للإشعارات.
    unawaited(WaslPushService.instance.start());
    // The server echoes back the area it actually stored, which may be null if
    // it rejected what we sent — trust its answer, not our own input.
    final int? savedZoneId = (userData['customerZoneId'] as num?)?.toInt();
    if (savedZoneId != null) {
      await prefs.setInt('customer_zone_id', savedZoneId);
    } else {
      await prefs.remove('customer_zone_id');
    }

    if (!mounted) return;
    _showSnackBar('تم إنشاء حساب العميل بنجاح! 🎉', const Color(0xFF22C55E));
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                      Text('أدخل الرمز المكون من 6 أرقام المرسل عبر واتساب إلى ${widget.phone ?? 'رقمك'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                      const SizedBox(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) => _buildOtpBox(index)),
                      ),
                      const SizedBox(height: 32),
                      _canResend
                          ? GestureDetector(onTap: _resendOtp, child: const Text('إعادة إرسال الرمز الآن', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', decoration: TextDecoration.underline)))
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