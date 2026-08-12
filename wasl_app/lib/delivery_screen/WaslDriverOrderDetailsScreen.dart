// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/delivery_screen/WaslSubmitBidDialog.dart';
//
// class WaslDriverOrderDetailsScreen extends StatefulWidget {
//   final Map<String, dynamic> orderData;
//
//   const WaslDriverOrderDetailsScreen({
//     Key? key,
//     required this.orderData,
//   }) : super(key: key);
//
//   @override
//   State<WaslDriverOrderDetailsScreen> createState() => _WaslDriverOrderDetailsScreenState();
// }
//
// class _WaslDriverOrderDetailsScreenState extends State<WaslDriverOrderDetailsScreen> {
//   late Map<String, dynamic> _liveOrderData;
//   Timer? _refreshTimer;
//   bool _isFirstLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _liveOrderData = widget.orderData;
//     _fetchNewestOrderDetails(); // 🎯 ضربة فورية بمجرد فتح الشاشة لجلب البيانات الحية بالملي
//
//     // 🔄 الاستماع الدوري الخفيف كل 3 ثوانٍ لو حصل أي تعديل في الرحلة
//     _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
//       _fetchNewestOrderDetails();
//     });
//   }
//
//   Future<void> _fetchNewestOrderDetails() async {
//     final String orderId = _liveOrderData['id']?.toString() ?? '';
//     if (orderId.isEmpty) return;
//
//     // 🎯 استخدام المسار المدرع والمحدث في الباك إند لفك كل تفاصيل العميل والطلب حياً
//     final url = Uri.parse('http://10.0.2.2:3000/orders/$orderId/customer-details');
//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200 && mounted) {
//         setState(() {
//           _liveOrderData = jsonDecode(response.body);
//           _isFirstLoading = false;
//         });
//         debugPrint("📡 [DRIVER DETAILS SYNC] تم سحب داتا الطلب الحية FL-$orderId بنجاح من الداتابيز.");
//       }
//     } catch (e) {
//       debugPrint('💥 [DETAILS FETCH ERROR]: $e');
//       if (mounted && _isFirstLoading) {
//         setState(() => _isFirstLoading = false);
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _refreshTimer?.cancel(); // 🛡️ حماية موارد الذاكرة
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final String safeOrderId = _liveOrderData['id']?.toString() ?? '';
//
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           'تنفيذ طلب FL-$safeOrderId 📋',
//           style: const TextStyle(
//             color: AppColors.textPrimary,
//             fontWeight: FontWeight.bold,
//             fontFamily: 'Cairo',
//             fontSize: 16,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: _isFirstLoading
//               ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
//               : Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   physics: const BouncingScrollPhysics(),
//                   padding: const EdgeInsets.all(20.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // 1️⃣ كارت الفئة والمسافة
//                       Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: AppColors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           boxShadow: [
//                             BoxShadow(
//                               color: AppColors.textPrimary.withOpacity(0.01),
//                               blurRadius: 10,
//                               offset: const Offset(0, 4),
//                             )
//                           ],
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               _liveOrderData['categoryType']?.toString() ?? 'طلب توصيل',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                                 color: AppColors.primary,
//                                 fontFamily: 'Cairo',
//                               ),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                               decoration: BoxDecoration(
//                                 color: AppColors.background,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Row(
//                                 children: [
//                                   const Icon(Icons.navigation_outlined, size: 14, color: AppColors.textSecondary),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     'يبعد عنك: ${_liveOrderData['distance'] ?? 'قريب منك'}',
//                                     textDirection: TextDirection.ltr,
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: AppColors.textSecondary,
//                                       fontFamily: 'Cairo',
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             )
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//
//                       // 2️⃣ تفاصيل مكان الشراء (المتجر الحي من العميل مباشرة)
//                       _buildDetailCard(
//                         title: 'مكان الشراء وشحن الطلب 🏪',
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               _liveOrderData['storeName']?.toString().isNotEmpty == true
//                                   ? _liveOrderData['storeName'].toString()
//                                   : 'من أقرب مكان متاح للعنوان',
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold,
//                                 color: AppColors.textPrimary,
//                                 fontFamily: 'Cairo',
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             const Text(
//                               'نطاق العمل: مركز كوم حمادة، محافظة البحيرة',
//                               style: TextStyle(
//                                   fontSize: 11,
//                                   color: AppColors.textSecondary,
//                                   fontFamily: 'Cairo'
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//
//                       // 3️⃣ تفاصيل وقائمة المشتريات المطلوبة بالملي
//                       _buildDetailCard(
//                         title: 'المنتجات والمشتريات المطلوبة من العميل 📦',
//                         child: Text(
//                           _liveOrderData['itemsDescription']?.toString().isNotEmpty == true
//                               ? _liveOrderData['itemsDescription'].toString()
//                               : 'لا توجد تفاصيل إضافية مكتوبة',
//                           style: const TextStyle(
//                             fontSize: 13,
//                             color: AppColors.textPrimary,
//                             fontFamily: 'Cairo',
//                             height: 1.5,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//
//                       // 4️⃣ وجهة توصيل العميل وعنوانه الفعلي المكتوب
//                       _buildDetailCard(
//                         title: 'وجهة توصيل العميل 📍',
//                         child: Text(
//                           _liveOrderData['deliveryAddressText']?.toString().isNotEmpty == true
//                               ? _liveOrderData['deliveryAddressText'].toString()
//                               : 'العنوان يدوي (كوم حمادة)',
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: AppColors.textPrimary,
//                             fontFamily: 'Cairo',
//                             height: 1.4,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//
//                       // 5️⃣ الحساب المالي التقديري (كاش)
//                       _buildDetailCard(
//                         title: 'الحساب المالي التقديري (كاش) 💵',
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text(
//                               'سعر المنتجات المتوقع بالمحل:',
//                               style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo'),
//                             ),
//                             Text(
//                               _liveOrderData['itemsPrice'] != null && _liveOrderData['itemsPrice'] != 0
//                                   ? '${_liveOrderData['itemsPrice']} ج.م'
//                                   : 'حسب الفاتورة ج.م',
//                               style: const TextStyle(
//                                 fontSize: 15,
//                                 fontWeight: FontWeight.bold,
//                                 color: AppColors.textPrimary,
//                                 fontFamily: 'Cairo',
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               // 6️⃣ زر تقديم العرض اللوجستي الثابت بالأسفل
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: ElevatedButton.icon(
//                   onPressed: () {
//                     final String stringOrderId = _liveOrderData['id']?.toString() ?? '0';
//
//                     showDialog(
//                       context: context,
//                       builder: (context) => WaslSubmitBidDialog(
//                         orderId: stringOrderId,
//                         onSubmit: (price, minutes) {
//                           // 🚀 ممرر وجاهز لربط دالة التقديم لاحقاً
//                         },
//                       ),
//                     );
//                   },
//                   icon: const Icon(Icons.local_offer_outlined, color: Colors.white, size: 20),
//                   label: const Text(
//                     'تقديم عرض توصيل للعميل',
//                     style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.textPrimary,
//                     minimumSize: const Size.fromHeight(54),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                     elevation: 0,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDetailCard({required String title, required Widget child}) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(
//             color: AppColors.textPrimary.withOpacity(0.01),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//               color: AppColors.textSecondary,
//               fontFamily: 'Cairo',
//             ),
//           ),
//           const SizedBox(height: 12),
//           child,
//         ],
//       ),
//     );
//   }
// }



import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/utils/phone_format.dart';
import 'package:wasl_app/delivery_screen/WaslSubmitBidDialog.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslDriverOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const WaslDriverOrderDetailsScreen({Key? key, required this.orderData}) : super(key: key);

  @override
  State<WaslDriverOrderDetailsScreen> createState() => _WaslDriverOrderDetailsScreenState();
}

class _WaslDriverOrderDetailsScreenState extends State<WaslDriverOrderDetailsScreen> {
  late Map<String, dynamic> _liveOrderData;
  Timer? _refreshTimer;
  bool _isFirstLoading = true;

  @override
  void initState() {
    super.initState();
    _liveOrderData = widget.orderData;
    _fetchNewestOrderDetails();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _fetchNewestOrderDetails());
  }

  Future<void> _fetchNewestOrderDetails() async {
    final String orderId = _liveOrderData['id']?.toString() ?? '';
    if (orderId.isEmpty) return;

    final parsedId = int.tryParse(orderId);
    if (parsedId == null) return;

    final result = await FlutterOrdersService().getOrderCustomerDetails(parsedId);
    if (result['success'] == true && mounted) {
      setState(() {
        _liveOrderData = result['data'];
        _isFirstLoading = false;
      });
    } else if (mounted && _isFirstLoading) {
      setState(() => _isFirstLoading = false);
    }
  }

  // 👤 ميثود لعرض بيانات العميل
  Widget _buildCustomerInfoCard() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade50)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.person_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          const Text('بيانات العميل', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ]),
        const Divider(),
        _buildCustomerRow('الاسم:', _liveOrderData['customerName'] ?? 'غير متوفر'),
        _buildCustomerRow('رقم الهاتف:', formatPhoneForDisplay(_liveOrderData['customerPhone'])),
      ],
    ),
  );

  Widget _buildCustomerRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontFamily: 'Cairo')),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ],
    ),
  );

  Widget _buildPriceDisplay(dynamic price) {
    if (price == null || price.toString() == "0" || price.toString() == "0.0") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: const Text('لم يحدد العميل سعر', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
      );
    }
    return Text('$price ج.م', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('تفاصيل الرحلة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ),
      body: _isFirstLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildCustomerInfoCard(), // 👤 بيانات العميل
                _buildInfoCard(Icons.storefront_rounded, 'مكان الشراء', _liveOrderData['storeName'] ?? 'أقرب محل متاح'),
                _buildInfoCard(Icons.shopping_bag_rounded, 'المنتجات المطلوبة', _liveOrderData['itemsDescription'] ?? 'لا توجد تفاصيل'),
                _buildInfoCard(Icons.location_on_rounded, 'وجهة التوصيل', _liveOrderData['deliveryAddressText'] ?? 'العنوان مكتوب يدوياً'),
                _buildPriceCard(),
              ],
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('طلب رقم FL-${_liveOrderData['id']}', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Cairo')),
          Text(_liveOrderData['categoryType'] ?? 'توصيل عام', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ]),
        const Icon(Icons.delivery_dining, color: Colors.white, size: 40),
      ],
    ),
  );

  Widget _buildInfoCard(IconData icon, String title, String content) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
    child: Row(children: [
      Icon(icon, color: AppColors.primary),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'Cairo')),
        Text(content, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
      ])),
    ]),
  );

  Widget _buildPriceCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade100)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('إجمالي قيمة المنتجات التقديري:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      _buildPriceDisplay(_liveOrderData['itemsPrice']),
    ]),
  );

  Widget _buildActionButtons() => Padding(
    padding: const EdgeInsets.all(20),
    child: ElevatedButton(
      onPressed: () => showDialog(
        context: context,
        builder: (context) => WaslSubmitBidDialog(
          orderId: _liveOrderData['id'].toString(),
          suggestedFee: double.tryParse(
              _liveOrderData['estimatedDeliveryFee']?.toString() ?? ''),
          onSubmit: (p, m) {},
        ),
      ),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.textPrimary, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: const Text('تقديم عرض توصيل الآن 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white)),
    ),
  );

  @override void dispose() { _refreshTimer?.cancel(); super.dispose(); }
}