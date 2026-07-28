import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';
import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';
import 'package:wasl_app/delivery_screen/WaslDriverHomeScreen.dart';

class WaslSplashScreen extends StatefulWidget {
  const WaslSplashScreen({super.key});

  @override
  State<WaslSplashScreen> createState() => _WaslSplashScreenState();
}

class _WaslSplashScreenState extends State<WaslSplashScreen>
    with TickerProviderStateMixin {
  bool _showLoadingDots = false;
  late final AnimationController _dotsController;
  late final AnimationController _introController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _introController, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _introController, curve: Curves.easeIn);
    _introController.forward();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showLoadingDots = true);
    });

    Timer(const Duration(milliseconds: 3200), _checkAuthSession);
  }

  Future<void> _checkAuthSession() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    final String? role = prefs.getString('user_role');

    Widget dest;
    if (token != null && token.isNotEmpty) {
      dest = (role == 'driver' || role == 'delivery')
          ? const WaslDriverHomeScreen()
          : const WaslCustomerHomeScreen();
    } else {
      dest = const WaslLoginScreen();
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => dest));
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedDot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        final delay = index * 0.2;
        final progress = (_dotsController.value - delay).clamp(0.0, 1.0);
        final bounce =
        (progress <= 0.5) ? (progress * 2) : (1.0 - (progress - 0.5) * 2);
        return Opacity(
          opacity: 0.4 + (bounce * 0.6),
          child: Transform.translate(
            offset: Offset(0, -bounce * 6),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1FC4D6), Color(0xFF1B62E6)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 🎯 1️⃣ كارت اللوجو بتنسيق متناسق وظل ناعم احترافي
                          Container(
                            width: 120,
                            height: 120,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'images/logo_sada.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.flash_on_rounded,
                                size: 56,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // 🎯 2️⃣ اسم التطبيق الرئيسي باللغة العربية
                          const Text(
                            'فلاش توصيل',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // 🎯 3️⃣ الاسم بالإنجليزية بتنسيق شيك وثانوي
                          Text(
                            'FLASH TAWSEEL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2.5,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 🎯 4️⃣ الشعار اللفظي (Slogan)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'توصيل كل حاجة، لأي مكان 🚀',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 🎯 5️⃣ مؤشر التحميل السفلي النقاط المتدرجة
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: AnimatedOpacity(
                    opacity: _showLoadingDots ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) => _buildAnimatedDot(i)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}