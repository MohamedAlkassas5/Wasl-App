import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslOrderTrackingScreen.dart';

class WaslOrderOffersScreen extends StatefulWidget {
  final int orderId;
  const WaslOrderOffersScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<WaslOrderOffersScreen> createState() => _WaslOrderOffersScreenState();
}

class _WaslOrderOffersScreenState extends State<WaslOrderOffersScreen> {
  List<dynamic> _offers = [];
  bool _isLoading = true;
  bool _isAccepting = false; // 🎯 مؤشر التحميل الخاص بقبول العرض لمنع الضرب المتكرر

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  // جلب العروض التنافسية المقدمة من مناديب كوم حمادة للطلب
  Future<void> _fetchOffers() async {
    final result = await FlutterOrdersService().getOrderOffers(widget.orderId);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _offers = result['offers'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 🎯 [تم التحديث]: معالجة قبول العرض والتنقل الفوري للشاشة التالية وتمرير البيانات الحية للعميل
  void _handleAcceptOffer(int orderId, int offerId) async {
    setState(() {
      _isAccepting = true;
    });

    // استدعاء خدمة الأوردرات المحدثة
    final result = await FlutterOrdersService().acceptOffer(
      orderId: orderId,
      offerId: offerId,
    );

    setState(() {
      _isAccepting = false;
    });

    if (result['success'] == true) {
      // 🟢 نجاح: تحول الأوردر لـ ACCEPTED وحصنته الداتابيز ضد الحذف التلقائي
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول عرض الكابتن بنجاح! جاري بدء الرحلة 🏍️🔥', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 🎯 [تم الإصلاح الحاسم]: جلب كائن الـ order الراجع ببيانات الـ relations كاملة من السيرفر
      // في حالة لم يرسل الـ Service الكائن كاملاً، نقوم بتجهيز Map مبدئي يحمل الـ id والـ status
      final Map<String, dynamic> liveOrderData = result['order'] ?? {
        'id': widget.orderId,
        'status': 'accepted',
      };

      // 🎯 [تم الإصلاح الحاسم]: التوجيه اللحظي للعميل لشاشة تتبع الرحلة وتمرير الـ orderData الحقيقي
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaslOrderTrackingScreen(orderData: liveOrderData), // 👈 يوجه العميل لايف بالبيانات الحقيقية
        ),
      );
    } else {
      // 🔴 فشل في قبول العرض
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'عفواً، فشل قبول العرض', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        title: const Text('عروض الكباتن المتاحة 🏁', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary), onPressed: _fetchOffers)],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _offers.isEmpty
            ? const Center(child: Text('بانتظار تقديم أول عرض سعر من كباتن كوم حمادة... ⏳', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _offers.length,
          itemBuilder: (context, index) {
            final offer = _offers[index];
            final driverName = offer['driver']?['name'] ?? 'كابتن وصل';
            final fee = offer['deliveryFee'];
            final time = offer['estimatedTime'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const CircleAvatar(radius: 24, backgroundColor: AppColors.background, child: Icon(Icons.delivery_dining, color: AppColors.primary)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                        const SizedBox(height: 2),
                        Text('يصلك خلال $time دقيقة ⏱️', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$fee ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success, fontFamily: 'Cairo')),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: _isAccepting
                              ? null
                              : () => _handleAcceptOffer(widget.orderId, offer['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isAccepting
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : const Text('قبول', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ),
                      )
                    ],
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}