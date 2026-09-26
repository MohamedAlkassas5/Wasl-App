// import 'package:flutter/material.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/services/orders_service.dart'; // 🎯 استيراد الـ Service المحدثة الخاصة بالطلبات
// import 'package:wasl_app/delivery_screen/WaslDriverOrderDetailsScreen.dart';
//
// class WaslDriverMarketplaceScreen extends StatefulWidget {
//   const WaslDriverMarketplaceScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslDriverMarketplaceScreen> createState() => _WaslDriverMarketplaceScreenState();
// }
//
// class _WaslDriverMarketplaceScreenState extends State<WaslDriverMarketplaceScreen> {
//   // 1️⃣ تعريف الـ Service في أول الكلاس تحت الـ State مباشرة
//   final FlutterOrdersService _ordersService = FlutterOrdersService();
//   late Future<List<dynamic>> _availableJobsFuture;
//
//   @override
//   void initState() {
//     super.initState();
//     _refreshAvailableJobs();
//   }
//
//   /// 🔄 2️⃣ [تم التحديث لايف]: سحب الأوردرات القريبة من الكابتن لايف وتمرير الإحداثيات الجغرافية
//   void _refreshAvailableJobs() {
//     setState(() {
//       // 🎯 تمرير إحداثيات موقع الفحص ليتوافق تماماً مع توجيهات الـ API المحدثة
//       _availableJobsFuture = _ordersService.getAvailableOrders(lat: 30.6967567, lng: 30.7634033);
//     });
//   }
//
//   void _navigateToDetails(Map<String, dynamic> job) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => WaslDriverOrderDetailsScreen(orderData: job),
//       ),
//     ).then((_) {
//       _refreshAvailableJobs();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'الطلبات المتاحة بالمنطقة',
//           style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
//         ),
//         centerTitle: true,
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: FutureBuilder<List<dynamic>>(
//             future: _availableJobsFuture,
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator(color: AppColors.primary));
//               }
//
//               if (snapshot.hasError) {
//                 return _buildEmptyState(
//                   message: 'عفواً، فشل الاتصال بسوق الطلبات حالياً.',
//                   icon: Icons.wifi_off_rounded,
//                 );
//               }
//
//               final List<dynamic> jobs = snapshot.data ?? [];
//
//               if (jobs.isEmpty) {
//                 return RefreshIndicator(
//                   onRefresh: () async => _refreshAvailableJobs(),
//                   color: AppColors.primary,
//                   child: ListView(
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     children: [
//                       SizedBox(height: MediaQuery.of(context).size.height * 0.3),
//                       _buildEmptyState(
//                         message: 'يا مسهل! لا توجد طلبات معلقة حالياً بالمدينة.',
//                         icon: Icons.cloud_done_outlined,
//                       ),
//                     ],
//                   ),
//                 );
//               }
//
//               return RefreshIndicator(
//                 onRefresh: () async => _refreshAvailableJobs(),
//                 color: AppColors.primary,
//                 child: ListView.builder(
//                   padding: const EdgeInsets.all(16),
//                   itemCount: jobs.length,
//                   physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
//                   itemBuilder: (context, index) {
//                     final Map<String, dynamic> job = Map<String, dynamic>.from(jobs[index]);
//
//                     String orderId = job['id']?.toString() ?? 'FL-0000';
//                     String category = job['categoryType'] ?? job['category'] ?? 'طلب توصيل';
//                     String store = job['storeName'] ?? job['store'] ?? 'متجر غير محدد';
//                     String items = job['itemsDescription'] ?? job['items'] ?? 'لا توجد تفاصيل';
//
//                     double rawDistance = double.tryParse(job['distance']?.toString() ?? '0.0') ?? 0.0;
//                     String formattedDist = rawDistance > 0 ? "${rawDistance.toStringAsFixed(1)} كم" : "قريب منك";
//
//                     return Container(
//                       margin: const EdgeInsets.only(bottom: 14),
//                       decoration: BoxDecoration(
//                         color: AppColors.white,
//                         borderRadius: BorderRadius.circular(18),
//                         boxShadow: [
//                           BoxShadow(color: AppColors.textPrimary.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))
//                         ],
//                       ),
//                       child: InkWell(
//                         borderRadius: BorderRadius.circular(18),
//                         onTap: () => _navigateToDetails({
//                           'id': orderId,
//                           'category': category,
//                           'store': store,
//                           'items': items,
//                           'distance': formattedDist,
//                           'expectedPrice': 'فاتورة متغيرة كاش',
//                         }),
//                         child: Padding(
//                           padding: const EdgeInsets.all(16.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Text(
//                                     category,
//                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary, fontFamily: 'Cairo'),
//                                   ),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                     decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
//                                     child: Row(
//                                       children: [
//                                         const Icon(Icons.navigation_outlined, size: 12, color: AppColors.textSecondary),
//                                         const SizedBox(width: 4),
//                                         Text('يبعد: $formattedDist', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo')),
//                                       ],
//                                     ),
//                                   )
//                                 ],
//                               ),
//                               const Divider(height: 24, color: Color(0xFFF1F5F9)),
//                               Text('موقع الشراء: $store', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                               const SizedBox(height: 6),
//                               Text('وصف الطلب: $items', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo', height: 1.4)),
//                               const SizedBox(height: 16),
//                               ElevatedButton.icon(
//                                 onPressed: () => _navigateToDetails({
//                                   'id': orderId,
//                                   'category': category,
//                                   'store': store,
//                                   'items': items,
//                                   'distance': formattedDist,
//                                   'expectedPrice': 'فاتورة متغيرة كاش',
//                                 }),
//                                 icon: const Icon(Icons.local_offer_outlined, color: Colors.white, size: 18),
//                                 label: const Text('عرض التفاصيل وتقديم سعر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: AppColors.textPrimary,
//                                   minimumSize: const Size.fromHeight(48),
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                                   elevation: 0,
//                                 ),
//                               )
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState({required String message, required IconData icon}) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(icon, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
//           const SizedBox(height: 16),
//           Text(message, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }
// }





// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart'; // 🎯 مستدعى لتفعيل التوجيه الفوري لخرائط جوجل بالـ GPS
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/services/orders_service.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverOrderDetailsScreen.dart';
//
// class WaslDriverMarketplaceScreen extends StatefulWidget {
//   const WaslDriverMarketplaceScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslDriverMarketplaceScreen> createState() => _WaslDriverMarketplaceScreenState();
// }
//
// class _WaslDriverMarketplaceScreenState extends State<WaslDriverMarketplaceScreen> {
//   final FlutterOrdersService _ordersService = FlutterOrdersService();
//   late Future<List<dynamic>> _availableJobsFuture;
//
//   @override
//   void initState() {
//     super.initState();
//     _refreshAvailableJobs();
//   }
//
//   void _refreshAvailableJobs() {
//     setState(() {
//       // 🎯 تمرير إحداثيات موقع الفحص التقديري للكابتن لايف
//       _availableJobsFuture = _ordersService.getAvailableOrders(lat: 30.6967567, lng: 30.7634033);
//     });
//   }
//
//   // 🗺️ دالة ملاحة خرائط جوجل الجغرافية الحية المعتمدة على إحداثيات العميل
//   Future<void> _openGoogleMaps(double lat, double lng) async {
//     final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
//     if (await canLaunchUrl(url)) {
//       await launchUrl(url, mode: LaunchMode.externalApplication);
//     } else {
//       debugPrint('💥 [MAP LAUNCH ERROR]: Could not open google maps navigation.');
//     }
//   }
//
//   void _navigateToDetails(Map<String, dynamic> job) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => WaslDriverOrderDetailsScreen(orderData: job),
//       ),
//     ).then((_) {
//       _refreshAvailableJobs();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'الطلبات المتاحة بالمنطقة',
//           style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16),
//         ),
//         centerTitle: true,
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: FutureBuilder<List<dynamic>>(
//             future: _availableJobsFuture,
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator(color: AppColors.primary));
//               }
//
//               if (snapshot.hasError) {
//                 return _buildEmptyState(
//                   message: 'عفواً، فشل الاتصال بسوق الطلبات حالياً.',
//                   icon: Icons.wifi_off_rounded,
//                 );
//               }
//
//               final List<dynamic> jobs = snapshot.data ?? [];
//
//               if (jobs.isEmpty) {
//                 return RefreshIndicator(
//                   onRefresh: () async => _refreshAvailableJobs(),
//                   color: AppColors.primary,
//                   child: ListView(
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     children: [
//                       SizedBox(height: MediaQuery.of(context).size.height * 0.3),
//                       _buildEmptyState(
//                         message: 'يا مسهل! لا توجد طلبات معلقة حالياً بالمدينة.',
//                         icon: Icons.cloud_done_outlined,
//                       ),
//                     ],
//                   ),
//                 );
//               }
//
//               return RefreshIndicator(
//                 onRefresh: () async => _refreshAvailableJobs(),
//                 color: AppColors.primary,
//                 child: ListView.builder(
//                   padding: const EdgeInsets.all(16),
//                   itemCount: jobs.length,
//                   physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
//                   itemBuilder: (context, index) {
//                     final Map<String, dynamic> job = Map<String, dynamic>.from(jobs[index]);
//
//                     String orderId = job['id']?.toString() ?? 'FL-0000';
//                     String category = job['categoryType'] ?? 'طلب توصيل';
//                     String store = job['storeName'] ?? 'من أقرب مكان';
//                     String items = job['itemsDescription'] ?? 'لا توجد تفاصيل الشحنة';
//
//                     // الداتا الجديدة المسترجعة لايف من الباك إند
//                     String cName = job['customerName'] ?? 'عميل وصل المميز';
//                     String cPhone = job['customerPhone'] ?? 'غير متوفر';
//                     String addressText = job['deliveryAddressText'] ?? 'مكتوب يدوي بالخريطة';
//
//                     double lat = double.tryParse(job['latitude']?.toString() ?? '0.0') ?? 0.0;
//                     double lng = double.tryParse(job['longitude']?.toString() ?? '0.0') ?? 0.0;
//
//                     double rawDistance = double.tryParse(job['distance']?.toString() ?? '0.0') ?? 0.0;
//                     String formattedDist = rawDistance > 0 ? "${rawDistance.toStringAsFixed(1)} كم" : "قريب منك";
//
//                     // كبسولة تجميع الداتا الموحدة للتمرير لشاشة المزايدة والتفاصيل
//                     final Map<String, dynamic> fullJobData = {
//                       'id': orderId,
//                       'category': category,
//                       'store': store,
//                       'items': items,
//                       'distance': formattedDist,
//                       'customerName': cName,
//                       'customerPhone': cPhone,
//                       'deliveryAddressText': addressText,
//                       'latitude': lat,
//                       'longitude': lng,
//                       'expectedPrice': 'فاتورة متغيرة كاش',
//                     };
//
//                     return Container(
//                       margin: const EdgeInsets.only(bottom: 14),
//                       decoration: BoxDecoration(
//                         color: AppColors.white,
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
//                         boxShadow: [
//                           BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
//                         ],
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.all(16.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   category,
//                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary, fontFamily: 'Cairo'),
//                                 ),
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                   decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
//                                   child: Row(
//                                     children: [
//                                       const Icon(Icons.navigation_rounded, size: 12, color: AppColors.textSecondary),
//                                       const SizedBox(width: 4),
//                                       Text('يبعد: $formattedDist', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
//                                     ],
//                                   ),
//                                 )
//                               ],
//                             ),
//                             const Divider(height: 20, color: Color(0xFFF1F5F9), thickness: 1),
//                             Text('🏪 موقع الشراء: $store', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                             const SizedBox(height: 4),
//                             Text('📦 وصف الطلب: $items', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo', height: 1.4)),
//                             const SizedBox(height: 12),
//
//                             // 👤 2️⃣ كارت تفاصيل العميل المطور والمحقون لايف لراحت كابتن وصل
//                             Container(
//                               padding: const EdgeInsets.all(14),
//                               decoration: BoxDecoration(
//                                 color: AppColors.background,
//                                 borderRadius: BorderRadius.circular(16),
//                                 border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
//                                       const SizedBox(width: 8),
//                                       Text('تفاصيل المستلم: $cName', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13, color: AppColors.textPrimary)),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text('📞 رقم الهاتف: $cPhone', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
//                                   const SizedBox(height: 4),
//                                   Text('📍 العنوان اليدوي: $addressText', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
//
//                                   if (lat != 0.0 && lng != 0.0) ...[
//                                     const Divider(height: 20, color: Color(0xFFCBD5E1)),
//                                     ElevatedButton.icon(
//                                       onPressed: () => _openGoogleMaps(lat, lng),
//                                       icon: const Icon(Icons.map_rounded, size: 16, color: Colors.white),
//                                       label: const Text('فتح الموقع على خرائط جوجل 🗺️', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: AppColors.textPrimary,
//                                         foregroundColor: Colors.white,
//                                         minimumSize: const Size.fromHeight(40),
//                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                                         elevation: 0,
//                                       ),
//                                     ),
//                                   ],
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 14),
//
//                             ElevatedButton.icon(
//                               onPressed: () => _navigateToDetails(fullJobData),
//                               icon: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 16),
//                               label: const Text('عرض التفاصيل وتقديم سعر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: AppColors.primary,
//                                 minimumSize: const Size.fromHeight(46),
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//                                 elevation: 0,
//                               ),
//                             )
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState({required String message, required IconData icon}) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(icon, size: 54, color: AppColors.textSecondary.withOpacity(0.3)),
//           const SizedBox(height: 12),
//           Text(message, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }
// }










import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/delivery_screen/WaslDriverOrderDetailsScreen.dart';

class WaslDriverMarketplaceScreen extends StatefulWidget {
  const WaslDriverMarketplaceScreen({Key? key}) : super(key: key);

  @override
  State<WaslDriverMarketplaceScreen> createState() => _WaslDriverMarketplaceScreenState();
}

class _WaslDriverMarketplaceScreenState extends State<WaslDriverMarketplaceScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();

  /// 🐞 دي كانت `Future` بتتبني مرة واحدة في `initState` وبتتعرض بـ
  /// `FutureBuilder`، من غير أي تحديث دوري. يعني الكابتن كان لازم يكون فاتح
  /// الشاشة دي **وقت** ما الموجة تخرج، وإلا العرض بيروح من غير ما يشوفه —
  /// مهلته ٦٠ ثانية بس. القايمة بقت حالة عادية عشان نقدر نحدّثها كل شوية من
  /// غير ما الشاشة ترجع لدايرة التحميل وتفضل ترمش.
  List<dynamic> _jobs = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  /// أقصر من مهلة العرض بكتير، فالطلب بيبان في ثواني من ساعة ما اتعرض.
  static const Duration _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _refreshAvailableJobs();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => _refreshAvailableJobs(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// [silent] بيمنع دايرة التحميل في نبضات الخلفية — التحديث الدوري المفروض
  /// يعدّي من غير ما يمسح اللي الكابتن بيقراه.
  Future<void> _refreshAvailableJobs({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final result = await _ordersService.getAvailableOrders();
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _jobs = (result['data'] as List?) ?? const [];
        _error = null;
      } else if (!silent) {
        // فشل نبضة خلفية بيسيب آخر قايمة ناجحة زي ما هي بدل ما يحوّلها لرسالة
        // خطأ — الشبكة بتقطع لحظياً وهو راكب.
        _error = result['message']?.toString() ?? 'تعذّر تحميل الطلبات';
      }
    });
  }

  // 🗺️ دالة خرائط جوجل الصحيحة باستخدام الإحداثيات
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('💥 [MAP ERROR]: لا يمكن فتح الخرائط');
    }
  }

  void _navigateToDetails(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WaslDriverOrderDetailsScreen(orderData: job)),
    ).then((_) => _refreshAvailableJobs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        title: const Text('السوق اللوجستي 🏁', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
        centerTitle: true,
        actions: [IconButton(onPressed: _refreshAvailableJobs, icon: const Icon(Icons.refresh, color: AppColors.primary))],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAvailableJobs(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _jobs.isEmpty) {
      return _buildEmptyState(message: _error);
    }
    if (_jobs.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      itemBuilder: (context, index) =>
          _buildOrderCard(Map<String, dynamic>.from(_jobs[index] as Map)),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> job) {
    final String orderId = job['id']?.toString() ?? '0';
    final String cat = job['categoryType'] ?? 'طلب توصيل';
    final String cName = job['customerName'] ?? 'عميل وصل';
    final String address = job['deliveryAddressText'] ?? 'العنوان مكتوب يدوياً';
    final double itemsPrice = double.tryParse(job['itemsPrice']?.toString() ?? '0') ?? 0.0;
    final double lat = double.tryParse(job['latitude']?.toString() ?? '30.463') ?? 30.463;
    final double lng = double.tryParse(job['longitude']?.toString() ?? '30.702') ?? 30.702;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16, fontFamily: 'Cairo')),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Text('FL-$orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.person_pin_circle, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ]),
          const SizedBox(height: 8),
          Text(address, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
          const SizedBox(height: 10),
          if (itemsPrice > 0)
            Container(margin: const EdgeInsets.only(bottom: 10), child: Text('💰 القيمة التقديرية: $itemsPrice ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openGoogleMaps(lat, lng),
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('خرائط', style: TextStyle(fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptOrder(job),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('تفاصيل وعرض', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ListView وليس Column عشان RefreshIndicator يفضل شغال والقايمة فاضية.
  Widget _buildEmptyState({String? message}) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 200),
          Center(
            child: Text(
              message ?? 'لا توجد طلبات متاحة حالياً',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      );
  Future<void> _acceptOrder(Map<String, dynamic> job) async {
    final id = int.tryParse(job['id']?.toString() ?? '');
    if (id == null) return;
    final result = await _ordersService.acceptAvailableOrder(id);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إسناد الطلب إليك')));
      _refreshAvailableJobs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'تعذر قبول الطلب')));
    }
  }
}
