import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderCategoryScreen.dart';

import 'wasl_home_categories.dart';

/// Destination for a service whose workflow isn't built yet.
///
/// It uses the same design language as the finished screens and offers the
/// order-from-anywhere flow as a working alternative, so tapping the tile does
/// something useful instead of opening a blank page. It states plainly that the
/// service is on the way rather than implying it works.
class WaslServiceComingSoonScreen extends StatelessWidget {
  final WaslHomeCategory category;

  const WaslServiceComingSoonScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          physics: const BouncingScrollPhysics(),
          children: [
            Center(
              child: Container(
                width: 190,
                height: 190,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  category.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    category.fallbackIcon,
                    size: 76,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              category.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.tagline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.7,
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.construction_rounded,
                      color: AppColors.warning, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الخدمة دي تحت التطوير حالياً وهتكون متاحة قريباً',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لحد ما تجهز، تقدر تستخدم:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 12),
            _buildAlternativeCard(context),
          ],
        ),
      ),
    );
  }

  /// Order-from-anywhere genuinely works today and covers most of what these
  /// services will do, so it is offered rather than leaving a dead end.
  Widget _buildAlternativeCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.logoGradient,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اطلب أي حاجة من أي مكان',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'اكتب طلبك بنفسك والكابتن يجيبهولك',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}
