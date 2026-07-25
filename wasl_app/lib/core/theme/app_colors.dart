import 'package:flutter/material.dart';

/// Wasl brand design tokens (v2 — unified around the orange logo identity).
///
/// The whole app shares these constants, so redefining them here re-skins every
/// screen at once. Names are kept stable for backward compatibility; new tokens
/// were added for the redesign.
class AppColors {
  // Brand
  static const primary = Color(0xFFF14D18); // Wasl orange (matches the logo)
  static const primaryDark = Color(0xFFC83E10);
  static const secondary = Color(0xFFFF8A4C); // warm accent
  static const accent = Color(0xFF1F2A44); // deep ink for contrast surfaces

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

  // Signature gradient (buttons, highlights)
  static const logoGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFF7A3D), Color(0xFFF14D18)],
  );

  // Soft tinted surface behind icons/badges.
  static Color primarySoft = const Color(0xFFF14D18).withOpacity(0.08);
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
