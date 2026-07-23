import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/providers/user_provider.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslOrderSuccessScreen.dart';

class WaslOrderSummaryScreen extends StatelessWidget {
  final String category;
  final String storeName;
  final dynamic items;
  final String address;
  final String customerAddress;
  final double itemsPrice;
  final double latitude;
  final double longitude;

  final FlutterOrdersService _ordersService = FlutterOrdersService();

  WaslOrderSummaryScreen({
    Key? key,
    required this.category,
    required this.storeName,
    required this.items,
    required this.address,
    required this.customerAddress,
    required this.itemsPrice,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  Future<void> _submitOrderToMarketplace(BuildContext context) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary))
    );

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final result = await _ordersService.createOrder(
      customerId: userProvider.userId ?? 0,
      customerName: userProvider.userName ?? 'عميل وصل',
      customerPhone: userProvider.userPhone ?? '01000000000',
      categoryType: category,
      storeName: storeName.isEmpty ? 'غير محدد' : storeName,
      itemsDescription: items.toString(),
      itemsPrice: itemsPrice,
      deliveryAddressText: customerAddress,
      latitude: latitude,
      longitude: longitude,
    );

    if (!context.mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslOrderSuccessScreen(orderId: result['data']['id'].toString())));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'فشل'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // لون الخلفية الموحد
      appBar: AppBar(
        title: const Text('مراجعة الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection('تفاصيل الطلب 📦', [
                  _buildRow('التصنيف:', category),
                  _buildRow('موقع الشراء:', storeName.isEmpty ? 'أقرب مكان' : storeName),
                  _buildRow('الطلبات:', items.toString(), isLarge: true),
                ]),
                const SizedBox(height: 16),
                _buildSection('معلومات التوصيل 📍', [
                  _buildRow('العنوان:', customerAddress, isLarge: true),
                ]),
                const SizedBox(height: 16),
                _buildPriceSection(),
              ],
            ),
          ),
          _buildSubmitButton(context),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', color: AppColors.primary)),
      const Divider(height: 25, color: Color(0xFFF1F5F9)),
      ...children,
    ]),
  );

  Widget _buildRow(String label, String value, {bool isLarge = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
      const SizedBox(width: 10),
      Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary))),
    ]),
  );

  Widget _buildPriceSection() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('إجمالي قيمة المنتجات:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
      Text(itemsPrice > 0 ? '$itemsPrice ج.م' : 'لم يحدد', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18, fontFamily: 'Cairo')),
    ]),
  );

  Widget _buildSubmitButton(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: GestureDetector(
      onTap: () => _submitOrderToMarketplace(context),
      child: Container(
        height: 55,
        decoration: BoxDecoration(
            gradient: AppColors.logoGradient, // التدرج اللوني الخاص بـ وصل
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: const Center(
          child: Text('تأكيد ونشر الطلب 🚀', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        ),
      ),
    ),
  );
}





// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/core/providers/user_provider.dart';
// import 'package:wasl_app/services/orders_service.dart';
// import 'package:wasl_app/customer_screen/cart_orders/WaslOrderSuccessScreen.dart';
//
// class WaslOrderSummaryScreen extends StatelessWidget {
//   final String category;
//   final String storeName;
//   final dynamic items;
//   final String address;
//   final String customerAddress;
//   final double itemsPrice;
//   final double latitude;
//   final double longitude;
//
//   final FlutterOrdersService _ordersService = FlutterOrdersService();
//
//   WaslOrderSummaryScreen({
//     Key? key,
//     required this.category,
//     required this.storeName,
//     required this.items,
//     required this.address,
//     required this.customerAddress,
//     required this.itemsPrice,
//     required this.latitude,
//     required this.longitude,
//   }) : super(key: key);
//
//   Future<void> _submitOrderToMarketplace(BuildContext context) async {
//     showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary))
//     );
//
//     // 🔍 أضفنا الـ Print للتأكد من القيمة قبل الإرسال
//     debugPrint("💰 القيمة التي سيرسلها الموبايل للسيرفر هي: $itemsPrice");
//
//     final userProvider = Provider.of<UserProvider>(context, listen: false);
//
//     // تأكد من تحويل السعر لرقم صريح قبل الإرسال
//     final double finalPrice = itemsPrice.toDouble();
//
//     final result = await _ordersService.createOrder(
//       customerId: userProvider.userId ?? 0,
//       customerName: userProvider.userName ?? 'عميل وصل',
//       customerPhone: userProvider.userPhone ?? '01000000000',
//       categoryType: category,
//       storeName: storeName.isEmpty ? 'غير محدد' : storeName,
//       itemsDescription: items.toString(),
//       itemsPrice: finalPrice, // 👈 إرسال القيمة الصريحة
//       deliveryAddressText: customerAddress,
//       latitude: latitude,
//       longitude: longitude,
//     );
//
//     if (!context.mounted) return;
//     Navigator.pop(context);
//
//     if (result['success'] == true) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslOrderSuccessScreen(orderId: result['data']['id'].toString())));
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'فشل'), backgroundColor: AppColors.danger));
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         title: const Text('مراجعة الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         iconTheme: const IconThemeData(color: AppColors.textPrimary),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.all(20),
//               children: [
//                 _buildSection('تفاصيل الطلب 📦', [
//                   _buildRow('التصنيف:', category),
//                   _buildRow('موقع الشراء:', storeName.isEmpty ? 'أقرب مكان' : storeName),
//                   _buildRow('الطلبات:', items.toString(), isLarge: true),
//                 ]),
//                 const SizedBox(height: 16),
//                 _buildSection('معلومات التوصيل 📍', [
//                   _buildRow('العنوان:', customerAddress, isLarge: true),
//                 ]),
//                 const SizedBox(height: 16),
//                 _buildPriceSection(),
//               ],
//             ),
//           ),
//           _buildSubmitButton(context),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSection(String title, List<Widget> children) => Container(
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
//     ),
//     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', color: AppColors.primary)),
//       const Divider(height: 25, color: Color(0xFFF1F5F9)),
//       ...children,
//     ]),
//   );
//
//   Widget _buildRow(String label, String value, {bool isLarge = false}) => Padding(
//     padding: const EdgeInsets.only(bottom: 12),
//     child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Text(label, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
//       const SizedBox(width: 10),
//       Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary))),
//     ]),
//   );
//
//   Widget _buildPriceSection() => Container(
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
//     child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//       const Text('إجمالي قيمة المنتجات:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary)),
//       Text(itemsPrice > 0 ? '$itemsPrice ج.م' : 'لم يحدد', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18, fontFamily: 'Cairo')),
//     ]),
//   );
//
//   Widget _buildSubmitButton(BuildContext context) => Padding(
//     padding: const EdgeInsets.all(20),
//     child: GestureDetector(
//       onTap: () => _submitOrderToMarketplace(context),
//       child: Container(
//         height: 55,
//         decoration: BoxDecoration(
//             gradient: AppColors.logoGradient,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
//         ),
//         child: const Center(
//           child: Text('تأكيد ونشر الطلب 🚀', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
//         ),
//       ),
//     ),
//   );
// }