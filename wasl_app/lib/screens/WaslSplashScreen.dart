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
      duration: const Duration(milliseconds: 850),
    );
    _scale = CurvedAnimation(parent: _introController, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _introController, curve: Curves.easeIn);
    _introController.forward();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showLoadingDots = true);
    });

    Timer(const Duration(milliseconds: 3500), _checkAuthSession);
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
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo tile (falls back to an icon if the asset is missing).
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(34),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'images/logo_sada.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.near_me_rounded,
                                size: 64,
                                color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Text('وصل',
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('توصيل كل حاجة، لأي مكان',
                            style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: AnimatedOpacity(
                    opacity: _showLoadingDots ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          List.generate(4, (i) => _buildAnimatedDot(i)),
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
