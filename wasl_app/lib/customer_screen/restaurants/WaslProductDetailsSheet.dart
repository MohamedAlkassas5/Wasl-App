import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/theme/wasl_assets.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';

import 'data/cart_controller.dart';
import 'data/restaurant_models.dart';

/// Opens the product configuration sheet. Returns true if something was added.
Future<bool?> showWaslProductSheet({
  required BuildContext context,
  required Product product,
  required int merchantId,
  required String merchantName,
  double? merchantLat,
  double? merchantLng,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WaslProductDetailsSheet(
      product: product,
      merchantId: merchantId,
      merchantName: merchantName,
      merchantLat: merchantLat,
      merchantLng: merchantLng,
    ),
  );
}

/// Configure one menu item before adding it: pick a size (required when the
/// item has sizes), tick optional addons, set a quantity and leave a note.
class WaslProductDetailsSheet extends StatefulWidget {
  final Product product;
  final int merchantId;
  final String merchantName;
  final double? merchantLat;
  final double? merchantLng;

  const WaslProductDetailsSheet({
    super.key,
    required this.product,
    required this.merchantId,
    required this.merchantName,
    this.merchantLat,
    this.merchantLng,
  });

  @override
  State<WaslProductDetailsSheet> createState() =>
      _WaslProductDetailsSheetState();
}

class _WaslProductDetailsSheetState extends State<WaslProductDetailsSheet> {
  ProductSize? _size;
  final Set<int> _addonIds = {};
  int _quantity = 1;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Preselect the cheapest size so the price shown is never ambiguous.
    if (widget.product.hasSizes) {
      final sizes = [...widget.product.sizes]
        ..sort((a, b) => a.price.compareTo(b.price));
      _size = sizes.first;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<ProductAddon> get _selectedAddons =>
      widget.product.addons.where((a) => _addonIds.contains(a.id)).toList();

  double get _unitPrice {
    final base = _size?.price ?? widget.product.basePrice;
    final extras = _selectedAddons.fold<double>(0, (s, a) => s + a.price);
    return base + extras;
  }

  double get _total => _unitPrice * _quantity;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WaslSpacing.radiusLg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGrabber(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  media.viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildQuantityRow(),
                    if (widget.product.hasSizes) ...[
                      const SizedBox(height: 20),
                      _sectionTitle('اختر الحجم', required: true),
                      const SizedBox(height: 8),
                      ...widget.product.sizes.map(_buildSizeOption),
                    ],
                    if (widget.product.addons.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionTitle('إضافات اختيارية'),
                      const SizedBox(height: 8),
                      ...widget.product.addons.map(_buildAddonOption),
                    ],
                    const SizedBox(height: 20),
                    _sectionTitle('ملاحظات خاصة'),
                    const SizedBox(height: 8),
                    _buildNoteField(),
                  ],
                ),
              ),
            ),
            _buildAddBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusPill),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          child: Image.asset(
            WaslAssets.dishFor(widget.product.id),
            width: 82,
            height: 82,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 82,
              height: 82,
              color: AppColors.white,
              child: const Icon(Icons.fastfood_rounded,
                  color: AppColors.primary, size: 34),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
              if ((widget.product.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.product.description!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Cairo',
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded,
              color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
        ),
        if (required) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'مطلوب',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityRow() {
    return Row(
      children: [
        const Text(
          'الكمية',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          ),
          child: Row(
            children: [
              _stepButton(
                Icons.remove,
                _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$_quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _stepButton(Icons.add, () => setState(() => _quantity++)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildSizeOption(ProductSize size) {
    final selected = _size?.id == size.id;
    return GestureDetector(
      onTap: () => setState(() => _size = size),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.white,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                size.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            Text(
              '${size.price.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonOption(ProductAddon addon) {
    final selected = _addonIds.contains(addon.id);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _addonIds.remove(addon.id);
        } else {
          _addonIds.add(addon.id);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box_rounded : Icons.check_box_outline_blank,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                addon.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            Text(
              '+ ${addon.price.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      decoration: InputDecoration(
        hintText: 'مثال: بدون بصل، حار جداً',
        hintStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildAddBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: WaslButton(
          label: 'أضف إلى السلة — ${_total.toStringAsFixed(2)} ج.م',
          icon: Icons.shopping_cart_rounded,
          onPressed: _addToCart,
        ),
      ),
    );
  }

  Future<void> _addToCart() async {
    final cart = CartController.instance;

    // A cart holds one restaurant's items; warn before discarding the old one.
    if (cart.wouldReplaceCart(widget.merchantId)) {
      final replace = await _confirmReplaceCart();
      if (replace != true) return;
    }

    final note = _noteController.text.trim();
    cart.add(
      CartLine(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        merchantId: widget.merchantId,
        merchantName: widget.merchantName,
        merchantLat: widget.merchantLat,
        merchantLng: widget.merchantLng,
        product: widget.product,
        size: _size,
        addons: _selectedAddons,
        quantity: _quantity,
        note: note.isEmpty ? null : note,
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
          'تمت إضافة ${widget.product.name} إلى السلة',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _confirmReplaceCart() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          ),
          title: const Text(
            'بدء سلة جديدة؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          content: Text(
            'سلتك الحالية بها أصناف من "${CartController.instance.merchantName}". '
            'الطلب من مطعم آخر سيفرغ السلة الحالية.',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('سلة جديدة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
