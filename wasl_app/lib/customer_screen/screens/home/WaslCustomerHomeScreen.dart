// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/customer_screen/screens/home/WaslCategoryDetailsScreen.dart';
// import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderCategoryScreen.dart';
// import 'package:wasl_app/customer_screen/profile/WaslSettingsScreen.dart';
// import 'package:wasl_app/services/auth_service.dart';
// // 🎯 استيراد جرس الإشعارات الذكي لايف
// import 'package:wasl_app/screens/WaslNotificationBell.dart';
//
// class WaslCustomerHomeScreen extends StatefulWidget {
//   const WaslCustomerHomeScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslCustomerHomeScreen> createState() => _WaslCustomerHomeScreenState();
// }
//
// class _WaslCustomerHomeScreenState extends State<WaslCustomerHomeScreen> {
//   int _currentIndex = 4;
//   String _customerName = '...';
//   String _currentAddress = 'جاري تحديد موقعك الـ GPS...';
//   int? _customerId; // 🎯 حفظ الـ id الخاص بالعميل للاستماع لإشعاراته
//
//   bool _isLoadingStores = true;
//   bool _isLoadingCategories = true;
//
//   Position? _currentPosition;
//   List<dynamic> _liveCategories = [];
//   List<dynamic> _liveStores = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _initLiveLocationAndData();
//   }
//
//   Future<void> _initLiveLocationAndData() async {
//     final prefs = await SharedPreferences.getInstance();
//     if (mounted) {
//       setState(() {
//         _customerId = prefs.getInt('user_id') ?? 1; // الافتراضي 1 للتست
//         _customerName = prefs.getString('user_name') ?? 'عميل وصل';
//       });
//     }
//
//     _fetchLiveCategories();
//
//     _determineLivePosition().then((_) {
//       _fetchLiveStores();
//     }).catchError((e) {
//       _fetchLiveStores();
//     });
//   }
//
//   Future<void> _determineLivePosition() async {
//     bool serviceEnabled;
//     LocationPermission permission;
//
//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       if (mounted) setState(() => _currentAddress = 'خدمة الـ GPS معطلة بجهازك');
//       return;
//     }
//
//     permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         if (mounted) setState(() => _currentAddress = 'تم رفض صلاحية الوصول للموقع');
//         return;
//       }
//     }
//
//     if (permission == LocationPermission.deniedForever) {
//       if (mounted) setState(() => _currentAddress = 'الصلاحية مرفوضة من الإعدادات');
//       return;
//     }
//
//     try {
//       Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//       if (mounted) {
//         setState(() {
//           _currentPosition = position;
//           _currentAddress = "موقع نشط (Lat: ${position.latitude.toStringAsFixed(3)}, Lng: ${position.longitude.toStringAsFixed(3)})";
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() => _currentAddress = 'فشل جلب إشارات الـ GPS الحية');
//     }
//   }
//
//   Future<void> _fetchLiveCategories() async {
//     try {
//       final res = await FlutterAuthService().getCategories();
//
//       if (mounted && res != null && res['success'] == true) {
//         setState(() {
//           _liveCategories = res['data'] ?? [];
//           _isLoadingCategories = false;
//         });
//       } else {
//         _fallbackCategories();
//       }
//     } catch (e) {
//       _fallbackCategories();
//     }
//   }
//
//   void _fallbackCategories() {
//     if (mounted) {
//       setState(() {
//         _liveCategories = [
//           {'id': 1, 'name': 'مطاعم', 'iconName': 'restaurant', 'color': '#EBF3FF'},
//           {'id': 2, 'name': 'تموينك', 'iconName': 'shopping', 'color': '#E8F5E9'},
//           {'id': 3, 'name': 'صيدليات', 'iconName': 'pharmacy', 'color': '#FFFFEBEE'},
//           {'id': 4, 'name': 'مخابز', 'iconName': 'bakery', 'color': '#E3F2FD'},
//           {'id': 5, 'name': 'إلكترونيات', 'iconName': 'devices', 'color': '#F0F4F8'},
//           {'id': 6, 'name': 'قرطاسية', 'iconName': 'edit_note', 'color': '#F1F5F9'},
//           {'id': 7, 'name': 'هدايا', 'iconName': 'gift', 'color': '#FFF8E1'},
//           {'id': 8, 'name': 'منزل', 'iconName': 'home', 'color': '#E0F7FA'},
//         ];
//         _isLoadingCategories = false;
//       });
//     }
//   }
//
//   Future<void> _fetchLiveStores() async {
//     try {
//       final res = await FlutterAuthService().getNearbyStores(
//         lat: _currentPosition?.latitude ?? 30.0,
//         lng: _currentPosition?.longitude ?? 31.0,
//       );
//
//       if (mounted && res != null && res['success'] == true) {
//         setState(() {
//           _liveStores = res['data'] ?? [];
//           _isLoadingStores = false;
//         });
//       } else {
//         _fallbackStores();
//       }
//     } catch (e) {
//       _fallbackStores();
//     }
//   }
//
//   void _fallbackStores() {
//     if (mounted) {
//       setState(() {
//         _liveStores = [
//           {
//             'merchant_store_name': 'برجر العزبي - الفرع الأقرب',
//             'merchant_store_type': 'مطاعم • وجبات سريعة',
//             'merchant_logo': null,
//             'distance': 0.85,
//           },
//           {
//             'merchant_store_name': 'صيدلية العزبي المركزية',
//             'merchant_store_type': 'أدوية • مستحضرات طبية',
//             'merchant_logo': null,
//             'distance': 1.20,
//           }
//         ];
//         _isLoadingStores = false;
//       });
//     }
//   }
//
//   Widget _buildHomeBody() {
//     return RefreshIndicator(
//       color: AppColors.primary,
//       onRefresh: _initLiveLocationAndData,
//       child: SingleChildScrollView(
//         physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.only(bottom: 14.0, right: 4.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'أهلاً بك، $_customerName 👋',
//                     style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//                   ),
//                   const Text(
//                     'أين تود التوصيل اليوم؟',
//                     style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo'),
//                   ),
//                 ],
//               ),
//             ),
//
//             Container(
//               decoration: BoxDecoration(
//                 boxShadow: [
//                   BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
//                 ],
//               ),
//               child: TextField(
//                 style: const TextStyle(color: AppColors.textPrimary),
//                 decoration: InputDecoration(
//                   hintText: 'ابحث عن متجر أو منتج قريب منك...',
//                   hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
//                   prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
//                   suffixIcon: Container(
//                     margin: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
//                     child: const Icon(Icons.tune_outlined, size: 18, color: AppColors.primary),
//                   ),
//                   fillColor: AppColors.white,
//                   filled: true,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//
//             Container(
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFFFF5100), Color(0xFFFF8800)],
//                   begin: Alignment.topRight,
//                   end: Alignment.bottomLeft,
//                 ),
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))
//                 ],
//               ),
//               child: InkWell(
//                 onTap: () {
//                   Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen()));
//                 },
//                 borderRadius: BorderRadius.circular(20),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
//                   child: Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
//                         child: const Icon(Icons.bolt, color: Colors.white, size: 28),
//                       ),
//                       const SizedBox(width: 14),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: const [
//                             Text('📦 اطلب أي حاجة من أي مكان', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                             Text('اكتب طلبك بنفسك وهنوصله ليك فوراً', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo')),
//                           ],
//                         ),
//                       ),
//                       const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text('التصنيفات المتاحة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                 GestureDetector(
//                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen())),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
//                     child: const Text('عرض الكل', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 14),
//
//             _isLoadingCategories
//                 ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: AppColors.primary)))
//                 : GridView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: _liveCategories.length,
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
//               itemBuilder: (context, i) {
//                 final cat = _liveCategories[i];
//                 return GestureDetector(
//                   onTap: () => Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (_) => const WaslCategoryDetailsScreen())
//                   ),
//                   child: Column(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(14),
//                         decoration: BoxDecoration(
//                             color: cat['color'] != null
//                                 ? Color(int.parse(cat['color'].toString().replaceAll('#', '0xFF')))
//                                 : AppColors.primary.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(16)
//                         ),
//                         child: Icon(_getIconData(cat['iconName']), color: AppColors.primary),
//                       ),
//                       const SizedBox(height: 6),
//                       Text(cat['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
//                     ],
//                   ),
//                 );
//               },
//             ),
//             const SizedBox(height: 28),
//
//             const Text('متاجر نشطة قريبة منك حالياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//             const SizedBox(height: 12),
//
//             _isLoadingStores
//                 ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppColors.primary)))
//                 : ListView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: _liveStores.length,
//               itemBuilder: (context, index) {
//                 final store = _liveStores[index];
//
//                 String storeName = store['merchant_store_name'] ?? 'متجر وصل شريك';
//                 String storeType = store['merchant_store_type'] ?? 'توصيل سريـع';
//
//                 double rawDistance = double.tryParse(store['distance']?.toString() ?? '0.0') ?? 0.0;
//                 String formattedDist = "${rawDistance.toStringAsFixed(1)} كم";
//
//                 return _buildLiveStoreCard(
//                   name: storeName,
//                   tags: storeType,
//                   rate: '4.7',
//                   dist: formattedDist,
//                   time: "${(rawDistance * 10 + 5).toInt()} دقيقة",
//                   fee: "${(rawDistance * 5 + 10).toInt()} ج.م",
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLiveStoreCard({required String name, required String tags, required String rate, required String dist, required String time, required String fee}) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
//         ],
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Container(
//               width: 70,
//               height: 70,
//               decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
//               child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 28)
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
//                 const SizedBox(height: 2),
//                 Text(tags, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
//                 const SizedBox(height: 6),
//                 Wrap(
//                   crossAxisAlignment: WrapCrossAlignment.center,
//                   spacing: 6,
//                   runSpacing: 4,
//                   children: [
//                     Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
//                         Text(' $rate ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
//                       ],
//                     ),
//                     Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
//                         Text(' $dist ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
//                       ],
//                     ),
//                     Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
//                         Text(' $time', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
//                       ],
//                     ),
//                   ],
//                 )
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(fee, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo', fontSize: 13)),
//               const SizedBox(height: 6),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
//                 child: const Text('مفتوح', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//               )
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   IconData _getIconData(String? iconName) {
//     switch (iconName) {
//       case 'restaurant': return Icons.restaurant_menu;
//       case 'pharmacy': return Icons.local_pharmacy_outlined;
//       case 'shopping': return Icons.shopping_basket_outlined;
//       case 'bakery': return Icons.bakery_dining_outlined;
//       case 'devices': return Icons.devices;
//       case 'edit_note': return Icons.edit_note;
//       case 'gift': return Icons.card_giftcard;
//       case 'home': return Icons.home_work_outlined;
//       default: return Icons.storefront_rounded;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final List<Widget> _pages = [
//       const WaslSettingsScreen(),
//       const Center(child: Text('شاشة الطلبات الجارية والمكتملة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
//       const Center(child: Text('المحفظة الرقمية للكباتن والعملاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
//       const Center(child: Text('العروض الترويجية الحصرية لـ وصل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
//       _buildHomeBody(),
//     ];
//
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: _currentIndex == 4
//           ? AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0,
//         centerTitle: true,
//         leading: Padding(
//           padding: const EdgeInsets.all(6.0),
//           child: CircleAvatar(
//             backgroundColor: AppColors.background,
//             child: IconButton(icon: const Icon(Icons.menu, color: AppColors.textPrimary, size: 20), onPressed: () {}),
//           ),
//         ),
//         title: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: const [
//                 Icon(Icons.location_on, size: 14, color: AppColors.primary),
//                 SizedBox(width: 4),
//                 Text('التوصيل الحالي للعنوان القريب ▾', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo')),
//               ],
//             ),
//             const SizedBox(height: 2),
//             SizedBox(
//               width: 220,
//               child: Text(_currentAddress, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
//             ),
//           ],
//         ),
//         actions: [
//           // 🎯 [تم التحديث والحقن]: زرع جرس الإشعارات اللوجستي الذكي للعميل لايف
//           WaslNotificationBell(userId: _customerId ?? 1),
//           const SizedBox(width: 4),
//         ],
//       )
//           : null,
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: IndexedStack(
//           index: _currentIndex,
//           children: _pages,
//         ),
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: (index) => setState(() => _currentIndex = index),
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: AppColors.primary,
//         unselectedItemColor: AppColors.textSecondary,
//         backgroundColor: AppColors.white,
//         selectedFontSize: 11,
//         unselectedFontSize: 11,
//         selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
//         unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo'),
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'الحساب'),
//           BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'الطلبات'),
//           BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'المحفظة'),
//           BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), activeIcon: Icon(Icons.local_offer), label: 'العروض'),
//           BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'الرئيسية'),
//         ],
//       ),
//     );
//   }
// }




import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/screens/home/WaslCategoryDetailsScreen.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderCategoryScreen.dart';
import 'package:wasl_app/customer_screen/profile/WaslSettingsScreen.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslMyOrdersScreen.dart';
import 'package:wasl_app/customer_screen/profile/WaslCustomerWalletScreen.dart';
import 'package:wasl_app/customer_screen/profile/WaslCustomerOffersScreen.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/screens/WaslNotificationBell.dart';

class WaslCustomerHomeScreen extends StatefulWidget {
  const WaslCustomerHomeScreen({Key? key}) : super(key: key);

  @override
  State<WaslCustomerHomeScreen> createState() => _WaslCustomerHomeScreenState();
}

class _WaslCustomerHomeScreenState extends State<WaslCustomerHomeScreen> {
  int _currentIndex = 4;
  String _customerName = '...';
  String _currentAddress = 'جاري تحديد الموقع الـ GPS...';
  int? _customerId;

  bool _isLoadingStores = true;
  bool _isLoadingCategories = true;

  Position? _currentPosition;
  List<dynamic> _liveCategories = [];
  List<dynamic> _liveStores = [];

  /// سبب خلو قائمة المتاجر (مفيش GPS / مفيش متاجر قريبة / عطل اتصال).
  String _storesMessage = '';

  @override
  void initState() {
    super.initState();
    _initLiveLocationAndData();
  }

  Future<void> _initLiveLocationAndData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _customerId = prefs.getInt('user_id') ?? 1;
        _customerName = prefs.getString('user_name') ?? 'عميل وصل';
      });
    }

    _fetchLiveCategories();

    _determineLivePosition().then((_) {
      _fetchLiveStores();
    }).catchError((e) {
      _fetchLiveStores();
    });
  }

  Future<void> _determineLivePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _currentAddress = 'خدمة الـ GPS معطلة بجهازك');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentAddress = 'تم رفض صلاحية الموقع');
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = "مركز كوم حمادة، محافظة البحيرة";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = 'فشل جلب إشارات الـ GPS حياً');
    }
  }

  Future<void> _fetchLiveCategories() async {
    try {
      final res = await FlutterAuthService().getCategories();
      if (mounted && res['success'] == true) {
        setState(() {
          _liveCategories = res['data'] ?? [];
          _isLoadingCategories = false;
        });
      } else {
        _fallbackCategories();
      }
    } catch (e) {
      _fallbackCategories();
    }
  }

  void _fallbackCategories() {
    if (mounted) {
      setState(() {
        _liveCategories = [
          {'id': 1, 'name': 'مطاعم', 'iconName': 'restaurant', 'color': '#F8FAFC'},
          {'id': 2, 'name': 'تموينك', 'iconName': 'shopping', 'color': '#F8FAFC'},
          {'id': 3, 'name': 'صيدليات', 'iconName': 'pharmacy', 'color': '#F8FAFC'},
          {'id': 4, 'name': 'مخابز', 'iconName': 'bakery', 'color': '#F8FAFC'},
        ];
        _isLoadingCategories = false;
      });
    }
  }

  // 🏪 المتاجر الحقيقية بس. الفرع الاحتياطي القديم كان بيعرض "مطعم الشرقاوي"
  // و"صيدلية العزبي" وهميين — يعني العميل يدوس على متجر مش موجود. لو مفيش
  // متاجر معتمدة قريبة، بنقول كده صراحة.
  Future<void> _fetchLiveStores() async {
    if (_currentPosition == null) {
      // من غير GPS مفيش معنى لـ "قريب منك" — بلاش نخترع موقع.
      if (mounted) {
        setState(() {
          _liveStores = [];
          _storesMessage = 'فعّل خدمة الموقع لعرض المتاجر القريبة منك';
          _isLoadingStores = false;
        });
      }
      return;
    }

    try {
      final res = await FlutterAuthService().getNearbyStores(
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
      );
      if (!mounted) return;

      if (res['success'] == true) {
        final List stores = (res['data'] as List?) ?? [];
        setState(() {
          _liveStores = stores;
          _storesMessage = stores.isEmpty
              ? 'لا توجد متاجر شريكة في نطاقك حالياً — تقدر تطلب أي حاجة من أي مكان عبر زر الطلب'
              : '';
          _isLoadingStores = false;
        });
      } else {
        setState(() {
          _liveStores = [];
          _storesMessage = 'تعذّر تحميل المتاجر القريبة، حاول مرة أخرى';
          _isLoadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _liveStores = [];
          _storesMessage = 'تعذّر الاتصال بالسيرفر لعرض المتاجر';
          _isLoadingStores = false;
        });
      }
    }
  }

  Widget _buildHomeBody() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _initLiveLocationAndData,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 الترحيب الذكي والمخصص لأحمد طليطلة
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أهلاً بك، $_customerName 👋',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Cairo', letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'أين تود التوصيل اليوم؟',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // 🔍 صندوق البحث الاحترافي والناعم (Minimalistic Search Bar)
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: AppColors.textPrimary.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ابحث عن متجر أو منتج قريب منك...',
                  hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                  ),
                  fillColor: AppColors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ⚡ بانر الطلب السريع الفخم والمبسط (Premium Fluid Banner)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 8))
                ],
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen()));
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('📦 اطلب أي حاجة من أي مكان', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            SizedBox(height: 2),
                            Text('اكتب طلبك يدويّاً وهنوصله ليك فوراً بكوم حمادة', style: TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 🧱 قسم التصنيفات الاحترافي بنمط بطاقات هادئة (Flat Minimal Categories)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('التصنيفات المتاحة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslOrderCategoryScreen())),
                  child: Text('عرض الكل ▾', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _isLoadingCategories
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: AppColors.primary)))
                : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _liveCategories.length > 4 ? 4 : _liveCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9),
              itemBuilder: (context, i) {
                final cat = _liveCategories[i];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaslCategoryDetailsScreen())),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getIconData(cat['iconName']), color: AppColors.primary, size: 22),
                        const SizedBox(height: 6),
                        Text(cat['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 26),

            // 🏪 المتاجر النشطة (Premium Store Cards)
            const Text('متاجر نشطة قريبة منك حالياً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
            const SizedBox(height: 12),

            if (_isLoadingStores)
              const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_liveStores.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 30, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      _storesMessage.isEmpty ? 'لا توجد متاجر شريكة قريبة حالياً' : _storesMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo', height: 1.6),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _liveStores.length,
                itemBuilder: (context, index) {
                  final store = _liveStores[index];
                  final distance = double.tryParse(store['distance']?.toString() ?? '');
                  return _buildLiveStoreCard(
                    name: store['merchant_store_name'] ?? 'متجر وصل شريك',
                    tags: store['merchant_store_type'] ?? '',
                    dist: distance == null ? '' : '${distance.toStringAsFixed(1)} كم',
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ⚠️ التقييم ووقت التوصيل ورسوم التوصيل كانت بتتحسب هنا بأرقام مخترعة
  // (4.7 ثابت، والمسافة×10+5 دقيقة، والمسافة×5+10 جنيه) — ورقم الرسوم ده كان
  // بيخالف محرك التسعير الحقيقي في السيرفر. اتشالوا لحد ما يبقى ليهم مصدر حقيقي.
  Widget _buildLiveStoreCard({required String name, required String tags, required String dist}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24)
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(tags, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (dist.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                      Text(' $dist', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant_rounded;
      case 'pharmacy': return Icons.local_pharmacy_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'bakery': return Icons.bakery_dining_rounded;
      default: return Icons.storefront_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const WaslSettingsScreen(),
      const WaslMyOrdersScreen(),
      const WaslCustomerWalletScreen(),
      const WaslCustomerOffersScreen(),
      _buildHomeBody(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _currentIndex == 4
          ? AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.background,
            child: IconButton(icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 20), onPressed: () {}),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text('التوصيل الحالي للعنوان القريب ▾', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo')),
              ],
            ),
            const SizedBox(height: 1),
            SizedBox(
              width: 200,
              child: Text(_currentAddress, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
        actions: [
          WaslNotificationBell(userId: _customerId ?? 1),
          const SizedBox(width: 8),
        ],
      )
          : null,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.white,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo'),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'الحساب'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment_rounded), label: 'الطلبات'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet_rounded), label: 'المحفظة'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), activeIcon: Icon(Icons.local_offer_rounded), label: 'العروض'),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
        ],
      ),
    );
  }
}