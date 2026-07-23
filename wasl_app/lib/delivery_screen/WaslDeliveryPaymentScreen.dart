import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslDeliveryPaymentScreen extends StatefulWidget {
  const WaslDeliveryPaymentScreen({Key? key}) : super(key: key);

  @override
  State<WaslDeliveryPaymentScreen> createState() => _WaslDeliveryPaymentScreenState();
}

class _WaslDeliveryPaymentScreenState extends State<WaslDeliveryPaymentScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'wallet'; // طريقة الدفع الافتراضية
  double _currentBalance = 0.00; // رصيد ديناميكي يتم سحبه من قاعدة البيانات حياً

  int? _driverId;
  bool _isLoading = false; // مؤشر انتظار الشحن والاتصال بالسيرفر

  // المبالغ السريعة للشحن
  final List<int> _quickAmounts = [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  // 🎯 جلب كود هوية المندوب المحفوظ محلياً ومزامنة الرصيد فوراً
  void _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverId = prefs.getInt('user_id') ?? 21; // ديفولت 21 للتست
    });
    // نجلب رصيده الحقيقي الفريش لايف من الداتابيز
    _fetchLiveBalance();
  }

  // 📡 سحب الرصيد التراكمي المحدث حياً من قاعدة البيانات (PostgreSQL)
  Future<void> _fetchLiveBalance() async {
    if (_driverId == null) return;
    final result = await _ordersService.getDriverDashboardStats(_driverId!);
    if (result['success'] == true && mounted) {
      setState(() {
        _currentBalance = double.tryParse(result['balance']?.toString() ?? '0') ?? 0.0;
      });
    }
  }

  void _handlePayment() async {
    final String amountText = _amountController.text.trim();
    if (amountText.isEmpty || double.tryParse(amountText) == null || double.parse(amountText) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برجاء إدخال مبلغ شحن صحيح أولاً ⚠️', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final amount = double.parse(amountText);

    final requestResult = await _ordersService.requestDriverTopUp(
      driverId: _driverId!,
      amount: amount,
    );

    if (requestResult['success'] != true) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(requestResult['message'] ?? 'فشل طلب الشحن', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
      return;
    }

    final webhookResult = await _ordersService.processPaymentWebhook(
      driverId: _driverId!,
      amount: amount,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (webhookResult['success'] == true) {
      _amountController.clear();
      await _fetchLiveBalance();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم شحن ${amount.toStringAsFixed(0)} ج.م بنجاح! رصيدك: ${_currentBalance.toStringAsFixed(0)} ج.م', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(webhookResult['message'] ?? 'فشل تأكيد الشحن', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'شحن رصيد المحفظة',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1️⃣ كارت رصيد المحفظة الحالي الفخم بالتدرج اللوني العميق لـ FLASH
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'الرصيد الحالي بالمحفظة',
                          style: TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_currentBalance.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Cairo', letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.security_rounded, color: Colors.amber, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'محفظة رقمية مشفرة وآمنة',
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2️⃣ حقل إدخال مبلغ الشحن المخصص
                  _buildSectionTitle('أدخل مبلغ الشحن بالجنيه'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: AppColors.textPrimary.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                        suffixText: 'جنيه مصري',
                        suffixStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.textSecondary, size: 20),
                        fillColor: AppColors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3️⃣ أزرار المبالغ السريعة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _quickAmounts.map((amount) {
                      return InkWell(
                        onTap: () => _selectQuickAmount(amount),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 76) / 4,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                          ),
                          child: Text(
                            '+$amount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Cairo'),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 4️⃣ طرق الدفع المتاحة لـ فلاش
                  _buildSectionTitle('اختر طريقة الدفع'),
                  const SizedBox(height: 10),
                  _buildPaymentMethodTile(
                    id: 'wallet',
                    title: 'المحافظ الإلكترونية (فودافون كاش، اتصالات...)',
                    sub: 'شحن فوري ومباشر عبر أي محفظة كاش',
                    icon: Icons.phone_android_rounded,
                  ),
                  _buildPaymentMethodTile(
                    id: 'card',
                    title: 'البطاقة الائتمانية (Visa / MasterCard)',
                    sub: 'ادفع بأمان باستخدام بطاقتك البنكية',
                    icon: Icons.credit_card_rounded,
                  ),
                  _buildPaymentMethodTile(
                    id: 'fawry',
                    title: 'كود فوري (Fawry Pay)',
                    sub: 'طلب كود الدفع والسداد من أقرب منفذ فوري',
                    icon: Icons.pix_rounded,
                  ),
                  const SizedBox(height: 28),

                  // 5️⃣ زر تأكيد الشحن والاتصال ببوابة الدفع (محدث بمؤشر التحميل والتأمين)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handlePayment,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded, size: 20),
                    label: Text(
                        _isLoading ? 'جاري الاتصال بـ بوابة الدفع...' : 'تأكيد شحن الحساب الآن',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String id,
    required String title,
    required String sub,
    required IconData icon,
  }) {
    bool isSelected = _selectedMethod == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.06) : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                    width: isSelected ? 5 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}