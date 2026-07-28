/// Models for the restaurant menu / cart flow.
///
/// These mirror the shape the backend will eventually return, so wiring the
/// real API later is a change inside the repository only — no screen edits.
library;

/// A tab inside a restaurant's menu, e.g. "وجبات", "مشروبات".
class MenuSection {
  final int id;
  final String name;

  const MenuSection({required this.id, required this.name});

  factory MenuSection.fromJson(Map<String, dynamic> json) => MenuSection(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
      );
}

/// A required choice that changes the price, e.g. "وسط" / "كبير".
class ProductSize {
  final int id;
  final String name;
  final double price;

  const ProductSize({
    required this.id,
    required this.name,
    required this.price,
  });

  factory ProductSize.fromJson(Map<String, dynamic> json) => ProductSize(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        price: double.tryParse(json['price'].toString()) ?? 0,
      );
}

/// An optional paid extra, e.g. "جبنة زيادة".
class ProductAddon {
  final int id;
  final String name;
  final double price;

  const ProductAddon({
    required this.id,
    required this.name,
    required this.price,
  });

  factory ProductAddon.fromJson(Map<String, dynamic> json) => ProductAddon(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        price: double.tryParse(json['price'].toString()) ?? 0,
      );
}

/// A menu item. When [sizes] is non-empty a size must be chosen and its price
/// is used; otherwise [basePrice] applies.
class Product {
  final int id;
  final int merchantId;
  final int? sectionId;
  final String name;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final bool isPopular;
  final bool isAvailable;
  final List<ProductSize> sizes;
  final List<ProductAddon> addons;

  const Product({
    required this.id,
    required this.merchantId,
    this.sectionId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.basePrice,
    this.isPopular = false,
    this.isAvailable = true,
    this.sizes = const [],
    this.addons = const [],
  });

  /// Cheapest price the customer could pay for this item, used on menu cards.
  double get startingPrice => sizes.isEmpty
      ? basePrice
      : sizes.map((s) => s.price).reduce((a, b) => a < b ? a : b);

  bool get hasSizes => sizes.isNotEmpty;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        merchantId: json['merchantId'] as int,
        sectionId: json['sectionId'] as int?,
        name: (json['name'] ?? '').toString(),
        description: json['description']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
        basePrice: double.tryParse(json['basePrice'].toString()) ?? 0,
        isPopular: json['isPopular'] == true,
        isAvailable: json['isAvailable'] != false,
        sizes: ((json['sizes'] as List?) ?? [])
            .map((e) => ProductSize.fromJson(e as Map<String, dynamic>))
            .toList(),
        addons: ((json['addons'] as List?) ?? [])
            .map((e) => ProductAddon.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One configured line in the cart: product + chosen size + addons + quantity.
class CartLine {
  final String id;
  final int merchantId;
  final String merchantName;

  /// Restaurant coordinates, carried so checkout can send them as the order's
  /// pickup point — that is what the pricing engine and the driver need.
  final double? merchantLat;
  final double? merchantLng;

  final Product product;
  final ProductSize? size;
  final List<ProductAddon> addons;
  int quantity;
  final String? note;

  CartLine({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    this.merchantLat,
    this.merchantLng,
    required this.product,
    this.size,
    this.addons = const [],
    this.quantity = 1,
    this.note,
  });

  /// One line of the order as plain text, e.g.
  /// `2× ساندويتش دجاج (كبير) + بطاطس وسط — ملاحظة: بدون بصل`.
  String get asOrderText {
    final buffer = StringBuffer('$quantity× ${product.name}');
    if (size != null) buffer.write(' (${size!.name})');
    if (addons.isNotEmpty) {
      buffer.write(' + ${addons.map((a) => a.name).join(' + ')}');
    }
    if ((note ?? '').isNotEmpty) buffer.write(' — ملاحظة: $note');
    buffer.write(' = ${lineTotal.toStringAsFixed(2)} ج.م');
    return buffer.toString();
  }

  /// Price of one unit including its addons.
  double get unitPrice {
    final base = size?.price ?? product.basePrice;
    final extras = addons.fold<double>(0, (sum, a) => sum + a.price);
    return base + extras;
  }

  double get lineTotal => unitPrice * quantity;

  /// Two lines are "the same product configuration" when the product, size and
  /// addon set match — used so re-adding an identical item bumps the quantity
  /// instead of creating a duplicate row.
  String get signature {
    final addonIds = addons.map((a) => a.id).toList()..sort();
    return '${product.id}|${size?.id ?? 0}|${addonIds.join(',')}|${note ?? ''}';
  }
}
