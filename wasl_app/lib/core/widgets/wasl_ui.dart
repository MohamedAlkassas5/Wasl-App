import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';

/// Reusable building blocks for the redesigned Wasl UI. Screens compose these
/// instead of re-implementing buttons/cards/states, keeping the look consistent.

/// Marks a screen whose content is sample data, not real merchant data.
///
/// This app previously shipped invented shops, ratings and prices that looked
/// identical to real ones, so a customer could tap a store that did not exist.
/// Any screen backed by placeholder data shows this banner, and it disappears
/// on its own the moment that screen is wired to a real source.
class WaslDemoDataBanner extends StatelessWidget {
  final String message;

  const WaslDemoDataBanner({
    super.key,
    this.message = 'عرض تجريبي — الأصناف والأسعار هنا للتصميم فقط وليست بيانات حقيقية',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(WaslSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary gradient action button with a built-in loading state.
class WaslButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;

  const WaslButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.6, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    color: outlined ? AppColors.primary : Colors.white,
                    size: 20),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: TextStyle(
                    color: outlined ? AppColors.primary : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  )),
            ],
          );

    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          gradient: outlined ? null : (disabled ? null : AppColors.logoGradient),
          color: outlined
              ? Colors.transparent
              : (disabled ? const Color(0xFFE2E4EA) : null),
          border:
              outlined ? Border.all(color: AppColors.primary, width: 1.4) : null,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          boxShadow: (outlined || disabled)
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Soft elevated surface used for grouping content.
class WaslCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const WaslCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WaslSpacing.md),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// Rounded icon chip on a soft brand-tinted background.
class WaslIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const WaslIconBadge(this.icon, {super.key, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(WaslSpacing.radiusSm),
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

/// Friendly empty state with an optional action.
class WaslEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const WaslEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WaslSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: WaslSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: WaslSpacing.sm),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.5)),
            ],
            if (action != null) ...[
              const SizedBox(height: WaslSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Branded centered loading indicator.
class WaslLoader extends StatelessWidget {
  final String? message;
  const WaslLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: WaslSpacing.md),
            Text(message!,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Small circular back button used on custom (non-AppBar) headers.
class WaslCircleBack extends StatelessWidget {
  final VoidCallback? onTap;
  const WaslCircleBack({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.arrow_back_ios_new,
            size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Status pill (pending / active / rejected …).
class WaslStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const WaslStatusBadge(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(WaslSpacing.radiusPill),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
