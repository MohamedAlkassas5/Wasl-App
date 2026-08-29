// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// // 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
// import 'package:wasl_app/core/theme/app_colors.dart';
// // 🎯 استيراد شاشة التنفيذ المحدثة الديناميكية
// import 'package:wasl_app/delivery_screen/WaslDriverJobExecutionScreen.dart';
//
// class WaslDriverOrdersScreen extends StatefulWidget {
//   const WaslDriverOrdersScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslDriverOrdersScreen> createState() => _WaslDriverOrdersScreenState();
// }
//
// class _WaslDriverOrdersScreenState extends State<WaslDriverOrdersScreen> with SingleTickerProviderStateMixin {
//   TabController? _tabController;
//   int? _driverId;
//
//   List<dynamic> _activeTrips = [];
//   List<dynamic> _completedTrips = [];
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadDriverSessionAndFetchOrders();
//   }
//
//   // 🎯 جلب الـ ID الحقيقي للكابتن من الكاش ثم استدعاء الـ API
//   Future<void> _loadDriverSessionAndFetchOrders() async {
//     final prefs = await SharedPreferences.getInstance();
//     final id = prefs.getInt('user_id') ?? 21; // الافتراضي 21 للتست
//     setState(() {
//       _driverId = id;
//     });
//     await _fetchDriverTripsFromServer();
//   }
//
//   // 📡 ضربة الـ API لجلب كافة رحلات الكابتن (النشطة والمنتهية) مباشرة من الداتابيز
//   Future<void> _fetchDriverTripsFromServer() async {
//     if (_driverId == null) return;
//
//     setState(() => _isLoading = true);
//
//     // 🎯 المسار يرسل الـ driverId كـ Query Parameter للسيرفر لتضمين أوردراته النشطة
//     final url = Uri.parse('http://10.0.2.2:3000/orders/available?driverId=$_driverId');
//
//     try {
//       final response = await http.get(
//         url,
//         headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
//       ).timeout(const Duration(seconds: 12));
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final List<dynamic> allOrders = jsonDecode(response.body);
//
//         setState(() {
//           // 🎯 تحويل الطرفين لنصوص لتجنب مشاكل الـ Int والـ String وتصفية الحالات بدقة
//           _activeTrips = allOrders.where((order) {
//             final isDriver = order['acceptedDriverId']?.toString() == _driverId?.toString();
//             final isOngoing = order['status']?.toString().toLowerCase() == 'accepted' ||
//                 order['status']?.toString().toLowerCase() == 'at_store' ||
//                 order['status']?.toString().toLowerCase() == 'delivering';
//             return isDriver && isOngoing;
//           }).toList();
//
//           // 🎯 تصفية الرحلات المنتهية بنجاح والمخصصة للكابتن الحالي
//           _completedTrips = allOrders.where((order) {
//             final isDriver = order['acceptedDriverId']?.toString() == _driverId?.toString();
//             return isDriver && order['status']?.toString().toLowerCase() == 'completed';
//           }).toList();
//
//           _isLoading = false;
//         });
//         return;
//       }
//     } catch (e) {
//       debugPrint('💥 [ORDERS FETCH ERROR] فشل جلب الرحلات الحية: $e');
//     }
//
//     setState(() => _isLoading = false);
//   }
//
//   @override
//   void dispose() {
//     _tabController?.dispose();
//     super.dispose();
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
//           'رحلاتي وتكليفاتي',
//           style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
//         ),
//         centerTitle: true,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
//             onPressed: _fetchDriverTripsFromServer,
//           )
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: AppColors.primary,
//           labelColor: AppColors.primary,
//           unselectedLabelColor: AppColors.textSecondary,
//           labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
//           unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
//           tabs: const [
//             Tab(text: 'رحلات نشطة جارية'),
//             Tab(text: 'رحلات منتهية'),
//           ],
//         ),
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: _isLoading
//               ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
//               : TabBarView(
//             controller: _tabController,
//             children: [
//               _buildActiveTripsList(),
//               _buildCompletedTripsList(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildActiveTripsList() {
//     if (_activeTrips.isEmpty) {
//       return _buildEmptyState('لا توجد رحلات جارية مكلف بها حالياً.', Icons.directions_bike_outlined);
//     }
//
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _activeTrips.length,
//       itemBuilder: (context, index) {
//         final trip = _activeTrips[index];
//         final orderId = trip['id'] ?? '';
//
//         // تأمين القراءة والتحويل حتى في قائمة الطلبات النشطة احتياطاً لمنع المشاكل المستقبلية
//         final dynamic rawFinalFee = trip['finalDeliveryFee'];
//         final dynamic rawFee = trip['deliveryFee'];
//         final double deliveryFee = rawFinalFee != null
//             ? (rawFinalFee is num ? rawFinalFee.toDouble() : double.tryParse(rawFinalFee.toString()) ?? 0.0)
//             : (rawFee != null ? (rawFee is num ? rawFee.toDouble() : double.tryParse(rawFee.toString()) ?? 0.0) : 0.0);
//
//         return Container(
//           margin: const EdgeInsets.only(bottom: 14),
//           decoration: BoxDecoration(
//             color: AppColors.white,
//             borderRadius: BorderRadius.circular(18),
//             boxShadow: [
//               BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
//             ],
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text('طلب رقم: FL-$orderId', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
//                     Text('${deliveryFee.toStringAsFixed(2)} ج.م توصيل', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
//                   ],
//                 ),
//                 const Divider(height: 24, color: Color(0xFFF1F5F9)),
//                 Text('${trip['categoryType'] ?? 'طلبات عامة'} • ${trip['storeName'] ?? 'من أقرب مكان'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                 const SizedBox(height: 4),
//                 Text('العنوان: ${trip['deliveryAddressText'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
//                 const SizedBox(height: 16),
//                 ElevatedButton(
//                   onPressed: () async {
//                     // الانتقال المباشر وتمرير الـ Map بالكامل حياً للشاشة الديناميكية المصلحة
//                     await Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => WaslDriverJobExecutionScreen(
//                           orderData: trip,
//                         ),
//                       ),
//                     );
//                     // إعادة التحديث تلقائياً فور العودة (مثلاً بعد إنهاء الرحلة)
//                     _fetchDriverTripsFromServer();
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.textPrimary,
//                     minimumSize: const Size.fromHeight(46),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     elevation: 0,
//                   ),
//                   child: const Text('فتح شاشة التنفيذ ومتابعة العميل 🚴', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
//                 )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildCompletedTripsList() {
//     if (_completedTrips.isEmpty) {
//       return _buildEmptyState('سجل رحلاتك المكتملة فارغ.', Icons.history_toggle_off_rounded);
//     }
//
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _completedTrips.length,
//       itemBuilder: (context, index) {
//         final trip = _completedTrips[index];
//         final orderId = trip['id'] ?? '';
//
//         // 🎯 [تم الإصلاح الجذري والشامل]: تأمين التحويل العالي والذكي سواء كان القادم int أو double أو String نصي من البوستجريس
//         final dynamic rawFinalFee = trip['finalDeliveryFee'];
//         final dynamic rawFee = trip['deliveryFee'];
//
//         final double fee = rawFinalFee != null
//             ? (rawFinalFee is num ? rawFinalFee.toDouble() : double.tryParse(rawFinalFee.toString()) ?? 0.0)
//             : (rawFee != null ? (rawFee is num ? rawFee.toDouble() : double.tryParse(rawFee.toString()) ?? 0.0) : 0.0);
//
//         // حساب صافي الربح الحقيقي للرحلة (رسوم التوصيل ناقص الـ 5 جنيه عمولة التطبيق)
//         final double netEarnings = fee > 5 ? fee - 5 : fee;
//
//         return Container(
//           margin: const EdgeInsets.only(bottom: 12),
//           decoration: BoxDecoration(
//             color: AppColors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
//             ],
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('${trip['categoryType'] ?? 'طلبات عامة'} • ${trip['storeName'] ?? 'من أقرب مكان'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                       const SizedBox(height: 4),
//                       Text('طلب رقم: FL-$orderId', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
//                     ],
//                   ),
//                 ),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     const Text('صافي ربحك', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'Cairo')),
//                     const SizedBox(height: 2),
//                     Text('${netEarnings.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF16A34A), fontFamily: 'Cairo')),
//                   ],
//                 )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildEmptyState(String message, IconData icon) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(icon, size: 54, color: AppColors.textSecondary.withOpacity(0.3)),
//           const SizedBox(height: 12),
//           Text(message, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }
// }


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/ui/wasl_async.dart';
import 'package:wasl_app/core/ui/wasl_failure.dart';
import 'package:wasl_app/core/widgets/wasl_async_view.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/delivery_screen/WaslDriverJobExecutionScreen.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslDriverOrdersScreen extends StatefulWidget {
  const WaslDriverOrdersScreen({Key? key}) : super(key: key);

  @override
  State<WaslDriverOrdersScreen> createState() => _WaslDriverOrdersScreenState();
}

class _WaslDriverOrdersScreenState extends State<WaslDriverOrdersScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int? _driverId;
  List<dynamic> _activeTrips = [];
  List<dynamic> _completedTrips = [];

  /// حالة تحميل الرحلات. زي شاشة العميل بالظبط: فشل الشبكة كان بيتعرض على
  /// إنه «مفيش رحلات»، والكابتن ممكن يبقى عنده رحلة شغالة فعلاً.
  WaslAsync<List<dynamic>> _trips = const WaslAsync.loading();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDriverSessionAndFetchOrders();
  }

  Future<void> _loadDriverSessionAndFetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // تحديث قاطع لذاكرة الكاش

    // تأمين جلب الـ ID الحقيقي المخزن عند تسجيل الدخول
    final storedId = prefs.get('user_id');
    final id = int.tryParse(storedId?.toString() ?? '') ?? 21;

    setState(() => _driverId = id);
    await _fetchDriverTripsFromServer();
  }

  // 🎯 دالة جلب الرحلات المحدثة والمربوطة بالسيرفر السحابي مع كود التشخيص
  Future<void> _fetchDriverTripsFromServer() async {
    if (_driverId == null) return;
    setState(() => _trips = const WaslAsync.loading());

    final result = await FlutterOrdersService().getAvailableOrders(driverId: _driverId);

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _trips = WaslAsync.failure(WaslFailure.fromResult(result)));
      return;
    }

    final List<dynamic> allOrders = result['data'] ?? [];

    setState(() {
      _activeTrips = allOrders.where((o) {
        final isDriver = o['acceptedDriverId']?.toString() == _driverId.toString();
        final status = o['status']?.toString().toLowerCase();
        return isDriver && ['accepted', 'at_store', 'items_bought', 'delivering'].contains(status);
      }).toList();

      _completedTrips = allOrders.where((o) {
        final isDriver = o['acceptedDriverId']?.toString() == _driverId.toString();
        return isDriver && o['status']?.toString().toLowerCase() == 'completed';
      }).toList();

      _trips = WaslAsync.data(allOrders);
    });
  }

  Future<void> _openJob(Map<String, dynamic> trip) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WaslDriverJobExecutionScreen(orderData: trip)));
    _fetchDriverTripsFromServer(); // تحديث القائمة لايف فور العودة
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        title: const Text('رحلاتي وتكليفاتي', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          tabs: const [Tab(text: 'رحلات نشطة'), Tab(text: 'رحلات منتهية')],
        ),
      ),
      body: Column(
        children: [
          WaslOfflineBanner(
            visible: _trips.failureOrNull?.isOffline ?? false,
            onRetry: _fetchDriverTripsFromServer,
          ),
          Expanded(
            child: WaslAsyncView<List<dynamic>>(
              state: _trips,
              onRetry: _fetchDriverTripsFromServer,
              builder: (context, _) => TabBarView(
                controller: _tabController,
                children: [_buildActiveTripsList(), _buildCompletedTripsList()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripsList() {
    if (_activeTrips.isEmpty) return _buildEmptyState('لا توجد رحلات جارية حالياً.', Icons.directions_bike_outlined);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeTrips.length,
      itemBuilder: (context, index) {
        final trip = _activeTrips[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openJob(trip),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delivery_dining, color: AppColors.primary)),
                      const SizedBox(width: 15),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(trip['categoryType'] ?? 'توصيل سريغ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo', color: AppColors.textPrimary)),
                        Text('طلب رقم: FL-${trip['id']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(20)), child: const Text('جاري التنفيذ', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(children: [
                    const Icon(Icons.location_on, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(trip['deliveryAddressText'] ?? 'كوم حمادة', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ])
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedTripsList() {
    if (_completedTrips.isEmpty) return _buildEmptyState('لا توجد رحلات سابقة.', Icons.history_rounded);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedTrips.length,
      itemBuilder: (context, index) {
        final trip = _completedTrips[index];
        final double fee = double.tryParse(trip['finalDeliveryFee']?.toString() ?? '0') ?? 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.02))),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.check_circle, color: Colors.green, size: 22)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip['categoryType'] ?? 'توصيل', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary, fontSize: 14)),
                Text('FL-${trip['id']} • تم الإنجاز بنجاح', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
              ])),
              Text('+${fee.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15, fontFamily: 'Cairo')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 54, color: Colors.grey.withOpacity(0.25)),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
    ]),
  );
}