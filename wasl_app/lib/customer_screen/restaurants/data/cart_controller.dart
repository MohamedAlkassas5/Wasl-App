import 'package:flutter/foundation.dart';

import 'restaurant_models.dart';

/// The customer's cart, held in memory for the session.
///
/// A cart belongs to **one restaurant at a time** — mixing items from two
/// kitchens into a single delivery isn't something the order flow can fulfil,
/// so adding from a different restaurant asks the customer to start a new cart
/// rather than silently dropping the old one.
class CartController extends ChangeNotifier {
  CartController._();
  static final CartController instance = CartController._();

  final List<CartLine> _lines = [];

  int? _merchantId;
  String _merchantName = '';

  List<CartLine> get lines => List.unmodifiable(_lines);
  int? get merchantId => _merchantId;
  String get merchantName => _merchantName;

  /// Restaurant coordinates for the cart's items, used as the order's pickup
  /// point at checkout. Null when the restaurant had no coordinates on file.
  double? get merchantLat => _lines.isEmpty ? null : _lines.first.merchantLat;
  double? get merchantLng => _lines.isEmpty ? null : _lines.first.merchantLng;

  /// The whole cart as the plain-text item list the orders API accepts.
  String get asOrderDescription =>
      _lines.map((l) => l.asOrderText).join('\n');

  bool get isEmpty => _lines.isEmpty;

  /// Total number of individual items (not lines) — for the cart badge.
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.quantity);

  /// Sum of the item lines, before delivery.
  double get subtotal => _lines.fold(0, (sum, l) => sum + l.lineTotal);

  /// Whether adding an item from [merchantId] would require clearing the cart.
  bool wouldReplaceCart(int merchantId) =>
      _lines.isNotEmpty && _merchantId != null && _merchantId != merchantId;

  /// Adds a configured line. If an identical configuration is already present
  /// its quantity is increased instead of adding a duplicate row.
  void add(CartLine line) {
    if (wouldReplaceCart(line.merchantId)) {
      _lines.clear();
    }

    _merchantId = line.merchantId;
    _merchantName = line.merchantName;

    final existingIndex =
        _lines.indexWhere((l) => l.signature == line.signature);
    if (existingIndex >= 0) {
      _lines[existingIndex].quantity += line.quantity;
    } else {
      _lines.add(line);
    }
    notifyListeners();
  }

  void increment(CartLine line) {
    line.quantity += 1;
    notifyListeners();
  }

  /// Decreasing below one removes the line entirely.
  void decrement(CartLine line) {
    if (line.quantity > 1) {
      line.quantity -= 1;
    } else {
      _lines.remove(line);
    }
    _resetIfEmpty();
    notifyListeners();
  }

  void remove(CartLine line) {
    _lines.remove(line);
    _resetIfEmpty();
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _resetIfEmpty();
    notifyListeners();
  }

  void _resetIfEmpty() {
    if (_lines.isEmpty) {
      _merchantId = null;
      _merchantName = '';
    }
  }
}
