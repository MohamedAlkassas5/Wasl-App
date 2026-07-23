import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 استيراد مكتبة الحفظ لإدارة الجلسات
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';
import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart'; // 👈 استيراد هوم العميل
import 'package:wasl_app/delivery_screen/WaslDriverHomeScreen.dart'; // 👈 استيراد هوم المندوب

class WaslSplashScreen extends StatefulWidget {
  const WaslSplashScreen({Key? key}) : super(key: key);

  @override
  State<WaslSplashScreen> createState() => _WaslSplashScreenState();
}

class _WaslSplashScreenState extends State<WaslSplashScreen> with TickerProviderStateMixin {
  bool _showLoadingDots = false;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();

    // 1️⃣ إعداد متحكم حركة نقاط التحميل الانسيابية
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // 2️⃣ إظهار شعار فلاش أولاً، ثم إظهار النقاط بعد 1500 مللي ثانية (ثانية ونصف)
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showLoadingDots = true;
        });
      }
    });

    // 3️⃣ 🎯 التوجيه الذكي التلقائي بعد 3.5 ثانية للتحقق من وجود جلسة دخول نشطة
    Timer(const Duration(milliseconds: 3500), () {
      _checkAuthSession();
    });
  }

  // 🎯 دالة فحص الـ Session المخزن لتحديد الوجهة ومنع تسجيل الدخول المتكرر
  Future<void> _checkAuthSession() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    final String? role = prefs.getString('user_role');

    // إذا كان التوكن موجوداً ومحفوظاً، يتم التوجيه مباشرة لصفحة دور الحساب المعتمد
    if (token != null && token.isNotEmpty) {
      if (role == 'driver' || role == 'delivery') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WaslDriverHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WaslCustomerHomeScreen()),
        );
      }
    } else {
      // إذا كانت الجلسة فارغة، يتم التوجيه العادي لشاشة تسجيل الدخول
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WaslLoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  // ويدجيت مخصصة لبناء النقاط المتحركة بتدرج ألوان الهوية البصرية لـ FLASH
  Widget _buildAnimatedDot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        // حساب الحركة الموجية لكل نقطة بشكل منفصل ومتناسق
        final delay = index * 0.2;
        final progress = (_dotsController.value - delay).clamp(0.0, 1.0);
        final double bounceFactor = (progress <= 0.5)
            ? (progress * 2)
            : (1.0 - (progress - 0.5) * 2);

        return Opacity(
          opacity: 0.4 + (bounceFactor * 0.6),
          child: Transform.translate(
            offset: Offset(0, -bounceFactor * 6),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.primary, // لون فلاش الرسمي النقي الظاهر في الصورة
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white, // خلفية بيضاء نقية مطابقة للصورة تماماً
      body: SafeArea(
        child: Stack(
          children: [
            // الشعار في منتصف الشاشة تماماً
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'images/logo_sada.png', // مسار شعار الطائر والكرتونة لـ FLASH
                    width: 400,
                    height: 400,
                    fit: BoxFit.contain,
                  ),

                  // مسافة ديناميكية مرنة بين الشعار ونقاط التحميل
                  const SizedBox(height: 48),

                  // ظهور النقاط بانسيابية (Fade-in) بعد الوقت المحدد
                  AnimatedOpacity(
                    opacity: _showLoadingDots ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) => _buildAnimatedDot(index)), // 4 نقاط مطابقة تماماً لصورة الـ Emulator
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}