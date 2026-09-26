import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wasl_app/core/ui/wasl_submit_guard.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslMyOrdersScreen.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/services/zones_service.dart';

import 'data/cart_controller.dart';
import 'WaslOrderPlacedScreen.dart';

enum FulfilmentMode { delivery, pickup }

enum CheckoutPaymentMethod { cash, wallet }

/// Checkout: where it goes, how it is collected, and how it is paid.
///
/// The delivery fee comes from the existing `/pricing/quote` endpoint — the
/// same engine the order-from-anywhere flow uses — so the number shown here is
/// the real configured price, not an invented one. If the quote can't be
/// fetched, the screen says so instead of guessing a fee.
class WaslCheckoutScreen extends StatefulWidget {
  const WaslCheckoutScreen({super.key});

  @override
  State<WaslCheckoutScreen> createState() => _WaslCheckoutScreenState();
}

class _WaslCheckoutScreenState extends State<WaslCheckoutScreen>
    with WaslSubmitGuard<WaslCheckoutScreen> {
  final _cart = CartController.instance;
  final _zones = ZonesService();
  final _orders = FlutterOrdersService();

  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  FulfilmentMode _mode = FulfilmentMode.delivery;
  CheckoutPaymentMethod _payment = CheckoutPaymentMethod.cash;

  Position? _position;
  bool _isLocating = true;

  double? _deliveryFee;
  bool _isQuoting = false;
  String? _quoteError;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillAddress();
    _initLocationAndQuote();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _prefillAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_delivery_address');
    if (saved != null && saved.isNotEmpty && mounted) {
      _addressController.text = saved;
    }
  }

  Future<void> _initLocationAndQuote() async {
    setState(() => _isLocating = true);
    _position = await _resolvePosition();
    if (!mounted) return;
    setState(() => _isLocating = false);
    await _fetchQuote();
  }

  Future<Position?> _resolvePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  /// Pickup costs nothing to deliver; delivery is priced by the real engine.
  Future<void> _fetchQuote() async {
    if (_mode == FulfilmentMode.pickup) {
      setState(() {
        _deliveryFee = 0;
        _quoteError = null;
      });
      return;
    }

    setState(() {
      _isQuoting = true;
      _quoteError = null;
    });

    // A normal order is priced by the customer's area, not by distance. No
    // area is sent, so the server uses the one saved on their profile — and
    // says so plainly if they haven't chosen one yet.
    final res = await _zones.getNormalQuote();

    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'];
      final fee = double.tryParse(
        (data is Map ? data['deliveryFee'] : null).toString(),
      );
      setState(() {
        _deliveryFee = fee;
        _quoteError = fee == null ? 'تعذّر قراءة سعر التوصيل' : null;
        _isQuoting = false;
      });
    } else {
      setState(() {
        _deliveryFee = null;
        _quoteError = (res['message'] ?? 'تعذّر حساب رسوم التوصيل').toString();
        _isQuoting = false;
      });
    }
  }

  double get _subtotal => _cart.subtotal;
  double? get _total =>
      _deliveryFee == null ? null : _subtotal + _deliveryFee!;

  bool get _canSubmit {
    if (_isSubmitting || _cart.isEmpty) return false;
    if (_mode == FulfilmentMode.delivery &&
        _addressController.text.trim().isEmpty) {
      return false;
    }
    return _total != null;
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
        title: const Text(
          'إتمام الطلب',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildOrderSummaryCard(),
            const SizedBox(height: 14),
            _buildFulfilmentCard(),
            const SizedBox(height: 14),
            if (_mode == FulfilmentMode.delivery) ...[
              _buildAddressCard(),
              const SizedBox(height: 14),
            ],
            _buildPaymentCard(),
            const SizedBox(height: 14),
            _buildNoteCard(),
            const SizedBox(height: 14),
            _buildTotalsCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return _sectionCard(
      title: 'طلبك من ${_cart.merchantName}',
      child: Column(
        children: _cart.lines.map((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${line.quantity}×',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      if (line.size != null || line.addons.isNotEmpty)
                        Text(
                          [
                            if (line.size != null) line.size!.name,
                            ...line.addons.map((a) => a.name),
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${line.lineTotal.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFulfilmentCard() {
    return _sectionCard(
      title: 'طريقة الاستلام',
      child: Row(
        children: [
          Expanded(
            child: _choiceTile(
              icon: Icons.delivery_dining_rounded,
              label: 'توصيل',
              selected: _mode == FulfilmentMode.delivery,
              onTap: () {
                setState(() => _mode = FulfilmentMode.delivery);
                _fetchQuote();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _choiceTile(
              icon: Icons.storefront_rounded,
              label: 'استلام من المطعم',
              selected: _mode == FulfilmentMode.pickup,
              onTap: () {
                setState(() => _mode = FulfilmentMode.pickup);
                _fetchQuote();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceTile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primary.withOpacity(0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return _sectionCard(
      title: 'عنوان التوصيل',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _addressController,
            maxLines: 2,
            textDirection: TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'اكتب عنوانك بالتفصيل (الشارع، رقم العمارة، الشقة)',
              hintStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _position != null
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_off_rounded,
                size: 15,
                color: _position != null
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isLocating
                      ? 'جاري تحديد موقعك...'
                      : _position != null
                          ? 'تم تحديد موقعك على الخريطة'
                          : 'لم يتم تحديد موقعك — سيعتمد التوصيل على العنوان المكتوب',
                  style: const TextStyle(
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

  Widget _buildPaymentCard() {
    return _sectionCard(
      title: 'طريقة الدفع',
      child: Column(
        children: [
          _paymentOption(
            icon: Icons.payments_outlined,
            label: 'نقداً عند الاستلام',
            subtitle: 'ادفع للكابتن عند وصول الطلب',
            value: CheckoutPaymentMethod.cash,
          ),
          const SizedBox(height: 8),
          _paymentOption(
            icon: Icons.account_balance_wallet_outlined,
            label: 'محفظة فلاش',
            subtitle: 'الخصم من رصيد محفظتك',
            value: CheckoutPaymentMethod.wallet,
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required CheckoutPaymentMethod value,
  }) {
    final selected = _payment == value;
    return GestureDetector(
      onTap: () => setState(() => _payment = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primary.withOpacity(0.06) : AppColors.background,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard() {
    return _sectionCard(
      title: 'ملاحظات للكابتن',
      child: TextField(
        controller: _noteController,
        maxLines: 2,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        decoration: InputDecoration(
          hintText: 'مثال: التسليم من الباب الخلفي، رن الجرس مرتين',
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsCard() {
    return _sectionCard(
      title: 'ملخص الدفع',
      child: Column(
        children: [
          _totalRow('المجموع الفرعي', '${_subtotal.toStringAsFixed(2)} ج.م'),
          const SizedBox(height: 8),
          _buildDeliveryFeeRow(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _totalRow(
            'المبلغ الإجمالي',
            _total == null
                ? '—'
                : '${_total!.toStringAsFixed(2)} ج.م',
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryFeeRow() {
    if (_isQuoting) {
      return Row(
        children: const [
          Text(
            'رسوم التوصيل',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
          Spacer(),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ],
      );
    }

    if (_quoteError != null) {
      return Row(
        children: [
          const Text(
            'رسوم التوصيل',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchQuote,
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      );
    }

    return _totalRow(
      'رسوم التوصيل',
      _mode == FulfilmentMode.pickup
          ? 'مجاناً (استلام)'
          : '${(_deliveryFee ?? 0).toStringAsFixed(2)} ج.م',
    );
  }

  Widget _totalRow(String label, String value, {bool emphasize = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasize ? 15 : 13,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
            color:
                emphasize ? AppColors.textPrimary : AppColors.textSecondary,
            fontFamily: 'Cairo',
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 17 : 13,
            fontWeight: FontWeight.bold,
            color: emphasize ? AppColors.primary : AppColors.textPrimary,
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
        child: WaslButton(
          label: _total == null
              ? 'في انتظار حساب التوصيل'
              : 'تأكيد الطلب — ${_total!.toStringAsFixed(2)} ج.م',
          icon: Icons.check_circle_outline_rounded,
          loading: _isSubmitting,
          onPressed: _canSubmit ? _confirmOrder : null,
        ),
      ),
    );
  }

  /// Final confirmation before anything is sent.
  Future<void> _confirmOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          ),
          title: const Text(
            'تأكيد الطلب',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('المطعم', _cart.merchantName),
              _confirmRow('عدد الأصناف', '${_cart.itemCount}'),
              _confirmRow(
                'طريقة الاستلام',
                _mode == FulfilmentMode.delivery ? 'توصيل' : 'استلام من المطعم',
              ),
              _confirmRow(
                'الدفع',
                _payment == CheckoutPaymentMethod.cash
                    ? 'نقداً عند الاستلام'
                    : 'محفظة فلاش',
              ),
              const Divider(height: 18),
              _confirmRow(
                'الإجمالي',
                '${_total!.toStringAsFixed(2)} ج.م',
                bold: true,
              ),
            ],
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
              child: const Text('تأكيد',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) await _submit();
  }

  Widget _confirmRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: bold ? 15 : 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: bold ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sends the cart through the platform's existing `/orders/create` endpoint —
  /// the same one the order-from-anywhere flow uses — so a restaurant order is a
  /// real order and shows up in "طلباتي" straight away.
  ///
  /// That endpoint carries the items as a single text block rather than
  /// itemised rows, so the cart is serialised into `itemsDescription`. The line
  /// detail (size, addons, per-line note and total) is all preserved in that
  /// text, which is what the driver reads.
  /// الشاشة عندها `_isSubmitting` بيتحكم في شكل الزرار، لكنه مكانش بيمنع
  /// استدعاء تاني — لمستين سريعتين كانوا يبعتوا أوردرين. الحارس بيمنع التاني
  /// من أصله، و`_isSubmitting` فضل زي ما هو عشان الواجهة متتغيرش.
  Future<void> _submit() => guardedSubmit(_placeOrder);

  Future<void> _placeOrder() async {
    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      await prefs.setString('last_delivery_address', address);
    }

    final customerId = prefs.getInt('user_id');
    final customerName = prefs.getString('user_name') ?? 'عميل';
    final customerPhone = prefs.getString('user_phone') ?? '';

    if (customerId == null) {
      _fail('لم نتمكن من التعرف على حسابك، سجّل الدخول مرة أخرى');
      return;
    }

    // The destination must be a real point: the customer's GPS when we have it,
    // otherwise the restaurant's own location so the order is still routable.
    final destLat = _position?.latitude ?? _cart.merchantLat;
    final destLng = _position?.longitude ?? _cart.merchantLng;
    if (destLat == null || destLng == null) {
      _fail('فعّل خدمة الموقع لتحديد مكان التوصيل');
      return;
    }

    final note = _noteController.text.trim();
    final description = [
      if (note.isNotEmpty) 'ملاحظات للكابتن: $note',
      if (_mode == FulfilmentMode.pickup) 'استلام من المطعم (بدون توصيل)',
      'الدفع: نقداً عند الاستلام',
    ].join('\n');

    // 🛒 السلة بتتبعت كأصناف منظّمة — منتج وحجم وإضافات وكمية. السيرفر هو
    // اللي بيجيب الأسعار من كتالوج التاجر ويحسب الإجمالي، فالتطبيق مش بيبعت
    // فلوس أصلاً.
    final result = await _orders.createOrder(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      categoryType: 'مطاعم',
      orderType: 'restaurant',
      merchantId: _cart.merchantId,
      storeName: _cart.merchantName,
      items: _cart.asOrderItems,
      itemsDescription: description,
      deliveryAddressText:
          address.isEmpty ? 'استلام من المطعم' : address,
      latitude: destLat,
      longitude: destLng,
      pickupLatitude: _cart.merchantLat,
      pickupLongitude: _cart.merchantLng,
      pickupAddressText: _cart.merchantName,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] != true) {
      _showError(
        (result['message'] ?? 'تعذّر إرسال الطلب، حاول مرة أخرى').toString(),
      );
      return;
    }

    final orderId = _extractOrderId(result['data']);

    final summary = OrderPlacedSummary(
      orderId: orderId,
      merchantName: _cart.merchantName,
      itemCount: _cart.itemCount,
      subtotal: _subtotal,
      deliveryFee: _deliveryFee ?? 0,
      total: _total ?? _subtotal,
      isDelivery: _mode == FulfilmentMode.delivery,
      address: address,
      paidByWallet: _payment == CheckoutPaymentMethod.wallet,
    );

    // The order now lives on the server, so the cart's job is done.
    _cart.clear();

    // 🔄 The shell's "طلباتي" tab is built once at app start and kept alive in
    // an IndexedStack, so nothing there re-fetches on its own. Refreshing here
    // — the moment the server confirmed the order — is what puts it under
    // الطلبات الحالية immediately, whichever button the customer taps next.
    // Deliberately not awaited: the order is already created, and the
    // confirmation screen must not wait on a second round trip.
    unawaited(WaslMyOrdersScreen.refreshNow());

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WaslOrderPlacedScreen(summary: summary),
      ),
    );
  }

  int? _extractOrderId(dynamic data) {
    if (data is Map) {
      final raw = data['id'] ?? data['orderId'] ?? data['order']?['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    return null;
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showError(message);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
      ),
    );
  }
}
