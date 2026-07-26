import 'package:flutter/material.dart';
// 🎯 تأكد من صحة مسار عمل import لكلاس الألوان بحسب مشروعك
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/whatsapp_otp_service.dart';

/// آخر خطوة في استعادة الحساب.
///
/// الشاشة دي كانت بتعرض "تم تحديث كلمة المرور بنجاح" من غير ما تكلّم السيرفر
/// خالص — كلمة المرور القديمة كانت بتفضل شغالة. دلوقتي بتبعت الرقم + الكود +
/// كلمة المرور الجديدة لـ /auth/otp/reset-password، والسيرفر بيتحقق من الكود
/// تاني قبل ما يغيّر أي حاجة.
class WaslResetPasswordScreen extends StatefulWidget {
  /// الرقم اللي اتأكد بالـ OTP، والكود نفسه — السيرفر بيطلبهم الاتنين علشان
  /// التغيير يفضل مربوط برمز مُثبَت، مش برقم هاتف لوحده.
  final String phone;
  final String code;

  const WaslResetPasswordScreen({
    Key? key,
    required this.phone,
    required this.code,
  }) : super(key: key);

  @override
  State<WaslResetPasswordScreen> createState() => _WaslResetPasswordScreenState();
}

class _WaslResetPasswordScreenState extends State<WaslResetPasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    if (_isSubmitting) return;

    if (_passController.text.isEmpty || _confirmPassController.text.isEmpty) {
      _showSnackBar('يرجى ملء كافة الحقول', AppColors.danger);
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      _showSnackBar('كلمتا المرور غير متطابقتين', AppColors.danger);
      return;
    }

    if (_passController.text.length < 6) {
      _showSnackBar('كلمة المرور يجب أن تكون 6 أحرف على الأقل', AppColors.danger);
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await WhatsappOtpService().resetPassword(
      phone: widget.phone,
      code: widget.code,
      newPassword: _passController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] != true) {
      _showSnackBar(result['message'] ?? 'تعذّر تحديث كلمة المرور', AppColors.danger);
      return;
    }

    _showSnackBar('تم تحديث كلمة المرور بنجاح! 🎉', AppColors.success);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showSnackBar(String text, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Image.asset(
                      'images/wasal_logo_new.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppColors.logoGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'إعادة تعيين كلمة المرور',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أدخل كلمة مرور جديدة وقوية لتأمين حسابك في وصل',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withOpacity(0.01),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'كلمة المرور الجديدة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passController,
                        obscureText: _obscurePass,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة المرور',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo'),
                          prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textSecondary),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          fillColor: AppColors.background,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 1.2)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'تأكيد كلمة المرور',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmPassController,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'أعد كتابة كلمة المرور',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo'),
                          prefixIcon: const Icon(Icons.gpp_good_outlined, size: 20, color: AppColors.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textSecondary),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          fillColor: AppColors.background,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 1.2)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _handleResetPassword,
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _isSubmitting
                                ? const [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                                    ),
                                  ]
                                : const [
                                    Text(
                                      'تحديث كلمة المرور',
                                      style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.done_all, color: AppColors.white, size: 18),
                                  ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'تواجه مشكلة؟ تواصل مع الدعم الفني',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
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