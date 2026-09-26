// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverMarketplaceScreen.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverOrdersScreen.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverProfileScreen.dart';
// import 'package:wasl_app/screens/WaslNotificationBell.dart';
// import 'package:wasl_app/delivery_screen/WaslDeliveryPaymentScreen.dart';
// import 'package:wasl_app/services/orders_service.dart';
// import 'package:wasl_app/services/location_service.dart';
// import 'package:wasl_app/services/location_api_service.dart';
//
// class WaslDriverHomeScreen extends StatefulWidget {
//   const WaslDriverHomeScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslDriverHomeScreen> createState() => _WaslDriverHomeScreenState();
// }
//
// class _WaslDriverHomeScreenState extends State<WaslDriverHomeScreen> with WidgetsBindingObserver {
//   final FlutterOrdersService _ordersService = FlutterOrdersService();
//   final LocationApiService _locationApi = LocationApiService();
//   Timer? _locationTimer;
//   bool _isOnline = false;
//   String _driverName = 'جاري التحميل...';
//   int _driverId = 21; // القيمة الافتراضية المعتمدة لـ MVP V1
//
//   double _walletBalance = 0.00;
//   bool _isLoadingBalance = true;
//
//   int _todayOrdersCount = 0;
//   double _todayEarnings = 0.00;
//   double _todayCommissions = 0.00;
//   double _driverRating = 4.95;
//
//   Timer? _dashboardTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this); // لمراقبة عودة الكابتن للتطبيق من الخلفية
//     _loadDriverSessionAndInitialize();
//   }
//
//   @override
//   void dispose() {
//     _stopLiveDashboardUpdates();
//     _stopLocationUpdates();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
//
//   // 🎯 تحديث البيانات تلقائياً لو الكابتن فتح الموبايل بعد قفله
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _fetchLiveDashboardStats(_driverId);
//       _fetchOnlineStatus(_driverId);
//       _startLiveDashboardUpdates();
//     } else if (state == AppLifecycleState.paused) {
//       _stopLiveDashboardUpdates();
//       _stopLocationUpdates();
//     }
//   }
//
//   Future<void> _loadDriverSessionAndInitialize() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload(); // تحديث قاطع لذاكرة الكاش
//
//     // 🛡️ تأمين جلب الـ ID بشكل مرن سواء كان مخزناً كـ String أو Int في السيرفر
//     final storedId = prefs.get('user_id');
//     final id = int.tryParse(storedId?.toString() ?? '') ?? 21;
//     final name = prefs.getString('user_name') ?? 'كابتن وصل';
//
//     if (mounted) {
//       setState(() {
//         _driverId = id;
//         _driverName = name;
//       });
//     }
//
//     await _fetchLiveDashboardStats(id);
//     await _fetchOnlineStatus(id);
//     _startLiveDashboardUpdates();
//   }
//
//   Future<void> _fetchOnlineStatus(int driverId) async {
//     final result = await _ordersService.getDriverOnlineStatus(driverId);
//     if (mounted && result['success'] == true) {
//       final online = result['isOnline'] == true;
//       setState(() => _isOnline = online);
//       // Resume/stop live location push to match the restored session state.
//       if (online) {
//         _startLocationUpdates();
//       } else {
//         _stopLocationUpdates();
//       }
//     }
//   }
//
//   void _startLiveDashboardUpdates() {
//     _dashboardTimer?.cancel(); // منع تداخل المؤقتات في الخلفية
//     _dashboardTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//       await _fetchLiveDashboardStats(_driverId);
//     });
//   }
//
//   // 🛰️ بث موقع الكابتن الحي للسيرفر أثناء الأونلاين ليظهر في بحث "الأقرب"
//   Future<void> _pushLocationOnce() async {
//     final pos = await LocationService.instance.getCurrentPosition();
//     if (pos == null) return;
//     await _locationApi.updateDriverLocation(
//       driverId: _driverId,
//       latitude: pos.latitude,
//       longitude: pos.longitude,
//     );
//   }
//
//   void _startLocationUpdates() {
//     _locationTimer?.cancel();
//     _pushLocationOnce(); // بث فوري أول ما يبقى أونلاين
//     _locationTimer = Timer.periodic(
//       const Duration(seconds: 20),
//       (_) => _pushLocationOnce(),
//     );
//   }
//
//   void _stopLocationUpdates() {
//     _locationTimer?.cancel();
//     _locationTimer = null;
//   }
//
//   void _stopLiveDashboardUpdates() {
//     _dashboardTimer?.cancel();
//     _dashboardTimer = null;
//   }
//
//   Future<void> _fetchLiveDashboardStats(int driverId) async {
//     final result = await _ordersService.getDriverDashboardStats(driverId);
//
//     if (result['success'] == true && mounted) {
//       setState(() {
//         _walletBalance = double.tryParse(result['balance']?.toString() ?? '') ?? 0.0;
//         _todayOrdersCount = int.tryParse(result['todayOrdersCount']?.toString() ?? '') ?? 0;
//         _todayEarnings = double.tryParse(result['todayEarnings']?.toString() ?? '') ?? 0.0;
//         _todayCommissions = double.tryParse(result['todayCommissions']?.toString() ?? '') ?? 0.0;
//         _driverRating = double.tryParse(result['rating']?.toString() ?? '4.95') ?? 4.95;
//         _isLoadingBalance = false;
//
//         if (_walletBalance < 5 && _isOnline) {
//           _isOnline = false;
//         }
//       });
//       return;
//     }
//
//     if (mounted && _isLoadingBalance) {
//       setState(() => _isLoadingBalance = false);
//     }
//   }
//
//   void _toggleOnlineStatus(bool value) async {
//     if (value && _walletBalance < 5.0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('عفواً، لا يمكنك استقبال طلبات. يرجى شحن محفظتك أولاً 💳', style: TextStyle(fontFamily: 'Cairo')),
//           backgroundColor: AppColors.danger,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     final result = await _ordersService.setDriverOnlineStatus(
//       driverId: _driverId,
//       isOnline: value,
//     );
//
//     if (!mounted) return;
//
//     if (result['success'] != true) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(result['message'] ?? 'فشل تحديث حالة الاتصال', style: const TextStyle(fontFamily: 'Cairo')),
//           backgroundColor: AppColors.danger,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }
//
//     setState(() => _isOnline = result['isOnline'] == true);
//
//     // 🛰️ Start/stop live GPS push so this driver appears in nearby search.
//     if (_isOnline) {
//       _startLocationUpdates();
//     } else {
//       _stopLocationUpdates();
//     }
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           _isOnline ? 'أنت أونلاين الآن! مستعد لاستقبال الطلبات ⚡' : 'تم تحويل حسابك أوفلاين.',
//           style: const TextStyle(fontFamily: 'Cairo'),
//         ),
//         backgroundColor: _isOnline ? const Color(0xFF16A34A) : AppColors.textSecondary,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     bool isAccountActive = (_walletBalance > -10.0);
//
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         automaticallyImplyLeading: false,
//         leadingWidth: 64,
//         leading: Padding(
//           padding: const EdgeInsets.only(right: 12.0, top: 6.0, bottom: 6.0),
//           child: GestureDetector(
//             onTap: () async {
//               _stopLiveDashboardUpdates(); // إيقاف مؤقت للراحة أثناء تصفح البروفايل
//               await Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const WaslDriverProfileScreen()),
//               );
//               _loadDriverSessionAndInitialize(); // 🎯 إعادة تشغيل الفحص فور العودة للشاشة الرئيسية
//             },
//             child: Container(
//               decoration: BoxDecoration(
//                 color: AppColors.primary.withOpacity(0.08),
//                 shape: BoxShape.circle,
//                 border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
//               ),
//               child: const Center(
//                 child: Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
//               ),
//             ),
//           ),
//         ),
//         title: const Text(
//           'لوحة التحكم',
//           style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16),
//         ),
//         centerTitle: false,
//         actions: [
//           Container(
//             margin: const EdgeInsets.symmetric(vertical: 8),
//             decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
//             child: IconButton(
//               icon: const Icon(Icons.assignment_rounded, color: AppColors.textPrimary, size: 20),
//               tooltip: 'رحلاتي وتكليفاتي',
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslDriverOrdersScreen()));
//               },
//             ),
//           ),
//           const SizedBox(width: 8),
//           WaslNotificationBell(userId: _driverId),
//           const SizedBox(width: 16),
//         ],
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: SingleChildScrollView(
//             physics: const BouncingScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 // 1️⃣ كارت حالة الاتصال
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: AppColors.white,
//                     borderRadius: BorderRadius.circular(18),
//                     boxShadow: [
//                       BoxShadow(color: AppColors.textPrimary.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))
//                     ],
//                   ),
//                   child: Row(
//                     children: [
//                       CircleAvatar(
//                         radius: 24,
//                         backgroundColor: _isOnline ? const Color(0xFFDCFCE7) : AppColors.primary.withOpacity(0.06),
//                         child: Icon(
//                             Icons.delivery_dining_rounded,
//                             color: _isOnline ? const Color(0xFF16A34A) : AppColors.primary,
//                             size: 26
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('يا هلا، كابتن $_driverName 👋', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                             const SizedBox(height: 2),
//                             Text(
//                               _isOnline ? 'متاح ومستعد لاستقبال عروض الساحة' : 'وضع عدم الاتصال بالخدمة',
//                               style: TextStyle(fontSize: 11, color: _isOnline ? const Color(0xFF16A34A) : AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Switch(
//                         value: _isOnline,
//                         onChanged: _toggleOnlineStatus,
//                         activeColor: const Color(0xFF16A34A),
//                         activeTrackColor: const Color(0xFFDCFCE7),
//                       )
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//
//                 // 2️⃣ بطاقة المحفظة الرقمية الفاخرة
//                 Container(
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
//                       begin: Alignment.topRight,
//                       end: Alignment.bottomLeft,
//                     ),
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: [
//                       BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 6))
//                     ],
//                   ),
//                   child: InkWell(
//                     borderRadius: BorderRadius.circular(20),
//                     onTap: () async {
//                       _stopLiveDashboardUpdates();
//                       await Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => const WaslDeliveryPaymentScreen()),
//                       );
//                       _loadDriverSessionAndInitialize();
//                     },
//                     child: Padding(
//                       padding: const EdgeInsets.all(20),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text('الرصيد المتاح بالمحفظة (اضغط للشحن) 💳', style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
//                               const Icon(Icons.add_card_rounded, color: Colors.amber, size: 20),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           _isLoadingBalance
//                               ? const SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
//                           )
//                               : Text(
//                             '${_walletBalance.toStringAsFixed(2)} ج.م',
//                             style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'Cairo', letterSpacing: -0.5),
//                           ),
//                           const Divider(height: 20, color: Colors.white12, thickness: 1),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: const [
//                               Expanded(
//                                 child: Text(
//                                   '💡 اضغط هنا لإعادة شحن رصيدك عبر المحافظ الإلكترونية أو الفيزا فوراُ.',
//                                   style: TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'Cairo', height: 1.4),
//                                 ),
//                               ),
//                               Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 // 3️⃣ تقارير الأداء اليومية
//                 const Text('تقرير الأداء اليومي (كوم حمادة)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                 const SizedBox(height: 12),
//
//                 GridView.count(
//                   shrinkWrap: true,
//                   physics: const NeverScrollableScrollPhysics(),
//                   crossAxisCount: 2,
//                   childAspectRatio: 1.25,
//                   crossAxisSpacing: 10,
//                   mainAxisSpacing: 10,
//                   children: [
//                     _buildMetricCard('طلبات اليوم المكتملة', '$_todayOrdersCount', Icons.check_circle_rounded, const Color(0xFF16A34A)),
//                     _buildMetricCard('أرباح التوصيل كاش', '${_todayEarnings.toStringAsFixed(0)} ج.م', Icons.monetization_on_rounded, AppColors.primary),
//                     _buildMetricCard('عمولات مخصومة', '${_todayCommissions.toStringAsFixed(0)} ج.م', Icons.trending_down_rounded, AppColors.danger),
//                     _buildMetricCard('تقييمك التراكمي', '${_driverRating.toStringAsFixed(2)} ★', Icons.star_rounded, Colors.amber.shade700),
//                   ],
//                 ),
//                 const SizedBox(height: 80),
//               ],
//             ),
//           ),
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20.0),
//         child: GestureDetector(
//           onTap: isAccountActive
//               ? () async {
//             if (!_isOnline) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('برجاء تفعيل وضع الاتصال (Online) أولاً لرؤية الطلبات المتاحة 📡', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.warning),
//               );
//               return;
//             }
//             _stopLiveDashboardUpdates();
//             await Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslDriverMarketplaceScreen()));
//             _loadDriverSessionAndInitialize();
//           }
//               : null,
//           child: Container(
//             height: 52,
//             decoration: BoxDecoration(
//               color: isAccountActive ? AppColors.textPrimary : Colors.grey.shade400,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 if (isAccountActive)
//                   BoxShadow(color: AppColors.textPrimary.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))
//               ],
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                     isAccountActive ? Icons.gavel_rounded : Icons.lock_outline_rounded,
//                     color: Colors.white,
//                     size: 18
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   isAccountActive ? 'الانتقال لساحة الطلبات المتاحة 🏁' : '🔒 الحساب معلق (تجاوز حد الدين)',
//                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Text(
//                   title,
//                   style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               Icon(icon, color: color, size: 18),
//             ],
//           ),
//           const Spacer(),
//           Text(
//             value,
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//           ),
//         ],
//       ),
//     );
//   }
// }





import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wasl_app/core/ui/wasl_submit_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/delivery_screen/WaslDriverMarketplaceScreen.dart';
import 'package:wasl_app/delivery_screen/WaslDriverOrdersScreen.dart';
import 'package:wasl_app/delivery_screen/WaslDriverProfileScreen.dart';
import 'package:wasl_app/screens/WaslNotificationBell.dart';
import 'package:wasl_app/delivery_screen/WaslDeliveryPaymentScreen.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/services/location_service.dart';
import 'package:wasl_app/services/location_api_service.dart';
import 'package:wasl_app/services/wallet_service.dart';

class WaslDriverHomeScreen extends StatefulWidget {
  const WaslDriverHomeScreen({Key? key}) : super(key: key);

  @override
  State<WaslDriverHomeScreen> createState() => _WaslDriverHomeScreenState();
}

class _WaslDriverHomeScreenState extends State<WaslDriverHomeScreen>
    with WidgetsBindingObserver, WaslSubmitGuard<WaslDriverHomeScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  final LocationApiService _locationApi = LocationApiService();
  final WaslWalletService _walletService = WaslWalletService();
  Timer? _locationTimer;
  bool _isOnline = false;
  String _driverName = 'جاري التحميل...';
  int _driverId = 21;

  double _walletBalance = 0.00;
  bool _isLoadingBalance = true;

  /// أونلاين بس السيرفر مش شايف موقعه — يعني **مش** بيستقبل طلبات.
  /// الفرق ده كان مخفي تماماً: الزرار يقول أونلاين والطلبات ما بتيجيش.
  bool _locationStale = false;

  int _todayOrdersCount = 0;
  double _todayEarnings = 0.00;
  double _todayCommissions = 0.00;
  double _driverRating = 4.63;

  Map<String, dynamic>? _activeOrder; // 🎯 تخزين الطلب النشط حالياً

  /// العروض المفتوحة على الكابتن دلوقتي (`pending_offers` معروضة عليه هو).
  /// بتتقرا من نفس نداء `/orders/available` اللي بيجيب الرحلة النشطة.
  List<dynamic> _openOffers = [];

  Timer? _dashboardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDriverSessionAndInitialize();
  }

  @override
  void dispose() {
    _stopLiveDashboardUpdates();
    _stopLocationUpdates();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLiveDashboardStats(_driverId);
      _refreshDriverWork(_driverId);
      _fetchOnlineStatus(_driverId);
      _startLiveDashboardUpdates();
      // 📍 أهم سطر هنا: بنبعت الموقع فوراً أول ما نرجع.
      //
      // السيرفر بيعتبر أي تحديث أقدم من `driver_location_ttl_min` (١٠ دقايق)
      // «بايت» ومش بيحسب الكابتن ضمن القريبين، فالعروض ما بتوصلهوش. لو
      // استنينا الـ Timer العادي ممكن يفضل ٢٠ ثانية تانية مستبعد من غير سبب.
      if (_isOnline) _pushLocationOnce();
    } else if (state == AppLifecycleState.paused) {
      _stopLiveDashboardUpdates();
      // ⚠️ الموقع **ما بيقفش** هنا عن قصد.
      //
      // ده كان بيوقف مع أول مرة الشاشة تتقفل، والكابتن يفضل `is_online = true`
      // والزرار في التطبيق يقول «أونلاين» — وبعد ١٠ دقايق يتحول لغير مرئي
      // لكل الطلبات من غير ما حد يقوله. حصل فعلاً: عميل عمل طلب، الموجة
      // راحت لصفر كباتن، والطلب فضل معلّق.
      //
      // النظام بيقفل الـ Timer لوحده لما يوقف العملية، وساعتها الشاشة بتعرض
      // تحذير أول ما ترجع (شوف `_isLocationStale`). اللي إحنا بنمنعه هنا إننا
      // نقطع البث بنفسنا والكابتن لسه شغال.
    }
  }

  Future<void> _loadDriverSessionAndInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final storedId = prefs.get('user_id');
    final id = int.tryParse(storedId?.toString() ?? '') ?? 21;
    final name = prefs.getString('user_name') ?? 'Talaat Harfoush';

    if (mounted) {
      setState(() {
        _driverId = id;
        _driverName = name;
      });
    }

    await _fetchLiveDashboardStats(id);
    await _refreshDriverWork(id); // 🎯 العروض الحيّة والرحلة النشطة فوراً
    await _fetchOnlineStatus(id);
    _startLiveDashboardUpdates();
  }

  Future<void> _fetchOnlineStatus(int driverId) async {
    final result = await _ordersService.getDriverOnlineStatus(driverId);
    if (mounted && result['success'] == true) {
      final online = result['isOnline'] == true;
      setState(() {
        _isOnline = online;
        // السيرفر بيقول `receivingOffers` — أونلاين + موقعه محدّث. لو أونلاين
        // وهو false يبقى موقعه بايت، وده اللي بنحذّر منه بدل الصمت.
        _locationStale = online && result['receivingOffers'] == false;
      });
      if (online) {
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }
    }
  }

  void _startLiveDashboardUpdates() {
    _dashboardTimer?.cancel();
    _dashboardTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _fetchLiveDashboardStats(_driverId);
      await _refreshDriverWork(_driverId); // 🎯 الاستعلام الحكيم المباشر
    });
  }

  /// الشغل المفتوح على الكابتن دلوقتي: العروض الحيّة + الرحلة اللي ماسكها.
  ///
  /// 🐞 دي كانت `_checkActiveAcceptedOrders` وكانت بتنده
  /// `GET /orders/driver/:id` — **مسار مش موجود على السيرفر خالص** — كل ٣
  /// ثواني جوّه `try/catch` فاضي. يعني كل نداء كان بيرجع 404 ويتبلع في صمت،
  /// وشاشة الكابتن ماكانتش بتعرف لا عن رحلة ولا عن عرض جديد. وكمان كانت
  /// بتدوّر على حالات (`in_progress` / `picked_up`) مش موجودة في مخطط حالات
  /// السيرفر أصلاً.
  ///
  /// المسار الصح هو `/orders/available` — نفس اللي شاشة السوق بتستخدمه.
  /// السيرفر بيرجّع منه بالظبط حاجتين: العروض اللي **اتعرضت على الكابتن ده**
  /// ولسه مهلتها شغالة، وشغله النشط. مفيش سوق مفتوح — الإسناد الموجّه زي ما
  /// هو، إحنا بس بنقرا نتيجته.
  ///
  /// مهم: العرض عمره ٦٠ ثانية بس. من غير القراءة الدورية دي الكابتن ماكانش
  /// ياخد باله من الطلب غير لو صادف إنه فاتح شاشة السوق في اللحظة دي، وده
  /// اللي خلّى طلبات تتولد وتنتهي صلاحيتها من غير ما حد يشوفها.
  static const List<String> _activeTripStatuses = [
    'accepted',
    'at_store',
    'items_bought',
    'delivering',
  ];

  Future<void> _refreshDriverWork(int driverId) async {
    final result = await _ordersService.getAvailableOrders(driverId: driverId);
    if (!mounted || result['success'] != true) return;

    final List<dynamic> orders = (result['data'] as List?) ?? const [];

    Map<String, dynamic>? active;
    final List<dynamic> offers = [];
    for (final raw in orders) {
      if (raw is! Map) continue;
      final order = Map<String, dynamic>.from(raw);
      final status = order['status']?.toString();
      if (status == 'pending_offers') {
        offers.add(order);
      } else if (active == null && _activeTripStatuses.contains(status)) {
        active = order;
      }
    }

    setState(() {
      _activeOrder = active;
      _openOffers = offers;
    });
  }

  /// يتأكد قبل ما الكابتن يقفل الاتصال وهو ماسك رحلة.
  ///
  /// الخروج من الاتصال **مابيلغيش** الرحلة — الطلب بيفضل مكلّف بيه والعميل
  /// مستنيه. الرسالة بتقول ده بصريح العبارة عشان محدش يفتكر إن قفل السويتش
  /// معناه إنه سلّم الطلب لحد تاني.
  Future<bool?> _confirmGoOfflineWithActiveTrips() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'عندك رحلة شغالة',
            style: TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: const Text(
            'لو قفلت الاتصال دلوقتي مش هتستقبل طلبات جديدة، لكن الرحلة اللي '
            'معاك دلوقتي هتفضل مكلّف بيها والعميل مستنيك.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('اقفل الاتصال',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pushLocationOnce() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos == null) return;
    await _locationApi.updateDriverLocation(
      driverId: _driverId,
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
  }

  /// تحذير: الكابتن أونلاين بس السيرفر مش شايف موقعه، فمفيش طلبات هتوصله.
  ///
  /// من غير الكارت ده الكابتن بيقعد مستني شغل والزرار بيقول إنه شغّال — وده
  /// اللي حصل فعلاً: طلب اتعمل وما وصلهوش، ومحصلش أي إشارة تقول ليه.
  Widget _buildLocationStaleBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_off_rounded,
              color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مش بتستقبل طلبات دلوقتي',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.amber.shade900)),
                const SizedBox(height: 3),
                Text(
                  'موقعك مش بيوصل للسيرفر، فالطلبات القريبة مش بتتعرض عليك. '
                  'اتأكد إن إذن الموقع مفعّل والتطبيق شغال.',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      height: 1.6,
                      color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await _pushLocationOnce();
              await _fetchOnlineStatus(_driverId);
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text('تحديث',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber.shade900)),
          ),
        ],
      ),
    );
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _pushLocationOnce();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _pushLocationOnce(),
    );
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void _stopLiveDashboardUpdates() {
    _dashboardTimer?.cancel();
    _dashboardTimer = null;
  }

  Future<void> _fetchLiveDashboardStats(int driverId) async {
    // الرصيد ليه مصدر واحد في التطبيق كله: `/wallet/summary`. الشاشة دي كانت
    // بتقراه من إحصائيات اللوحة وترجع لرقم افتراضي (150.66) لو القراءة فشلت،
    // وشاشة المحفظة بتقراه من نفس المسار وترجع لصفر — فالشاشتين كانوا بيعرضوا
    // رقمين مختلفين لنفس المحفظة. الرقم دلوقتي بييجي من مكان واحد، ولو ما
    // وصلش بنسيب آخر رقم معروف بدل ما نخترع واحد.
    await _fetchWalletBalance();

    final result = await _ordersService.getDriverDashboardStats(driverId);

    if (result['success'] == true && mounted) {
      final data = result['data'] ?? result;

      setState(() {
        _todayOrdersCount = int.tryParse(data['todayOrdersCount']?.toString() ?? '') ??
            int.tryParse(data['todayOrders']?.toString() ?? '') ??
            int.tryParse(data['completedOrders']?.toString() ?? '') ?? 0;

        _todayEarnings = double.tryParse(data['todayEarnings']?.toString() ?? '') ??
            double.tryParse(data['todayDeliveryFees']?.toString() ?? '') ?? 0.0;

        _todayCommissions = double.tryParse(data['todayCommissions']?.toString() ?? '') ??
            double.tryParse(data['commissions']?.toString() ?? '') ?? 0.0;

        _driverRating = double.tryParse(data['rating']?.toString() ?? '4.63') ?? 4.63;
      });
      return;
    }

    if (mounted && _isLoadingBalance) {
      setState(() => _isLoadingBalance = false);
    }
  }

  /// الرصيد المعتمد من المحفظة نفسها — من غير رقم كابتن، فما ينفعش يتوجّه
  /// لصف غلط لو الرقم المتخزّن محلياً قديم.
  Future<void> _fetchWalletBalance() async {
    final summary = await _walletService.getSummary();
    if (!mounted) return;
    if (summary['success'] == true) {
      final balance = (summary['balance'] as num?)?.toDouble() ??
          double.tryParse(summary['balance']?.toString() ?? '');
      if (balance != null) {
        setState(() {
          _walletBalance = balance;
          _isLoadingBalance = false;
        });
        return;
      }
    }
    if (_isLoadingBalance) setState(() => _isLoadingBalance = false);
  }

  void _toggleOnlineStatus(bool value) async {
    if (value && _walletBalance < 5.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عفواً، لا يمكنك استقبال طلبات. يرجى شحن محفظتك أولاً 💳', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 🛑 الخروج من الاتصال والكابتن عنده رحلة شغالة مش قرار عابر: الطلب
    // مابيتلغيش لوحده، والعميل مستني. بنتأكد الأول بدل ما يحصل بالغلط من
    // لمسة على السويتش.
    if (!value && _activeOrder != null) {
      final confirmed = await _confirmGoOfflineWithActiveTrips();
      if (confirmed != true || !mounted) return;
    }

    // السويتش بيقبل لمسات متتالية والحالة الحقيقية بتيجي من السيرفر، فضغط
    // سريع كان بيبعت طلبات متعارضة (اتصال/قطع/اتصال) والنتيجة الأخيرة
    // مش بالضرورة اللي الكابتن قصدها.
    await guardedSubmit(() => _applyOnlineStatus(value));
  }

  Future<void> _applyOnlineStatus(bool value) async {
    final result = await _ordersService.setDriverOnlineStatus(
      driverId: _driverId,
      isOnline: value,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'فشل تحديث حالة الاتصال', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isOnline = result['isOnline'] == true);

    if (_isOnline) {
      _startLocationUpdates();
    } else {
      _stopLocationUpdates();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOnline ? 'أنت أونلاين الآن! مستعد لاستقبال الطلبات ⚡' : 'تم تحويل حسابك أوفلاين.',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: _isOnline ? const Color(0xFF16A34A) : AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAccountActive = (_walletBalance > -10.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(right: 12.0, top: 6.0, bottom: 6.0),
          child: GestureDetector(
            onTap: () async {
              _stopLiveDashboardUpdates();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WaslDriverProfileScreen()),
              );
              _loadDriverSessionAndInitialize();
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
              ),
            ),
          ),
        ),
        title: const Text(
          'لوحة التحكم',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.assignment_rounded, color: AppColors.textPrimary, size: 20),
              tooltip: 'رحلاتي وتكليفاتي',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslDriverOrdersScreen()));
              },
            ),
          ),
          const SizedBox(width: 8),
          WaslNotificationBell(userId: _driverId),
          const SizedBox(width: 16),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🎯 [التنبيه البارز المباشر]: يظهر فوراً بأعلى الصفحة بمجرد قبول العميل للعرض
                if (_activeOrder != null) _buildActiveOrderBanner(),

                // 📦 عرض جديد معروض على الكابتن دلوقتي. بيتحدّث مع نبضة الـ ٣
                // ثواني اللي فوق، فالطلب بيبان لوحده من غير ما الكابتن يفتح
                // شاشة السوق ولا يعيد تشغيل التطبيق. المهلة ٦٠ ثانية بس،
                // فالبانر ده هو الفرق بين إن الطلب يتشاف وإنه ينتهي لوحده.
                if (_openOffers.isNotEmpty) _buildOpenOffersBanner(),

                // 1️⃣ كارت حالة الاتصال
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: AppColors.textPrimary.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _isOnline ? const Color(0xFFDCFCE7) : AppColors.primary.withOpacity(0.06),
                        child: Icon(
                            Icons.delivery_dining_rounded,
                            color: _isOnline ? const Color(0xFF16A34A) : AppColors.primary,
                            size: 26
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('يا هلا، كابتن $_driverName 👋', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                            const SizedBox(height: 2),
                            Text(
                              _isOnline ? 'متاح ومستعد لاستقبال عروض الساحة' : 'وضع عدم الاتصال بالخدمة',
                              style: TextStyle(fontSize: 11, color: _isOnline ? const Color(0xFF16A34A) : AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        onChanged: _toggleOnlineStatus,
                        activeColor: const Color(0xFF16A34A),
                        activeTrackColor: const Color(0xFFDCFCE7),
                      )
                    ],
                  ),
                ),
                // ⚠️ أونلاين بس مش بيستقبل — الحالة اللي كانت صامتة تماماً.
                if (_locationStale) _buildLocationStaleBanner(),
                const SizedBox(height: 16),

                // 2️⃣ بطاقة المحفظة الرقمية الفاخرة
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 6))
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      _stopLiveDashboardUpdates();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WaslDeliveryPaymentScreen()),
                      );
                      _loadDriverSessionAndInitialize();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('الرصيد المتاح بالمحفظة (اضغط للشحن) 💳', style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              const Icon(Icons.add_card_rounded, color: Colors.amber, size: 20),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _isLoadingBalance
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : Text(
                            '${_walletBalance.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'Cairo', letterSpacing: -0.5),
                          ),
                          const Divider(height: 20, color: Colors.white12, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Expanded(
                                child: Text(
                                  '💡 اضغط هنا لإعادة شحن رصيدك عبر المحافظ الإلكترونية أو الفيزا فوراُ.',
                                  style: TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'Cairo', height: 1.4),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3️⃣ تقارير الأداء اليومية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تقرير الأداء اليومي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                      onPressed: () {
                        _fetchLiveDashboardStats(_driverId);
                        _refreshDriverWork(_driverId);
                      },
                    )
                  ],
                ),
                const SizedBox(height: 8),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildMetricCard('طلبات اليوم المكتملة', '$_todayOrdersCount', Icons.check_circle_rounded, const Color(0xFF16A34A)),
                    _buildMetricCard('أرباح التوصيل كاش', '${_todayEarnings.toStringAsFixed(0)} ج.م', Icons.monetization_on_rounded, AppColors.primary),
                    _buildMetricCard('عمولات مخصومة', '${_todayCommissions.toStringAsFixed(0)} ج.م', Icons.trending_down_rounded, AppColors.danger),
                    _buildMetricCard('تقييمك التراكمي', '${_driverRating.toStringAsFixed(2)} ★', Icons.star_rounded, Colors.amber.shade700),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: GestureDetector(
          onTap: isAccountActive
              ? () async {
            if (!_isOnline) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('برجاء تفعيل وضع الاتصال (Online) أولاً لرؤية الطلبات المتاحة 📡', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.warning),
              );
              return;
            }
            _stopLiveDashboardUpdates();
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslDriverMarketplaceScreen()));
            _loadDriverSessionAndInitialize();
          }
              : null,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isAccountActive ? AppColors.textPrimary : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (isAccountActive)
                  BoxShadow(color: AppColors.textPrimary.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    isAccountActive ? Icons.gavel_rounded : Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 18
                ),
                const SizedBox(width: 8),
                Text(
                  isAccountActive ? 'الانتقال لساحة الطلبات المتاحة 🏁' : '🔒 الحساب معلق (تجاوز حد الدين)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// كارت العروض المفتوحة — الطلبات اللي السيرفر عرضها على الكابتن ده دلوقتي.
  ///
  /// بيروح لشاشة السوق لأنها المكان الوحيد اللي بيعرض العروض فعلاً؛ شاشة
  /// «رحلاتي وتكليفاتي» بتفلتر على `acceptedDriverId == أنا` في التبويبين،
  /// فالطلب المعروض (لسه `pending_offers` ومن غير كابتن) مبيظهرش فيها أصلاً.
  ///
  /// أول ما الكابتن يرجع من السوق بنقرا الحالة تاني، عشان لو قبل الطلب البانر
  /// يختفي على طول بدل ما يستنى النبضة الجاية.
  Widget _buildOpenOffersBanner() {
    final count = _openOffers.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WaslDriverMarketplaceScreen()),
            );
            if (mounted) await _refreshDriverWork(_driverId);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Color(0xFFEA580C), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1
                            ? 'عندك طلب جديد معروض عليك!'
                            : 'عندك $count طلبات جديدة معروضة عليك!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'المهلة دقيقة واحدة — دوس لمراجعة الطلب وقبوله',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎯 كارت التنبيه الفوري للطلب المقبول
  Widget _buildActiveOrderBanner() {
    final orderId = _activeOrder?['id'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WaslDriverOrdersScreen()),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 تم قبول عرضك للطلب #$orderId!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'اضغط هنا للانتقال لصفحة الرحلات والتوصيل فوراً 🏍️',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}