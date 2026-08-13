import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import 'restaurant_models.dart';

/// Where restaurant menus come from.
///
/// The UI depends only on this interface, so switching from the placeholder to
/// a real API means adding one implementation and changing the single line in
/// [MenuRepository.instance] — no screen has to be touched.
abstract class MenuRepository {
  /// Swap this for the HTTP implementation once the menu endpoints exist.
  static MenuRepository instance = HttpMenuRepository();

  /// True when the data is sample content rather than real merchant data.
  /// The UI surfaces this to the user so demo items can never be mistaken for
  /// a real menu — the previous version of this app shipped invented shops and
  /// prices with no such marker, which is exactly what this prevents.
  bool get isPlaceholderData;

  Future<List<MenuSection>> getSections(int merchantId);

  Future<List<Product>> getProducts(int merchantId);
}

/// Sample menu used while the backend has no products table.
///
/// ⚠️ Nothing here is real merchant data. It exists so the restaurant screens
/// can be designed and reviewed end-to-end; [isPlaceholderData] is true so
/// every screen shows a "عرض تجريبي" banner while it is in use.
///
/// The content is deliberately generic (no real restaurant names, no branding
/// copied from any other app) — it is filler, not a catalogue.
class PlaceholderMenuRepository implements MenuRepository {
  @override
  bool get isPlaceholderData => true;

  static const _sections = [
    MenuSection(id: 1, name: 'الأكثر طلباً'),
    MenuSection(id: 2, name: 'وجبات رئيسية'),
    MenuSection(id: 3, name: 'إضافات'),
    MenuSection(id: 4, name: 'مشروبات'),
  ];

  @override
  Future<List<MenuSection>> getSections(int merchantId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _sections;
  }

  @override
  Future<List<Product>> getProducts(int merchantId) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return [
      Product(
        id: 1,
        merchantId: merchantId,
        sectionId: 2,
        name: 'ساندويتش دجاج',
        description: 'صدور دجاج مشوية مع صوص وخضار طازجة',
        basePrice: 0,
        isPopular: true,
        sizes: const [
          ProductSize(id: 11, name: 'وسط', price: 65),
          ProductSize(id: 12, name: 'كبير', price: 85),
        ],
        addons: const [
          ProductAddon(id: 101, name: 'بطاطس وسط', price: 20),
          ProductAddon(id: 102, name: 'جبنة زيادة', price: 10),
          ProductAddon(id: 103, name: 'صوص إضافي', price: 5),
        ],
      ),
      Product(
        id: 2,
        merchantId: merchantId,
        sectionId: 2,
        name: 'وجبة مشويات',
        description: 'تشكيلة مشويات مع أرز وسلطة',
        basePrice: 0,
        isPopular: true,
        sizes: const [
          ProductSize(id: 21, name: 'فردي', price: 120),
          ProductSize(id: 22, name: 'مزدوج', price: 210),
        ],
        addons: const [
          ProductAddon(id: 104, name: 'خبز إضافي', price: 5),
          ProductAddon(id: 105, name: 'سلطة', price: 15),
        ],
      ),
      Product(
        id: 3,
        merchantId: merchantId,
        sectionId: 2,
        name: 'طبق معكرونة',
        description: 'معكرونة بصوص الطماطم والجبن',
        basePrice: 70,
        addons: const [
          ProductAddon(id: 106, name: 'دجاج مقطع', price: 25),
        ],
      ),
      Product(
        id: 4,
        merchantId: merchantId,
        sectionId: 3,
        name: 'بطاطس مقلية',
        description: 'بطاطس مقرمشة',
        basePrice: 0,
        sizes: const [
          ProductSize(id: 41, name: 'وسط', price: 20),
          ProductSize(id: 42, name: 'كبير', price: 35),
        ],
      ),
      Product(
        id: 5,
        merchantId: merchantId,
        sectionId: 4,
        name: 'مشروب غازي',
        basePrice: 15,
        isPopular: true,
      ),
      Product(
        id: 6,
        merchantId: merchantId,
        sectionId: 4,
        name: 'عصير طازج',
        description: 'برتقال أو ليمون',
        basePrice: 25,
      ),
      Product(
        id: 7,
        merchantId: merchantId,
        sectionId: 3,
        name: 'سلطة خضراء',
        basePrice: 18,
        isAvailable: false,
      ),
    ];
  }
}

/// Production repository. It deliberately returns an empty list on a valid
/// empty catalogue; placeholder/demo data is never mixed into a production
/// response.
class HttpMenuRepository implements MenuRepository {
  @override
  bool get isPlaceholderData => false;

  /// The id here is a **merchant** id — the one `/stores/nearby` returns.
  ///
  /// It always was: the app has only ever had merchant ids to work with. The
  /// old path sent it to `/restaurants/:id/menu`, which looked it up in a
  /// separate table with its own id sequence, so the menu resolved to an
  /// unrelated row or, in practice, to nothing at all.
  Future<Map<String, dynamic>> _get(int merchantId) async {
    final response = await http
        .get(Uri.parse('${WaslApiConfig.baseUrl}/merchants/$merchantId/menu'),
            headers: await WaslApiConfig.authHeaders())
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر تحميل قائمة المتجر (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<List<MenuSection>> getSections(int merchantId) async {
    final data = await _get(merchantId);
    return ((data['categories'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MenuSection.fromJson)
        .toList();
  }

  @override
  Future<List<Product>> getProducts(int merchantId) async {
    final data = await _get(merchantId);
    return ((data['products'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }
}
