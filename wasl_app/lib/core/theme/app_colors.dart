import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0D5BE1);
  static const secondary = Color(0xFF12CFE0);
  static const background = Color(0xFFF8FAFC);
  static const white = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);

  // 🎯 الألوان المسببة للمشكلة - تأكد من وجودها هنا
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12CFE0), Color(0xFF0D5BE1)],
  );
}