import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/theme/wasl_assets.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';

import 'data/cart_controller.dart';
import 'data/restaurant_models.dart';
import 'WaslCheckoutScreen.dart';

/// The cart for the current restaurant: review lines, change quantities,
/// remove items, then continue to checkout.
///
/// Delivery is deliberately NOT estimated here — it depends on the delivery
/// address, which is chosen at checkout. Showing a total that later changes
/// would be worse than showing the item subtotal honestly.
class WaslCartScreen extends StatefulWidget {
  const WaslCartScreen({super.key});

  @override
  State<WaslCartScreen> createState() => _WaslCartScreenState();
}

class _WaslCartScreenState extends State<WaslCartScreen> {
  final _cart = CartController.instance;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'السلة',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                fontFamily: 'Cairo',
              ),
            ),
            if (_cart.merchantName.isNotEmpty)
              Text(
                _cart.merchantName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'Cairo',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (!_cart.isEmpty)
            IconButton(
              tooltip: 'إفراغ السلة',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
            ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _cart.isEmpty ? _buildEmpty() : _buildContent(),
      ),
      bottomNavigationBar: _cart.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildEmpty() {
    return WaslEmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'سلة التسوق فارغة',
      subtitle: 'أضف بعض الأصناف من المطعم لتبدأ طلبك',
      action: WaslButton(
        label: 'تصفّح المطاعم',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        ..._cart.lines.map(_buildLine),
        const SizedBox(height: 8),
        _buildSummary(),
      ],
    );
  }

  Widget _buildLine(CartLine line) {
    return Dismissible(
      key: ValueKey(line.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _cart.remove(line),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
              child: Image.asset(
                WaslAssets.dishFor(line.product.id),
                width: 66,
                height: 66,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 66,
                  height: 66,
                  color: AppColors.background,
                  child: const Icon(Icons.fastfood_rounded,
                      color: AppColors.primary, size: 26),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _cart.remove(line),
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: AppColors.danger),
                      ),
                    ],
                  ),
                  if (line.size != null)
                    _detailText('الحجم: ${line.size!.name}'),
                  if (line.addons.isNotEmpty)
                    _detailText(
                        'إضافات: ${line.addons.map((a) => a.name).join('، ')}'),
                  if ((line.note ?? '').isNotEmpty)
                    _detailText('ملاحظة: ${line.note}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStepper(line),
                      const Spacer(),
                      Text(
                        '${line.lineTotal.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildStepper(CartLine line) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _cart.decrement(line),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                line.quantity > 1
                    ? Icons.remove
                    : Icons.delete_outline_rounded,
                size: 16,
                color: line.quantity > 1 ? AppColors.primary : AppColors.danger,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: () => _cart.increment(line),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.add, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ملخص الطلب',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('عدد الأصناف', '${_cart.itemCount}'),
          const SizedBox(height: 8),
          _summaryRow(
            'المجموع الفرعي',
            '${_cart.subtotal.toStringAsFixed(2)} ج.م',
            bold: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'رسوم التوصيل تُحسب بعد تحديد عنوان التوصيل',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Cairo',
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: bold ? AppColors.primary : AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'المجموع الفرعي',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    '${_cart.subtotal.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: WaslButton(
                label: 'متابعة الطلب',
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WaslCheckoutScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          ),
          title: const Text(
            'إفراغ السلة؟',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 17),
          ),
          content: const Text(
            'سيتم حذف كل الأصناف من سلتك.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إفراغ',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) _cart.clear();
  }
}
