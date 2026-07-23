import 'package:flutter/material.dart';
// 🎯 تأكد من صحة مسار عمل import لكلاس الألوان بحسب مشروعك
import 'package:wasl_app/core/theme/app_colors.dart';

class WaslResetPasswordScreen extends StatefulWidget {
  const WaslResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<WaslResetPasswordScreen> createState() => _WaslResetPasswordScreenState();
}

class _WaslResetPasswordScreenState extends State<WaslResetPasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _handleResetPassword() {
    if (_passController.text.isEmpty || _confirmPassController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء كافة الحقول', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger, // 🎯 تم الإصلاح
        ),
      );
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمتا المرور غير متطابقتين', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger, // 🎯 تم الإصلاح
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث كلمة المرور بنجاح! 🎉', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success, // 🎯 تم الإصلاح
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                  'أدخل كلمة مرور جديدة وقوية لتأمين حسابك في فلاش',
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
                            children: const [
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