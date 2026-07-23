import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';

class WaslOrderInvoiceScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const WaslOrderInvoiceScreen({Key? key, required this.orderData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String safeOrderId = orderData['id']?.toString() ?? '';
    final double deliveryFee = double.tryParse(orderData['finalDeliveryFee']?.toString() ?? '25.0') ?? 25.0;
    final double itemsPrice = double.tryParse(orderData['itemsPrice']?.toString() ?? '0.0') ?? 0.0;
    final double totalAmount = deliveryFee + itemsPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        title: const Text('مراجعة الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.receipt_long_rounded, color: AppColors.warning),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'الكابتن اشترى المنتجات ورفع قيمة الفاتورة. راجع المبلغ قبل الاستلام.',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(color: AppColors.textPrimary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('فاتورة الطلب WS-$safeOrderId', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const Divider(height: 24, thickness: 1),
                      _buildInvoiceRow('قيمة المشتريات:', '${itemsPrice.toStringAsFixed(2)} ج.م'),
                      const SizedBox(height: 10),
                      _buildInvoiceRow('رسوم التوصيل:', '${deliveryFee.toStringAsFixed(2)} ج.م'),
                      const Divider(height: 24, thickness: 1),
                      _buildInvoiceRow('الإجمالي عند الاستلام (كاش):', '${totalAmount.toStringAsFixed(2)} ج.م', isTotal: true),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'موافق — متابعة التتبع',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: isTotal ? 14 : 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: AppColors.textPrimary)),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: isTotal ? 16 : 13, fontWeight: FontWeight.bold, color: isTotal ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}
