// import 'dart:async'; // 🎯 مستدعى ومفعل للمزامنة الآنية
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverMarketplaceScreen.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverOrdersScreen.dart';
// import 'package:wasl_app/delivery_screen/WaslDriverProfileScreen.dart';
// import 'package:wasl_app/screens/WaslNotificationBell.dart';
// import 'package:wasl_app/delivery_screen/WaslDeliveryPaymentScreen.dart';
//
// class WaslDriverHomeScreen extends StatefulWidget {
//   const WaslDriverHomeScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslDriverHomeScreen> createState() => _WaslDriverHomeScreenState();
// }
//
// class _WaslDriverHomeScreenState extends State<WaslDriverHomeScreen> {
//   bool _isOnline = false;
//   String _driverName = 'جاري التحميل...';
//   int? _driverId;
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
//     _loadDriverSessionAndInitialize();
//   }
//
//   Future<void> _loadDriverSessionAndInitialize() async {
//     final prefs = await SharedPreferences.getInstance();
//     final id = prefs.getInt('user_id') ?? 21;
//     final name = prefs.getString('user_name') ?? 'كابتن وصل';
//
//     setState(() {
//       _driverId = id;
//       _driverName = name;
//     });
//
//     await _fetchLiveDashboardStats(id);
//     _startLiveDashboardUpdates();
//   }
//
//   void _startLiveDashboardUpdates() {
//     _dashboardTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//       if (_driverId != null) {
//         await _fetchLiveDashboardStats(_driverId!);
//       }
//     });
//   }
//
//   Future<void> _fetchLiveDashboardStats(int driverId) async {
//     final url = Uri.parse('http://10.0.2.2:3000/orders/driver/$driverId/dashboard-stats');
//
//     try {
//       final response = await http.get(
//         url,
//         headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
//       ).timeout(const Duration(seconds: 8));
//
//       if (response.statusCode == 200 && mounted) {
//         final data = jsonDecode(response.body);
//
//         if (data != null) {
//           setState(() {
//             // معالجة مرنة لقراءة الحقول الحية اليومية أو الإجمالية لتجنب الأصفار
//             _walletBalance = double.tryParse(data['balance']?.toString() ?? '') ??
//                 double.tryParse(data['walletBalance']?.toString() ?? '0.0') ?? 0.0;
//
//             _todayOrdersCount = int.tryParse(data['todayOrdersCount']?.toString() ?? '') ??
//                 int.tryParse(data['completedOrdersCount']?.toString() ?? '0') ?? 0;
//
//             _todayEarnings = double.tryParse(data['todayEarnings']?.toString() ?? '') ??
//                 double.tryParse(data['totalEarnings']?.toString() ?? '0.0') ?? 0.0;
//
//             _todayCommissions = double.tryParse(data['todayCommissions']?.toString() ?? '') ??
//                 double.tryParse(data['totalCommissions']?.toString() ?? '0.0') ?? 0.0;
//
//             _driverRating = double.tryParse(data['rating']?.toString() ?? '4.95') ?? 4.95;
//             _isLoadingBalance = false;
//           });
//           return;
//         }
//       }
//     } catch (e) {
//       debugPrint('💥 [LIVE STATS FETCH ERROR]: $e');
//     }
//     if (mounted) setState(() => _isLoadingBalance = false);
//   }
//
//   @override
//   void dispose() {
//     _dashboardTimer?.cancel();
//     super.dispose();
//   }
//
//   void _toggleOnlineStatus(bool value) {
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
//     setState(() {
//       _isOnline = value;
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           _isOnline ? 'أنت أونلاين الآن! مستعد استقبال عروض الأسعار ⚡' : 'تم تحويل حسابك أوفلاين بنجاح.',
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
//         leadingWidth: 56,
//         leading: Padding(
//           padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
//           child: GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const WaslDriverProfileScreen()),
//               );
//             },
//             child: Container(
//               decoration: BoxDecoration(
//                 color: AppColors.primary.withOpacity(0.06),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
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
//               icon: const Icon(Icons.assignment_rounded, color: AppColors.textPrimary, size: 18),
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslDriverOrdersScreen()));
//               },
//             ),
//           ),
//           const SizedBox(width: 4),
//           WaslNotificationBell(userId: _driverId ?? 21),
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
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => const WaslDeliveryPaymentScreen()),
//                       );
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
//                 // 3️⃣ تقارير الأداء الفلات الاحترافية
//                 const Text('تقرير الأداء اليومي (كوم حمادة)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                 const SizedBox(height: 12),
//
//                 GridView.count(
//                   shrinkWrap: true,
//                   physics: const NeverScrollableScrollPhysics(),
//                   crossAxisCount: 2,
//                   childAspectRatio: 1.25, // 🎯 تم تعديل النسبة لإعطاء مساحة كافية لظهور الأرقام والعملة منعاً للـ Clipping
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
//               ? () {
//             if (!_isOnline) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('برجاء تفعيل وضع الاتصال (Online) أولاً لرؤية الطلبات المتاحة 📡', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.warning),
//               );
//               return;
//             }
//             Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslDriverMarketplaceScreen()));
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
//   // 🎯 تم إعادة هيكلة دالة كرت الأداء لضمان بقاء الأرقام متناسقة وبدون سقوط بصري
//   Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start, // محاذاة لليمين مع الـ RTL
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               // حماية النص من الـ Overflow عن طريق الـ Expanded
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
//           const Spacer(), // حقن مسافة مرنة تدفع الرقم للأسفل بثبات
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

