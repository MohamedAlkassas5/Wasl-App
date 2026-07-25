import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🎯 استيراد الـ Provider لقراءة جلسة الكابتن النشطة
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/providers/user_provider.dart'; // 🎯 استيراد الـ UserProvider الخاص بك ديناميكياً
import 'package:wasl_app/services/orders_service.dart'; // 🎯 استيراد الـ Service الخاصة بالطلبات

class WaslSubmitBidDialog extends StatefulWidget {
  final String orderId;
  // 💰 Distance-based fee suggested by the backend pricing engine. Pre-fills
  // the input so the driver confirms/adjusts rather than guessing.
  final double? suggestedFee;
  final Function(double price, int minutes)? onSubmit;

  const WaslSubmitBidDialog({
    Key? key,
    required this.orderId,
    this.suggestedFee,
    this.onSubmit,
  }) : super(key: key);

  @override
  State<WaslSubmitBidDialog> createState() => _WaslSubmitBidDialogState();
}

class _WaslSubmitBidDialogState extends State<WaslSubmitBidDialog> {
  final _feeController = TextEditingController();
  final _timeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final FlutterOrdersService _ordersService = FlutterOrdersService();

  @override
  void initState() {
    super.initState();
    // Pre-fill the pricing-engine suggestion (city 20 / nearby 40 / dynamic).
    if (widget.suggestedFee != null && widget.suggestedFee! > 0) {
      _feeController.text = widget.suggestedFee!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _feeController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _submitBid() async {
    if (_formKey.currentState!.validate()) {
      if (_feeController.text.isEmpty || _timeController.text.isEmpty) return;

      // إظهار مؤشر تحميل دائري لحماية العملية من النقرات المتكررة
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      final double price = double.parse(_feeController.text.trim());
      final int minutes = int.parse(_timeController.text.trim());

      // 🎯 [تم التحديث لايف]: سحب الـ ID الفعلي والـ Dynamic للكابتن الحالي من الـ Provider
      final currentDriverId = Provider.of<UserProvider>(context, listen: false).userId;

      // 🛡️ حماية لوجستية أمنية: رفض ترحيل المزايدة لو السيستم مقراش الـ ID التلقائي من قاعدة البيانات
      if (currentDriverId == null || currentDriverId == 0) {
        if (!context.mounted) return;
        Navigator.pop(context); // إغلاق مؤشر التحميل أولاً
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ في تحديد هوية المندوب التلقائية من قاعدة البيانات.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
        return;
      }

      // استدعاء الـ Service وإرسال البيانات التلقائية للسيرفر
      final result = await _ordersService.submitOffer(
        orderId: int.tryParse(widget.orderId) ?? 1, // 👈 حماية تمنع الكراش لو كان الـ ID نصي مستقبلاً
        driverId: currentDriverId, // 👈 بياخد الـ ID التلقائي الحقيقي للكابتن (21) من الداتابيز مباشرة
        deliveryFee: price,
        estimatedTime: minutes,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // إغلاق مؤشر التحميل (Loading Dialog)

      if (result['success'] == true) {
        Navigator.pop(context); // إغلاق الـ Dialog الأساسي لتقديم العرض

        if (widget.onSubmit != null) {
          widget.onSubmit!(price, minutes);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال عرضك بنجاح للعميل، بانتظار الموافقة... 🚀', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'فشل تقديم العرض، يرجى مراجعة رصيد المحفظة', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.gavel_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'تقديم عرض سعر توصيل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary, fontFamily: 'Cairo'),
            ),
          ],
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'سعر التوصيل المقترح (ج.م)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'برجاء إدخال السعر';
                    if (double.tryParse(value) == null || double.parse(value) <= 0) return 'أدخل سعر صحيح';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'مثال: 25',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.normal),
                    fillColor: AppColors.background,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (widget.suggestedFee != null && widget.suggestedFee! > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'السعر المقترح حسب المسافة: ${widget.suggestedFee!.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                    'وقت الوصول المتوقع للمحل (بالدقائق)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _timeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'برجاء إدخال الوقت';
                    if (int.tryParse(value) == null || int.parse(value) <= 0) return 'أدخل وقت صحيح';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'مثال: 20',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.normal),
                    fillColor: AppColors.background,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: _submitBid,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('إرسال العرض', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}