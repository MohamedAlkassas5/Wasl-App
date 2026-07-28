// import 'package:flutter/material.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/services/orders_service.dart';
// import 'package:wasl_app/customer_screen/cart_orders/WaslOrderTrackingScreen.dart';
//
// class WaslOrderOffersScreen extends StatefulWidget {
//   final int orderId;
//   const WaslOrderOffersScreen({Key? key, required this.orderId}) : super(key: key);
//
//   @override
//   State<WaslOrderOffersScreen> createState() => _WaslOrderOffersScreenState();
// }
//
// class _WaslOrderOffersScreenState extends State<WaslOrderOffersScreen> {
//   List<dynamic> _offers = [];
//   bool _isLoading = true;
//   bool _isAccepting = false; // 🎯 مؤشر التحميل الخاص بقبول العرض لمنع الضرب المتكرر
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchOffers();
//   }
//
//   // جلب العروض التنافسية المقدمة من مناديب كوم حمادة للطلب
//   Future<void> _fetchOffers() async {
//     final result = await FlutterOrdersService().getOrderOffers(widget.orderId);
//     if (!mounted) return;
//
//     if (result['success'] == true) {
//       setState(() {
//         _offers = result['offers'] ?? [];
//         _isLoading = false;
//       });
//     } else {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   // 🎯 [تم التحديث]: معالجة قبول العرض والتنقل الفوري للشاشة التالية وتمرير البيانات الحية للعميل
//   void _handleAcceptOffer(int orderId, int offerId) async {
//     setState(() {
//       _isAccepting = true;
//     });
//
//     // استدعاء خدمة الأوردرات المحدثة
//     final result = await FlutterOrdersService().acceptOffer(
//       orderId: orderId,
//       offerId: offerId,
//     );
//
//     setState(() {
//       _isAccepting = false;
//     });
//
//     if (result['success'] == true) {
//       // 🟢 نجاح: تحول الأوردر لـ ACCEPTED وحصنته الداتابيز ضد الحذف التلقائي
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('تم قبول عرض الكابتن بنجاح! جاري بدء الرحلة 🏍️🔥', style: TextStyle(fontFamily: 'Cairo')),
//           backgroundColor: Color(0xFF22C55E),
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//
//       // 🎯 [تم الإصلاح الحاسم]: جلب كائن الـ order الراجع ببيانات الـ relations كاملة من السيرفر
//       // في حالة لم يرسل الـ Service الكائن كاملاً، نقوم بتجهيز Map مبدئي يحمل الـ id والـ status
//       final Map<String, dynamic> liveOrderData = result['order'] ?? {
//         'id': widget.orderId,
//         'status': 'accepted',
//       };
//
//       // 🎯 [تم الإصلاح الحاسم]: التوجيه اللحظي للعميل لشاشة تتبع الرحلة وتمرير الـ orderData الحقيقي
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => WaslOrderTrackingScreen(orderData: liveOrderData), // 👈 يوجه العميل لايف بالبيانات الحقيقية
//         ),
//       );
//     } else {
//       // 🔴 فشل في قبول العرض
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(result['message'] ?? 'عفواً، فشل قبول العرض', style: const TextStyle(fontFamily: 'Cairo')),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         title: const Text('عروض الكباتن المتاحة 🏁', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
//         centerTitle: true,
//         actions: [IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary), onPressed: _fetchOffers)],
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: _isLoading
//             ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
//             : _offers.isEmpty
//             ? const Center(child: Text('بانتظار تقديم أول عرض سعر من كباتن كوم حمادة... ⏳', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)))
//             : ListView.builder(
//           padding: const EdgeInsets.all(16),
//           itemCount: _offers.length,
//           itemBuilder: (context, index) {
//             final offer = _offers[index];
//             final driverName = offer['driver']?['name'] ?? 'كابتن وصل';
//             final fee = offer['deliveryFee'];
//             final time = offer['estimatedTime'];
//
//             return Container(
//               margin: const EdgeInsets.only(bottom: 12),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
//               child: Row(
//                 children: [
//                   const CircleAvatar(radius: 24, backgroundColor: AppColors.background, child: Icon(Icons.delivery_dining, color: AppColors.primary)),
//                   const SizedBox(width: 14),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                         const SizedBox(height: 2),
//                         Text('يصلك خلال $time دقيقة ⏱️', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
//                       ],
//                     ),
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text('$fee ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success, fontFamily: 'Cairo')),
//                       const SizedBox(height: 6),
//                       SizedBox(
//                         height: 32,
//                         child: ElevatedButton(
//                           onPressed: _isAccepting
//                               ? null
//                               : () => _handleAcceptOffer(widget.orderId, offer['id']),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.primary,
//                             elevation: 0,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                           ),
//                           child: _isAccepting
//                               ? const SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
//                           )
//                               : const Text('قبول', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                         ),
//                       )
//                     ],
//                   )
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

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
  int? _acceptingOfferId; // 🎯 لتحديد العرض الذي يتم قبوله حالياً وإظهار مؤشر التحميل عليه فقط

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  // 🎯 جلب عروض الكباتن الحية مع فحص دقيق للـ Data الراجعة
  Future<void> _fetchOffers() async {
    setState(() => _isLoading = true);
    final result = await FlutterOrdersService().getOrderOffers(widget.orderId);
    if (!mounted) return;

    if (result['success'] == true) {
      final rawData = result['offers'] ?? result['data'] ?? [];
      setState(() {
        _offers = rawData is List ? rawData : [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 🎯 معالجة قبول العرض والتوجيه لشاشة التتبع
  Future<void> _handleAcceptOffer(int offerId) async {
    setState(() => _acceptingOfferId = offerId);

    final result = await FlutterOrdersService().acceptOffer(
      orderId: widget.orderId,
      offerId: offerId,
    );

    if (!mounted) return;
    setState(() => _acceptingOfferId = null);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم قبول عرض الكابتن بنجاح! جاري الانطلاق 🏍️⚡',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final Map<String, dynamic> liveOrderData = result['order'] ?? {
        'id': widget.orderId,
        'status': 'accepted',
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaslOrderTrackingScreen(orderData: liveOrderData),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'عفواً، فشل قبول العرض',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.redAccent,
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
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          'عروض الكباتن المتاحة 🏁',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _fetchOffers,
            tooltip: 'تحديث العروض',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        // 🎯 تفعيل السحب للتحديث للأسفل
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _fetchOffers,
          child: _isLoading
              ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
              : _offers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _offers.length,
            itemBuilder: (context, index) {
              final offer = _offers[index];
              final offerId = offer['id'];
              final driver = offer['driver'] ?? {};
              final driverName = driver['name'] ?? 'كابتن فلاش';
              final fee = offer['deliveryFee'] ?? offer['amount'] ?? 0;
              final time = offer['estimatedTime'] ?? offer['duration'] ?? '--';
              final rating = driver['rating']?.toString() ?? '5.0';

              final isAcceptingThis = _acceptingOfferId == offerId;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    // 🛵 أيقونة أو صورة الكابتن
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.logoGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 📝 تفاصيل الكابتن والوقت
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                driverName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFB800),
                                size: 16,
                              ),
                              Text(
                                rating,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_filled_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'يصلك خلال $time دقيقة',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 💰 السعر وزر القبول
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$fee ج.م',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Color(0xFF10B981),
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          width: 86,
                          child: ElevatedButton(
                            onPressed: _acceptingOfferId != null
                                ? null
                                : () => _handleAcceptOffer(offerId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isAcceptingThis
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'قبول',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 🎯 شاشة الانتظار الأنيقة في حال عدم وجود عروض بعد
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(), // لتمكين التحديث بالسحب حتى في حالة الفارغ
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'جاري البحث عن كباتن بالقرب منك...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ستظهر عروض الكباتن هنا فور تقديمها.\nاسحب الشاشة للأسفل للتحديث في أي وقت.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _fetchOffers,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تحديث الكشوفات الحية', style: TextStyle(fontFamily: 'Cairo')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}