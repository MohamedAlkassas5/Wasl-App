import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';

import 'package:wasl_app/customer_screen/screens/home/WaslCustomerHomeScreen.dart';

import 'data/cart_controller.dart';

/// What the checkout screen hands over to the confirmation screen.
class OrderPlacedSummary {
  /// Server-assigned order id, present once the order was actually created.
  final int? orderId;
  final String merchantName;
  final int itemCount;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final bool isDelivery;
  final String address;
  final bool paidByWallet;

  const OrderPlacedSummary({
    this.orderId,
    required this.merchantName,
    required this.itemCount,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.isDelivery,
    required this.address,
    required this.paidByWallet,
  });
}

/// Shown after checkout.
///
/// The order has already been created on the server by this point, so this
/// screen confirms a real order and shows its id. It never claims success for
/// something that was not actually sent — checkout keeps the customer on the
/// form and shows the error if the request failed.
class WaslOrderPlacedScreen extends StatelessWidget {
  final OrderPlacedSummary summary;

  const WaslOrderPlacedScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 50, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'تم إرسال طلبك بنجاح!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  summary.orderId != null
                      ? 'طلبك رقم FL-${summary.orderId} في انتظار عروض الكباتن، وهتلاقيه في "طلباتي" ضمن الطلبات الحالية.'
                      : 'طلبك اتسجّل، وهتلاقيه في "طلباتي" ضمن الطلبات الحالية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: AppColors.textSecondary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSummaryCard(),
              const SizedBox(height: 20),
              WaslButton(
                label: 'تتبّع طلباتي',
                icon: Icons.receipt_long_rounded,
                onPressed: () {
                  // Back to the shell, which opens on "طلباتي" so the new order
                  // is right there under الطلبات الحالية.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  WaslHomeShell.openOrdersTab();
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text(
                  'العودة إلى الرئيسية',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
      ),
      child: Column(
        children: [
          _row('المطعم', summary.merchantName),
          _row('عدد الأصناف', '${summary.itemCount}'),
          _row(
            'طريقة الاستلام',
            summary.isDelivery ? 'توصيل' : 'استلام من المطعم',
          ),
          if (summary.isDelivery && summary.address.isNotEmpty)
            _row('العنوان', summary.address),
          _row(
            'الدفع',
            summary.paidByWallet ? 'محفظة فلاش' : 'نقداً عند الاستلام',
          ),
          const Divider(height: 22),
          _row('المجموع الفرعي', '${summary.subtotal.toStringAsFixed(2)} ج.م'),
          _row(
            'رسوم التوصيل',
            summary.isDelivery
                ? '${summary.deliveryFee.toStringAsFixed(2)} ج.م'
                : 'مجاناً',
          ),
          const Divider(height: 22),
          _row(
            'الإجمالي',
            '${summary.total.toStringAsFixed(2)} ج.م',
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasize ? 15 : 12,
              fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
              color:
                  emphasize ? AppColors.textPrimary : AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: emphasize ? 17 : 12,
                fontWeight: FontWeight.bold,
                color: emphasize ? AppColors.primary : AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
