/// Maps business concepts to image assets, with a graceful fallback.
///
/// Category names arrive from the server as free text and the set can change
/// without an app release, so artwork is looked up by name here rather than
/// being hardcoded per screen. An unknown category — or one whose file hasn't
/// been added yet — renders the branded icon instead of a broken box.
///
/// ## Replacing the temporary artwork
/// Everything under `assets/demo/` is placeholder material for development:
///   - `categories/wasly|hatly|pharmacy|restaurants|stores.png` — this project's
///     own illustrations.
///   - the remaining category icons — Noto Emoji (Apache-2.0, Google).
///   - `food/`, `restaurants/`, `banners/` — TheMealDB's free photo API.
/// Drop replacements in with the same filenames and nothing else has to change.
library;

import 'package:flutter/material.dart';

class WaslAssets {
  static const _categories = 'assets/demo/categories';
  static const _food = 'assets/demo/food';
  static const _covers = 'assets/demo/restaurants';
  static const _banners = 'assets/demo/banners';

  /// Category name → artwork. Several spellings map to the same file because
  /// the server list and the app's wording have drifted (e.g. صيدلية/صيدليات).
  static const Map<String, String> _categoryImages = {
    'وصلي': '$_categories/wasly.png',
    'وصلى': '$_categories/wasly.png',
    'هاتلي': '$_categories/hatly.png',
    'هاتلى': '$_categories/hatly.png',
    'تموينك': '$_categories/hatly.png',
    'صيدلية': '$_categories/pharmacy.png',
    'صيدليات': '$_categories/pharmacy.png',
    'مطاعم': '$_categories/restaurants.png',
    'المتاجر': '$_categories/stores.png',
    'متاجر': '$_categories/stores.png',
    'مخابز': '$_categories/bakery.png',
    'إلكترونيات': '$_categories/electronics.png',
    'الكترونيات': '$_categories/electronics.png',
    'قرطاسية': '$_categories/stationery.png',
    'هدايا': '$_categories/gifts.png',
    'منزل': '$_categories/home.png',
    'ورود': '$_categories/flowers.png',
    'زهور': '$_categories/flowers.png',
    'حيوانات أليفة': '$_categories/pets.png',
    'بقالة': '$_categories/grocery.png',
    'سوبر ماركت': '$_categories/grocery.png',
    'مشروبات': '$_categories/drinks.png',
    'حلويات': '$_categories/sweets.png',
    'لحوم': '$_categories/meat.png',
    'كافيهات': '$_categories/coffee.png',
    'قهوة': '$_categories/coffee.png',
  };

  static String? categoryImage(String? name) =>
      name == null ? null : _categoryImages[name.trim()];

  static const List<String> dishes = [
    '$_food/dish_1.jpg',
    '$_food/dish_2.jpg',
    '$_food/dish_3.jpg',
    '$_food/dish_4.jpg',
    '$_food/dish_5.jpg',
    '$_food/dish_6.jpg',
    '$_food/dish_7.jpg',
    '$_food/dish_8.jpg',
  ];

  static const List<String> covers = [
    '$_covers/cover_1.jpg',
    '$_covers/cover_2.jpg',
    '$_covers/cover_3.jpg',
  ];

  static const List<String> banners = [
    '$_banners/banner_1.jpg',
    '$_banners/banner_2.jpg',
  ];

  /// Deterministic pick so the same product/restaurant always shows the same
  /// picture — a photo that reshuffles on every rebuild looks broken.
  static String dishFor(int seed) => dishes[seed.abs() % dishes.length];
  static String coverFor(int seed) => covers[seed.abs() % covers.length];
  static String bannerFor(int seed) => banners[seed.abs() % banners.length];
}

/// Renders an asset image and quietly falls back to [fallbackIcon] when the
/// file is missing, so absent artwork never shows as a broken image.
class WaslAssetImage extends StatelessWidget {
  final String? assetPath;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double? size;
  final BoxFit fit;

  const WaslAssetImage({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath == null) return _fallback();
    return Image.asset(
      assetPath!,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => Icon(
        fallbackIcon,
        size: size == null ? 40 : size! * 0.6,
        color: fallbackColor,
      );
}
