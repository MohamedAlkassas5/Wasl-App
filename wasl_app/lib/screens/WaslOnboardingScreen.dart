import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';

class WaslOnboardingScreen extends StatefulWidget {
  const WaslOnboardingScreen({super.key});

  @override
  State<WaslOnboardingScreen> createState() => _WaslOnboardingScreenState();
}

class _OnbData {
  final String title;
  final String desc;
  final String image;
  final IconData icon;
  const _OnbData(this.title, this.desc, this.image, this.icon);
}

class _WaslOnboardingScreenState extends State<WaslOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnbData> _data = [
    _OnbData(
      'كل مدينتك بين يديك',
      'اطلب أي شيء من متاجرك المحلية المفضلة، ويصلك مباشرة إلى باب بيتك بأسرع وقت.',
      'images/PageStart_logo.png',
      Icons.storefront_rounded,
    ),
    _OnbData(
      'تتبع طلبك لحظة بلحظة',
      'تابع الكابتن على الخريطة مباشرة من وقت خروج الطلب وحتى وصوله إليك.',
      'images/onboarding_track.png',
      Icons.location_on_rounded,
    ),
    _OnbData(
      'وصّل أي شيء لأي مكان',
      'محتاج حد يجيب لك دواء أو يوصّل طرد؟ اطلب خدمة توصيل مخصصة لأي مهمة.',
      'images/onboarding_payment.png',
      Icons.delivery_dining_rounded,
    ),
  ];

  bool get _isLast => _currentPage == _data.length - 1;

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WaslLoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _data.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _buildPage(_data[i]),
                ),
              ),
              _buildIndicator(),
              const SizedBox(height: WaslSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WaslSpacing.lg),
                child: WaslButton(
                  label: _isLast ? 'ابدأ الآن' : 'التالي',
                  icon: _isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (_isLast) {
                      _complete();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: WaslSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WaslSpacing.lg, WaslSpacing.md, WaslSpacing.lg, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.logoGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.near_me_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('وصل',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ],
          ),
          AnimatedOpacity(
            opacity: _isLast ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: TextButton(
              onPressed: _isLast ? null : _complete,
              child: const Text('تخطي',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnbData d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WaslSpacing.lg),
      child: Column(
        children: [
          const Spacer(),
          // Illustration with a soft branded halo; falls back to an icon tile.
          Container(
            width: MediaQuery.of(context).size.width * 0.72,
            height: MediaQuery.of(context).size.width * 0.72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.primary.withOpacity(0.10),
                  AppColors.secondary.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            padding: const EdgeInsets.all(28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                d.image,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: AppColors.logoGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(d.icon, size: 58, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(d.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: WaslSpacing.md),
          Text(d.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.7)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_data.length, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 26 : 7,
          height: 7,
          decoration: BoxDecoration(
            gradient: active ? AppColors.logoGradient : null,
            color: active ? null : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
