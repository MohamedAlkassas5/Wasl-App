import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslMyOrdersScreen.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/services/zones_service.dart';

/// Ordering from a pharmacy.
///
/// Deliberately a free-text request rather than a catalog: pharmacies do not
/// publish stock here, and what a customer needs is usually written on a
/// prescription. So the driver is told the pharmacy, the medicines and an
/// optional photo, and the real price is settled at the counter — which is why
/// the amount entered here is explicitly an estimate.
///
/// Reuses the same visual language and the same orders API as every other
/// flow; nothing new is invented for pharmacy.
class WaslPharmacyRequestScreen extends StatefulWidget {
  const WaslPharmacyRequestScreen({super.key});

  @override
  State<WaslPharmacyRequestScreen> createState() =>
      _WaslPharmacyRequestScreenState();
}

class _WaslPharmacyRequestScreenState extends State<WaslPharmacyRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pharmacyController = TextEditingController();
  final _medicinesController = TextEditingController();
  final _addressController = TextEditingController();
  final _estimateController = TextEditingController();

  final _orders = FlutterOrdersService();
  final _zones = ZonesService();

  File? _prescription;
  Position? _position;
  bool _isLocating = false;
  bool _isSubmitting = false;

  double? _deliveryFee;
  String? _quoteError;

  @override
  void initState() {
    super.initState();
    _fetchQuote();
    _detectLocation();
  }

  @override
  void dispose() {
    _pharmacyController.dispose();
    _medicinesController.dispose();
    _addressController.dispose();
    _estimateController.dispose();
    super.dispose();
  }

  /// The fee comes from the customer's saved area — same rule as every other
  /// normal order. Never computed here.
  Future<void> _fetchQuote() async {
    final result = await _zones.getNormalQuote();
    if (!mounted) return;
    setState(() {
      if (result['success'] == true) {
        _deliveryFee = (result['data']?['deliveryFee'] as num?)?.toDouble();
        _quoteError = _deliveryFee == null ? 'تعذّر قراءة سعر التوصيل' : null;
      } else {
        _quoteError = (result['message'] ?? 'تعذّر حساب سعر التوصيل').toString();
      }
    });
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = position;
        _isLocating = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickPrescription() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _prescription = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) {
      _snack('فعّل خدمة الموقع لتحديد مكان التوصيل 📍', AppColors.danger);
      return;
    }

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getInt('user_id');
    if (customerId == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _snack('سجّل الدخول مرة أخرى', AppColors.danger);
      return;
    }

    final result = await _orders.createOrderWithImage(
      customerId: customerId,
      customerName: prefs.getString('user_name') ?? 'عميل',
      customerPhone: prefs.getString('user_phone') ?? '',
      categoryType: 'صيدلية',
      orderType: 'pharmacy',
      pharmacyName: _pharmacyController.text.trim(),
      storeName: _pharmacyController.text.trim(),
      itemsDescription: _medicinesController.text.trim(),
      deliveryAddressText: _addressController.text.trim(),
      itemsPrice: double.tryParse(_estimateController.text.trim()) ?? 0,
      latitude: _position!.latitude,
      longitude: _position!.longitude,
      itemsImage: _prescription,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] != true) {
      _snack(
        (result['message'] ?? 'تعذّر إرسال الطلب').toString(),
        AppColors.danger,
      );
      return;
    }

    _snack('تم إرسال طلبك للصيدلية 🏥', AppColors.success);
    // 🔄 The shell keeps its own "طلباتي" instance alive; refresh it too, not
    // just the one this navigation is about to build.
    unawaited(WaslMyOrdersScreen.refreshNow());
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WaslMyOrdersScreen()),
    );
  }

  void _snack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          'طلب من صيدلية',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 16,
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('🏥 اسم الصيدلية'),
                        TextFormField(
                          controller: _pharmacyController,
                          decoration: _input('مثال: صيدلية العزبي - شارع الجمهورية'),
                          style: _fieldStyle,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'اكتب اسم الصيدلية'
                              : null,
                        ),
                        const SizedBox(height: 18),

                        _label('💊 الأدوية والكميات'),
                        TextFormField(
                          controller: _medicinesController,
                          maxLines: 5,
                          decoration: _input(
                            'مثال:\nبانادول إكسترا — علبة\nفيتامين سي ١٠٠٠ — علبتين',
                          ),
                          style: _fieldStyle,
                          validator: (v) => (v ?? '').trim().length < 3
                              ? 'اكتب الأدوية المطلوبة'
                              : null,
                        ),
                        const SizedBox(height: 18),

                        _label('📄 صورة الروشتة (اختياري)'),
                        _prescriptionPicker(),
                        const SizedBox(height: 18),

                        _label('💰 السعر التقديري (اختياري)'),
                        TextFormField(
                          controller: _estimateController,
                          keyboardType: TextInputType.number,
                          decoration: _input('مثال: 150'),
                          style: _fieldStyle,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 4),
                          child: Text(
                            'ده تقدير بس — الكابتن هيبعتلك السعر الحقيقي من الصيدلية قبل ما يشتري',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        _label('📍 عنوان التوصيل'),
                        TextFormField(
                          controller: _addressController,
                          decoration: _input('الشارع، رقم العمارة، الدور...')
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: _isLocating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(
                                      Icons.my_location,
                                      color: _position == null
                                          ? AppColors.textSecondary
                                          : AppColors.success,
                                    ),
                              onPressed: _detectLocation,
                              tooltip: 'تحديد موقعي',
                            ),
                          ),
                          style: _fieldStyle,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'اكتب عنوان التوصيل'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _feeSummary(),
                      ],
                    ),
                  ),
                ),
                _submitBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _prescriptionPicker() {
    return InkWell(
      onTap: _pickPrescription,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _prescription == null
                ? const Color(0xFFE2E8F0)
                : AppColors.success,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _prescription == null
                  ? Icons.add_a_photo_outlined
                  : Icons.check_circle,
              size: 20,
              color: _prescription == null
                  ? AppColors.textSecondary
                  : AppColors.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _prescription == null
                    ? 'إرفاق صورة الروشتة'
                    : 'تم إرفاق الروشتة ✅',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: _prescription == null
                      ? AppColors.textSecondary
                      : AppColors.success,
                ),
              ),
            ),
            if (_prescription != null)
              TextButton(
                onPressed: () => setState(() => _prescription = null),
                child: const Text(
                  'إزالة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feeSummary() {
    final Color colour;
    final String text;
    if (_quoteError != null) {
      colour = AppColors.danger;
      text = _quoteError!;
    } else if (_deliveryFee == null) {
      colour = AppColors.textSecondary;
      text = 'جاري حساب سعر التوصيل...';
    } else {
      colour = AppColors.success;
      text =
          'سعر التوصيل: ${_deliveryFee!.toStringAsFixed(0)} ج.م — يُدفع مع قيمة الأدوية عند الاستلام';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 18, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: colour,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: const Color(0xFFCBD5E1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white),
                )
              : const Text(
                  'إرسال الطلب للصيدلية',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
        ),
      ),
    );
  }

  static const _fieldStyle =
      TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textPrimary);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12.5,
          color: Color(0xFF94A3B8),
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}
