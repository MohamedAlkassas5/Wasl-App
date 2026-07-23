import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wasl_app/screens/WaslOtpScreen.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/auth_service.dart';

class WaslForgotPasswordScreen extends StatefulWidget {
  const WaslForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<WaslForgotPasswordScreen> createState() => _WaslForgotPasswordScreenState();
}

class _WaslForgotPasswordScreenState extends State<WaslForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryCode = '20';
  String _selectedCountryFlag = '🇪🇬';
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // 🎯 طلب الـ OTP الحي عبر فايربيز للتحقق الفعلي قبل إتاحة تحديث كلمة المرور
  void _submitForgotPassword() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم الجوال أولاً ⚠️', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    String cleanPhone = _phoneController.text.trim();
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    String fullPhone = '+$_selectedCountryCode$cleanPhone';

    // 🔥 طلب الـ OTP من Firebase لمسار نسيت كلمة المرور وتمريره للمنظومة
    await FlutterAuthService().sendFirebaseOtp(
      phone: fullPhone,
      onCodeSent: (String verificationId) {
        Navigator.pop(context); // إغلاق الـ Loading Dialog

        // الانتقال لشاشة الـ OTP وتأكيد مسار استعادة الحساب لإعادة التعيين لاحقاً
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WaslOtpScreen(
              phone: fullPhone,
              isFromForgotPassword: true, // إشارة لشاشة الـ OTP لتفعيل واجهة تحديث الباسورد بالـ Backend بعد التحقق
              verificationId: verificationId,
            ),
          ),
        );
      },
      onFailed: (FirebaseAuthException e) {
        Navigator.pop(context); // إغلاق الـ Loading Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الرمز: ${e.message}', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'استعادة الحساب',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16),
        ),
        centerTitle: true,
      ),
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
                  // ⚡ أيقونة إعادة التعيين فلات مدمجة بظلال ناعمة ومتناسقة
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 6))
                      ],
                    ),
                    child: const Icon(Icons.lock_reset_rounded, size: 44, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'نسيت كلمة المرور؟',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Cairo', letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'أدخل رقم الجوال المرتبط بحسابك لتلقي رمز التحقق اللحظي وبدء استعادة وتحديث كلمة المرور بآمان',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 💳 كارت التحقق الموحد بـ Borders ناعمة ومحاذاة منضبطة
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0, right: 4.0),
                          child: const Text(
                            'رقم الجوال للـحساب',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                          ),
                        ),
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
                                    Text(
                                      '$_selectedCountryFlag +$_selectedCountryCode',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // زر الإرسال الانسيابي المحدث المدعوم بالتدرج البصري والـ Shadows لـ فلاش
                        InkWell(
                          onTap: _isLoading ? null : _submitForgotPassword,
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('إرسال رمز التحقق الخلوي', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                SizedBox(width: 6),
                                Icon(Icons.send_rounded, color: Colors.white, size: 16),
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
      ),
    );
  }
}