import 'package:flutter/material.dart';

/// The services shown on the home screen.
///
/// These are navigation destinations, not just a data list — each one opens a
/// different workflow — so they live in the app rather than coming from the
/// server's `/categories` feed. That feed still drives the older
/// order-from-anywhere category picker; this list is deliberately separate and
/// limited to the five services being built now.
class WaslHomeCategory {
  final String id;
  final String name;

  /// Shown on the destination screen while the workflow is still a placeholder.
  final String tagline;
  final String assetPath;
  final IconData fallbackIcon;

  /// False until the workflow behind it is built, which routes the tap to the
  /// "coming soon" screen instead of a dead end.
  final bool isImplemented;

  const WaslHomeCategory({
    required this.id,
    required this.name,
    required this.tagline,
    required this.assetPath,
    required this.fallbackIcon,
    this.isImplemented = false,
  });
}

const List<WaslHomeCategory> kWaslHomeCategories = [
  WaslHomeCategory(
    id: 'restaurants',
    name: 'مطاعم',
    tagline: 'اطلب من مطاعم مدينتك ويوصلك لحد باب البيت',
    assetPath: 'assets/demo/categories/restaurants.png',
    fallbackIcon: Icons.restaurant_rounded,
    isImplemented: true,
  ),
  WaslHomeCategory(
    id: 'pharmacy',
    name: 'صيدلية',
    tagline: 'أدوية ومستلزمات طبية من أقرب صيدلية ليك',
    assetPath: 'assets/demo/categories/pharmacy.png',
    fallbackIcon: Icons.local_pharmacy_rounded,
  ),
  WaslHomeCategory(
    id: 'stores',
    name: 'المتاجر',
    tagline: 'تصفّح المتاجر الشريكة واطلب منها مباشرة',
    assetPath: 'assets/demo/categories/stores.png',
    fallbackIcon: Icons.storefront_rounded,
  ),
  WaslHomeCategory(
    id: 'wasly',
    name: 'وصللي',
    tagline: 'عايز حاجة تتوصّل من مكان لمكان؟ إحنا نوصّلها',
    assetPath: 'assets/demo/categories/wasly.png',
    fallbackIcon: Icons.local_shipping_rounded,
    // Backed by the existing order-from-anywhere flow.
    isImplemented: true,
  ),
  WaslHomeCategory(
    id: 'hatly',
    name: 'هاتلي',
    tagline: 'اكتب اللي عايزه من أي محل والكابتن يجيبهولك',
    assetPath: 'assets/demo/categories/hatly.png',
    fallbackIcon: Icons.shopping_basket_rounded,
    // Also served by order-from-anywhere until it gets its own catalogue.
    isImplemented: true,
  ),
];
