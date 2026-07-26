import 'package:flutter/material.dart';

/// Wasl brand design tokens (v3 — unified around the FLASH blue/cyan logo).
///
/// The whole app shares these constants, so redefining them here re-skins every
/// screen at once. Names are kept stable for backward compatibility; the values
/// now follow the FLASH logo: an electric royal blue with a turquoise/cyan
/// accent, matching the "FLASH tawseel" mark and its blue→cyan gradient.
class AppColors {
  // Brand — from the FLASH logo
  static const primary = Color(0xFF1B62E6); // FLASH electric blue
  static const primaryDark = Color(0xFF1442AE); // deeper blue (pressed/shadow)
  static const secondary = Color(0xFF1FC4D6); // turquoise/cyan accent
  static const accent = Color(0xFF0F2038); // deep navy for contrast surfaces

  // Neutrals
  static const background = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFECEEF2);

  // Text
  static const textPrimary = Color(0xFF16192C);
  static const textSecondary = Color(0xFF737686);

  // Status
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  // Signature gradient (buttons, highlights) — cyan → blue like the logo.
  static const logoGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1FC4D6), Color(0xFF1B62E6)],
  );

  // Soft tinted surface behind icons/badges.
  static Color primarySoft = const Color(0xFF1B62E6).withOpacity(0.08);
}

/// Spacing / radius scale for consistent rhythm across the redesign.
class WaslSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 22.0;
  static const radiusPill = 999.0;
}