class WaslDriverHomeScreen extends StatefulWidget {
  const WaslDriverHomeScreen({Key? key}) : super(key: key);

  @override
  State<WaslDriverHomeScreen> createState() => _WaslDriverHomeScreenState();
}

class _WaslDriverHomeScreenState extends State<WaslDriverHomeScreen> with WidgetsBindingObserver {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  final LocationApiService _locationApi = LocationApiService();
  Timer? _locationTimer;
  bool _isOnline = false;
  String _driverName = 'جاري التحميل...';
  int _driverId = 21; // القيمة الافتراضية المعتمدة لـ MVP V1

  double _walletBalance = 0.00;
  bool _isLoadingBalance = true;

  int _todayOrdersCount = 0;
  double _todayEarnings = 0.00;
  double _todayCommissions = 0.00;
  double _driverRating = 4.95;

  Timer? _dashboardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // لمراقبة عودة الكابتن للتطبيق من الخلفية
    _loadDriverSessionAndInitialize();
  }

  @override
  void dispose() {
    _stopLiveDashboardUpdates();
    _stopLocationUpdates();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🎯 تحديث البيانات تلقائياً لو الكابتن فتح الموبايل بعد قفله
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLiveDashboardStats(_driverId);
      _fetchOnlineStatus(_driverId);
      _startLiveDashboardUpdates();
    } else if (state == AppLifecycleState.paused) {
      _stopLiveDashboardUpdates();
      _stopLocationUpdates();
    }
  }

  Future<void> _loadDriverSessionAndInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // تحديث قاطع لذاكرة الكاش

    // 🛡️ تأمين جلب الـ ID بشكل مرن سواء كان مخزناً كـ String أو Int في السيرفر
    final storedId = prefs.get('user_id');
    final id = int.tryParse(storedId?.toString() ?? '') ?? 21;
    final name = prefs.getString('user_name') ?? 'كابتن وصل';

    if (mounted) {
      setState(() {
        _driverId = id;
        _driverName = name;
      });
    }

    await _fetchLiveDashboardStats(id);
    await _fetchOnlineStatus(id);
    _startLiveDashboardUpdates();
  }

  Future<void> _fetchOnlineStatus(int driverId) async {
    final result = await _ordersService.getDriverOnlineStatus(driverId);
    if (mounted && result['success'] == true) {
      final online = result['isOnline'] == true;
      setState(() => _isOnline = online);
      // Resume/stop live location push to match the restored session state.
      if (online) {
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }
    }
  }

  void _startLiveDashboardUpdates() {
    _dashboardTimer?.cancel(); // منع تداخل المؤقتات في الخلفية
    _dashboardTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _fetchLiveDashboardStats(_driverId);
    });
  }

  // 🛰️ بث موقع الكابتن الحي للسيرفر أثناء الأونلاين ليظهر في بحث "الأقرب"
  Future<void> _pushLocationOnce() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos == null) return;
    await _locationApi.updateDriverLocation(
      driverId: _driverId,
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _pushLocationOnce(); // بث فوري أول ما يبقى أونلاين
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
    final result = await _ordersService.getDriverDashboardStats(driverId);

    if (result['success'] == true && mounted) {
      setState(() {
        _walletBalance = double.tryParse(result['balance']?.toString() ?? '') ?? 0.0;
        _todayOrdersCount = int.tryParse(result['todayOrdersCount']?.toString() ?? '') ?? 0;
        _todayEarnings = double.tryParse(result['todayEarnings']?.toString() ?? '') ?? 0.0;
        _todayCommissions = double.tryParse(result['todayCommissions']?.toString() ?? '') ?? 0.0;
        _driverRating = double.tryParse(result['rating']?.toString() ?? '4.95') ?? 4.95;
        _isLoadingBalance = false;

        if (_walletBalance < 5 && _isOnline) {
          _isOnline = false;
        }
      });
      return;
    }

    if (mounted && _isLoadingBalance) {
      setState(() => _isLoadingBalance = false);
    }
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

    // 🛰️ Start/stop live GPS push so this driver appears in nearby search.
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
              _stopLiveDashboardUpdates(); // إيقاف مؤقت للراحة أثناء تصفح البروفايل
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WaslDriverProfileScreen()),
              );
              _loadDriverSessionAndInitialize(); // 🎯 إعادة تشغيل الفحص فور العودة للشاشة الرئيسية
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
            decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
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
                const Text('تقرير الأداء اليومي (كوم حمادة)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                const SizedBox(height: 12),

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