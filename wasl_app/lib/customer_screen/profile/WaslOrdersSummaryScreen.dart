import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslOrdersSummaryScreen extends StatefulWidget {
  const WaslOrdersSummaryScreen({Key? key}) : super(key: key);

  @override
  State<WaslOrdersSummaryScreen> createState() => _WaslOrdersSummaryScreenState();
}

class _WaslOrdersSummaryScreenState extends State<WaslOrdersSummaryScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  int? _customerId;
  bool _isLoading = true;
  int _completedOrders = 0;
  double _totalSpent = 0;

  @override
  void initState() {
    super.initState();
    _loadWalletSummary();
  }

  Future<void> _loadWalletSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id') ?? 1;
    setState(() => _customerId = id);

    final result = await _ordersService.getCustomerOrders(id);
    if (!mounted) return;

    if (result['success'] == true) {
      final List<dynamic> orders = result['data'] ?? [];
      double spent = 0;
      int completed = 0;

      for (final order in orders) {
        if (order['status']?.toString().toLowerCase() == 'completed') {
          completed++;
          final deliveryFee = double.tryParse(order['finalDeliveryFee']?.toString() ?? '0') ?? 0;
          final itemsPrice = double.tryParse(order['itemsPrice']?.toString() ?? '0') ?? 0;
          spent += deliveryFee + itemsPrice;
        }
      }

      setState(() {
        _completedOrders = completed;
        _totalSpent = spent;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          // ⚠️ مش محفظة. العميل مالوش رصيد ولا محفظة في النظام أصلاً — الشاشة
          // دي ملخّص لمصاريف طلباته + طرق الدفع المتاحة. الاسم القديم
          // («المحفظة والدفع» وكلاس WaslCustomerWalletScreen) كان بيوحي بحاجة
          // مش موجودة، وده بالظبط اللي ممكن يخلي حد يبني عليها بعدين.
          'ملخص طلباتي',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadWalletSummary();
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.logoGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إجمالي مصروفاتك',
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Cairo',
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_totalSpent.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_completedOrders طلب مكتمل',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Cairo',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPaymentCard(
                    icon: Icons.payments_rounded,
                    title: 'الدفع عند الاستلام',
                    subtitle: 'الطريقة الوحيدة المتاحة حالياً في كوم حمادة — ادفع نقداً للكابتن عند وصول الطلب.',
                    isActive: true,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'فودافون كاش / إنستا باي',
                    subtitle: 'سيتم تفعيل الدفع الإلكتروني في التحديث القادم بعد توسع المنصة.',
                    isActive: false,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'طلبات أكثر من 300 ج.م قد تتطلب تحويل مقدم تأكيد — سيتم إعلامك عند إنشاء الطلب.',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textSecondary.withOpacity(0.9),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_customerId != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'معرّف الحساب: #$_customerId',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary.withOpacity(0.3) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary.withOpacity(0.1) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: isActive ? AppColors.primary : AppColors.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'مفعّل',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
