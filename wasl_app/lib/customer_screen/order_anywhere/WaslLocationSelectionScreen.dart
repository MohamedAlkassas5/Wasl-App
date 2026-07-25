// // import 'package:flutter/material.dart';
// // // 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
// // import 'package:wasl_app/core/theme/app_colors.dart';
// // // 🎯 تأكد من استيراد شاشة ملخص الطلب والـ Voice Note (الصفحة 4 و 5 اللاحقة في الـ Flow) لتوجيه المستخدم إليها
// // import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderSummaryScreen.dart';
// //
// // class WaslLocationSelectionScreen extends StatefulWidget {
// //   final String category;
// //   final String storeName;
// //   final String items;
// //
// //   const WaslLocationSelectionScreen({
// //     Key? key,
// //     required this.category,
// //     required this.storeName,
// //     required this.items,
// //   }) : super(key: key);
// //
// //   @override
// //   State<WaslLocationSelectionScreen> createState() => _WaslLocationSelectionScreenState();
// // }
// //
// // class _WaslLocationSelectionScreenState extends State<WaslLocationSelectionScreen> {
// //   final _mapsLinkController = TextEditingController();
// //   final _manualAddressController = TextEditingController();
// //   String _selectedLocationMethod = ''; // 'map', 'link', 'manual'
// //   String _detectedMapAddress = '';
// //
// //   @override
// //   void dispose() {
// //     _mapsLinkController.dispose();
// //     _manualAddressController.dispose();
// //     super.dispose();
// //   }
// //
// //   void _navigateToNextStep() {
// //     String finalStoreLocation = '';
// //
// //     if (_selectedLocationMethod == 'map') {
// //       finalStoreLocation = _detectedMapAddress.isNotEmpty ? _detectedMapAddress : 'موقع جرافي محدد عبر الخريطة 📍';
// //     } else if (_selectedLocationMethod == 'link') {
// //       if (_mapsLinkController.text.trim().isEmpty) {
// //         _showSnackBar('برجاء لصق رابط موقع جوجل مابس أولاً');
// //         return;
// //       }
// //       finalStoreLocation = 'رابط موقع: ${_mapsLinkController.text.trim()}';
// //     } else if (_selectedLocationMethod == 'manual') {
// //       if (_manualAddressController.text.trim().isEmpty) {
// //         _showSnackBar('برجاء كتابة العنوان بالتفصيل أولاً');
// //         return;
// //       }
// //       finalStoreLocation = _manualAddressController.text.trim();
// //     } else {
// //       _showSnackBar('برجاء اختيار طريقة واحدة لتحديد موقع الشراء');
// //       return;
// //     }
// //
// //     // الانتقال التراكمي الموحد لصفحة المراجعة النهائية (WaslOrderSummaryScreen)
// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (_) => WaslOrderSummaryScreen(
// //           category: widget.category,
// //           storeName: widget.storeName,
// //           items: widget.items,
// //           address: finalStoreLocation, // تمرير العنوان النهائي المصفى من الطرق الثلاثة
// //         ),
// //       ),
// //     );
// //   }
// //
// //   void _showSnackBar(String message) {
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(
// //         content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
// //         backgroundColor: AppColors.danger,
// //         behavior: SnackBarBehavior.floating,
// //       ),
// //     );
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: AppColors.background,
// //       appBar: AppBar(
// //         backgroundColor: AppColors.white,
// //         elevation: 0.5,
// //         leading: IconButton(
// //           icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
// //           onPressed: () => Navigator.pop(context),
// //         ),
// //         title: const Text(
// //           'موقع مكان الشراء',
// //           style: TextStyle(
// //             color: AppColors.textPrimary,
// //             fontWeight: FontWeight.bold,
// //             fontFamily: 'Cairo',
// //             fontSize: 16,
// //           ),
// //         ),
// //         centerTitle: true,
// //       ),
// //       body: Directionality(
// //         textDirection: TextDirection.rtl,
// //         child: SafeArea(
// //           child: Column(
// //             children: [
// //               Expanded(
// //                 child: SingleChildScrollView(
// //                   physics: const BouncingScrollPhysics(),
// //                   padding: const EdgeInsets.all(20.0),
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       const Text(
// //                         'اختر طريقة لتحديد مكان الشراء وكوم حمادة بالكامل تدعم الطرق الثلاثة:',
// //                         style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo', height: 1.5),
// //                       ),
// //                       const SizedBox(height: 20),
// //
// //                       // الطريقة الأولى: خريطة جوجل التفاعلية
// //                       _buildMethodContainer(
// //                         methodKey: 'map',
// //                         title: 'الطريقة 1: تحديد من الخريطة',
// //                         icon: Icons.map_outlined,
// //                         child: Column(
// //                           children: [
// //                             ElevatedButton.icon(
// //                               onPressed: () {
// //                                 setState(() {
// //                                   _selectedLocationMethod = 'map';
// //                                   _detectedMapAddress = 'شارع الجمهورية - وسط البلد - كوم حمادة';
// //                                 });
// //                               },
// //                               icon: const Icon(Icons.pin_drop_rounded, color: Colors.white),
// //                               label: const Text('📍 تحديد موقع المحل على الخريطة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
// //                               style: ElevatedButton.styleFrom(
// //                                 backgroundColor: AppColors.secondary,
// //                                 minimumSize: const Size.fromHeight(50),
// //                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                                 elevation: 0,
// //                               ),
// //                             ),
// //                             if (_detectedMapAddress.isNotEmpty) ...[
// //                               const SizedBox(height: 10),
// //                               Text('📍 الموقع المحدد: $_detectedMapAddress', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
// //                             ]
// //                           ],
// //                         ),
// //                       ),
// //                       const SizedBox(height: 14),
// //
// //                       // الطريقة الثانية: لصق رابط خرائط جوجل
// //                       _buildMethodContainer(
// //                         methodKey: 'link',
// //                         title: 'الطريقة 2: لصق رابط Google Maps',
// //                         icon: Icons.link_rounded,
// //                         child: TextField(
// //                           controller: _mapsLinkController,
// //                           onTap: () => setState(() => _selectedLocationMethod = 'link'),
// //                           style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
// //                           decoration: InputDecoration(
// //                             hintText: 'https://maps.google.com/...',
// //                             hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
// //                             fillColor: AppColors.background,
// //                             filled: true,
// //                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
// //                           ),
// //                         ),
// //                       ),
// //                       const SizedBox(height: 14),
// //
// //                       // الطريقة الثالثة: كتابة العنوان يدوياً وبدقة
// //                       _buildMethodContainer(
// //                         methodKey: 'manual',
// //                         title: 'الطريقة 3: كتابة العنوان يدوياً',
// //                         icon: Icons.edit_location_alt_outlined,
// //                         child: TextField(
// //                           controller: _manualAddressController,
// //                           onTap: () => setState(() => _selectedLocationMethod = 'manual'),
// //                           maxLines: 3,
// //                           style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
// //                           decoration: InputDecoration(
// //                             hintText: 'مثال: صيدلية العزبي - شارع الجمهورية - بجوار بنك مصر بـ كوم حمادة',
// //                             hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey, height: 1.5),
// //                             fillColor: AppColors.background,
// //                             filled: true,
// //                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //
// //               // زر المتابعة الثابت أسفل الشاشة للتأكيد والنشر
// //               Padding(
// //                 padding: const EdgeInsets.all(20.0),
// //                 child: GestureDetector(
// //                   onTap: _navigateToNextStep,
// //                   child: Container(
// //                     height: 56,
// //                     decoration: BoxDecoration(
// //                       gradient: AppColors.logoGradient,
// //                       borderRadius: BorderRadius.circular(16),
// //                       boxShadow: [
// //                         BoxShadow(
// //                           color: AppColors.primary.withOpacity(0.24),
// //                           blurRadius: 16,
// //                           offset: const Offset(0, 6),
// //                         )
// //                       ],
// //                     ),
// //                     child: Row(
// //                       mainAxisAlignment: MainAxisAlignment.center,
// //                       children: const [
// //                         Text(
// //                           'التالي: مراجعة وإرسال الطلب',
// //                           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
// //                         ),
// //                         SizedBox(width: 8),
// //                         Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildMethodContainer({required String methodKey, required String title, required IconData icon, required Widget child}) {
// //     bool isSelected = _selectedLocationMethod == methodKey;
// //     return AnimatedContainer(
// //       duration: const Duration(milliseconds: 200),
// //       padding: const EdgeInsets.all(16),
// //       decoration: BoxDecoration(
// //         color: AppColors.white,
// //         borderRadius: BorderRadius.circular(16),
// //         border: Border.all(
// //           color: isSelected ? AppColors.primary : Colors.transparent,
// //           width: 1.5,
// //         ),
// //         boxShadow: [
// //           BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
// //         ],
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Row(
// //             children: [
// //               Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 22),
// //               const SizedBox(width: 10),
// //               Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
// //               const Spacer(),
// //               Radio<String>(
// //                 value: methodKey,
// //                 groupValue: _selectedLocationMethod,
// //                 activeColor: AppColors.primary,
// //                 onChanged: (v) => setState(() => _selectedLocationMethod = v!),
// //               )
// //             ],
// //           ),
// //           const Divider(height: 20, color: Color(0xFFF1F5F9)),
// //           child,
// //         ],
// //       ),
// //     );
// //   }
// // }
//
// import 'package:flutter/material.dart';
// // 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
// import 'package:wasl_app/core/theme/app_colors.dart';
// // 🎯 تأكد من استيراد شاشة ملخص الطلب لتوجيه المستخدم إليها
// import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderSummaryScreen.dart';
//
// class WaslLocationSelectionScreen extends StatefulWidget {
//   final String category;
//   final String storeName;
//   final String items;
//   final double itemsPrice;
//   // 🛰️ الحقول اللوجستية لاستقبال مكان توصيل العميل عبر الـ Flow التراكمي
//   final String address;
//   final double latitude;
//   final double longitude;
//
//   const WaslLocationSelectionScreen({
//     Key? key,
//     required this.category,
//     required this.storeName,
//     required this.items,
//     required this.address,   // 🎯 حقن المتغيرات الجديدة إجبارياً في الـ Constructor
//     required this.latitude,
//     required this.itemsPrice,
//     required this.longitude,
//   }) : super(key: key);
//
//   @override
//   State<WaslLocationSelectionScreen> createState() => _WaslLocationSelectionScreenState();
// }
//
// class _WaslLocationSelectionScreenState extends State<WaslLocationSelectionScreen> {
//   final _mapsLinkController = TextEditingController();
//   final _manualAddressController = TextEditingController();
//   String _selectedLocationMethod = ''; // 'map', 'link', 'manual'
//   String _detectedMapAddress = '';
//
//   @override
//   void dispose() {
//     _mapsLinkController.dispose();
//     _manualAddressController.dispose();
//     super.dispose();
//   }
//
//   void _navigateToNextStep() {
//     String finalStoreLocation = '';
//
//     if (_selectedLocationMethod == 'map') {
//       finalStoreLocation = _detectedMapAddress.isNotEmpty ? _detectedMapAddress : 'موقع جغرافي محدد عبر الخريطة 📍';
//     } else if (_selectedLocationMethod == 'link') {
//       if (_mapsLinkController.text.trim().isEmpty) {
//         _showSnackBar('برجاء لصق رابط موقع جوجل مابس أولاً');
//         return;
//       }
//       finalStoreLocation = 'رابط موقع: ${_mapsLinkController.text.trim()}';
//     } else if (_selectedLocationMethod == 'manual') {
//       if (_manualAddressController.text.trim().isEmpty) {
//         _showSnackBar('برجاء كتابة العنوان بالتفصيل أولاً');
//         return;
//       }
//       finalStoreLocation = _manualAddressController.text.trim();
//     } else {
//       _showSnackBar('برجاء اختيار طريقة واحدة لتحديد موقع الشراء');
//       return;
//     }
//
//     // 🚀 الانتقال التراكمي الموحد لصفحة المراجعة مع الفصل الصريح بين مكان الشراء ومكان التوصيل
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => WaslOrderSummaryScreen(
//           category: widget.category,
//           storeName: widget.storeName,
//           items: widget.items,
//           address: finalStoreLocation,        // 🏪 مكان شراء البضاعة قادماً من الخيارات الثلاثة
//           customerAddress: widget.address,    // 👤 عنوان توصيل العميل قادماً من الشاشة الأولى
//           latitude: widget.latitude,          // 🛰️ إحداثيات الـ GPS الحية لعنوان العميل
//           longitude: widget.longitude,
//         ),
//       ),
//     );
//   }
//
//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
//         backgroundColor: AppColors.danger,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
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
//           'موقع مكان الشراء',
//           style: TextStyle(
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
//           child: Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   physics: const BouncingScrollPhysics(),
//                   padding: const EdgeInsets.all(20.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'اختر طريقة لتحديد مكان الشراء وكوم حمادة بالكامل تدعم الطرق الثلاثة:',
//                         style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo', height: 1.5),
//                       ),
//                       const SizedBox(height: 20),
//
//                       // الطريقة الأولى: خريطة جوجل التفاعلية
//                       _buildMethodContainer(
//                         methodKey: 'map',
//                         title: 'الطريقة 1: تحديد من الخريطة',
//                         icon: Icons.map_outlined,
//                         child: Column(
//                           children: [
//                             ElevatedButton.icon(
//                               onPressed: () {
//                                 setState(() {
//                                   _selectedLocationMethod = 'map';
//                                   _detectedMapAddress = 'شارع الجمهورية - وسط البلد - كوم حمادة';
//                                 });
//                               },
//                               icon: const Icon(Icons.pin_drop_rounded, color: Colors.white),
//                               label: const Text('📍 تحديد موقع المحل على الخريطة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: AppColors.secondary,
//                                 minimumSize: const Size.fromHeight(50),
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                                 elevation: 0,
//                               ),
//                             ),
//                             if (_detectedMapAddress.isNotEmpty) ...[
//                               const SizedBox(height: 10),
//                               Text('📍 الموقع المحدد: $_detectedMapAddress', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
//                             ]
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 14),
//
//                       // الطريقة الثانية: لصق رابط خرائط جوجل
//                       _buildMethodContainer(
//                         methodKey: 'link',
//                         title: 'الطريقة 2: لصق رابط Google Maps',
//                         icon: Icons.link_rounded,
//                         child: TextField(
//                           controller: _mapsLinkController,
//                           onTap: () => setState(() => _selectedLocationMethod = 'link'),
//                           style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
//                           decoration: InputDecoration(
//                             hintText: 'https://maps.google.com/...',
//                             hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
//                             fillColor: AppColors.background,
//                             filled: true,
//                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 14),
//
//                       // الطريقة الثالثة: كتابة العنوان يدوياً وبدقة
//                       _buildMethodContainer(
//                         methodKey: 'manual',
//                         title: 'الطريقة 3: كتابة العنوان يدوياً',
//                         icon: Icons.edit_location_alt_outlined,
//                         child: TextField(
//                           controller: _manualAddressController,
//                           onTap: () => setState(() => _selectedLocationMethod = 'manual'),
//                           maxLines: 3,
//                           style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
//                           decoration: InputDecoration(
//                             hintText: 'مثال: صيدلية العزبي - شارع الجمهورية - بجوار بنك مصر بـ كوم حمادة',
//                             hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey, height: 1.5),
//                             fillColor: AppColors.background,
//                             filled: true,
//                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               // زر المتابعة الثابت أسفل الشاشة للتأكيد والنشر
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: GestureDetector(
//                   onTap: _navigateToNextStep,
//                   child: Container(
//                     height: 56,
//                     decoration: BoxDecoration(
//                       gradient: AppColors.logoGradient,
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: AppColors.primary.withOpacity(0.24),
//                           blurRadius: 16,
//                           offset: const Offset(0, 6),
//                         )
//                       ],
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: const [
//                         Text(
//                           'التالي: مراجعة وإرسال الطلب',
//                           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
//                         ),
//                         SizedBox(width: 8),
//                         Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
//                       ],
//                     ),
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
//   Widget _buildMethodContainer({required String methodKey, required String title, required IconData icon, required Widget child}) {
//     bool isSelected = _selectedLocationMethod == methodKey;
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 200),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: isSelected ? AppColors.primary : Colors.transparent,
//           width: 1.5,
//         ),
//         boxShadow: [
//           BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 22),
//               const SizedBox(width: 10),
//               Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
//               const Spacer(),
//               Radio<String>(
//                 value: methodKey,
//                 groupValue: _selectedLocationMethod,
//                 activeColor: AppColors.primary,
//                 onChanged: (v) => setState(() => _selectedLocationMethod = v!),
//               )
//             ],
//           ),
//           const Divider(height: 20, color: Color(0xFFF1F5F9)),
//           child,
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderSummaryScreen.dart';

class WaslLocationSelectionScreen extends StatefulWidget {
  final String category;
  final String storeName;
  final String items;
  final double itemsPrice;
  final String address;
  final double latitude;
  final double longitude;

  const WaslLocationSelectionScreen({
    Key? key,
    required this.category,
    required this.storeName,
    required this.items,
    required this.itemsPrice,
    required this.address,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  State<WaslLocationSelectionScreen> createState() => _WaslLocationSelectionScreenState();
}

class _WaslLocationSelectionScreenState extends State<WaslLocationSelectionScreen> {
  final _mapsLinkController = TextEditingController();
  final _manualAddressController = TextEditingController();
  String _selectedLocationMethod = '';
  String _detectedMapAddress = '';

  @override
  void dispose() {
    _mapsLinkController.dispose();
    _manualAddressController.dispose();
    super.dispose();
  }

  void _navigateToNextStep() {
    String finalStoreLocation = '';

    if (_selectedLocationMethod == 'map') {
      finalStoreLocation = _detectedMapAddress.isNotEmpty ? _detectedMapAddress : 'موقع جغرافي محدد عبر الخريطة 📍';
    } else if (_selectedLocationMethod == 'link') {
      if (_mapsLinkController.text.trim().isEmpty) {
        _showSnackBar('برجاء لصق رابط موقع جوجل مابس أولاً');
        return;
      }
      finalStoreLocation = 'رابط موقع: ${_mapsLinkController.text.trim()}';
    } else if (_selectedLocationMethod == 'manual') {
      if (_manualAddressController.text.trim().isEmpty) {
        _showSnackBar('برجاء كتابة العنوان بالتفصيل أولاً');
        return;
      }
      finalStoreLocation = _manualAddressController.text.trim();
    } else {
      _showSnackBar('برجاء اختيار طريقة واحدة لتحديد موقع الشراء');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaslOrderSummaryScreen(
          category: widget.category,
          storeName: widget.storeName,
          items: widget.items,
          itemsPrice: widget.itemsPrice,
          address: finalStoreLocation,
          customerAddress: widget.address,
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('موقع مكان الشراء', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('اختر طريقة لتحديد مكان الشراء:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      _buildMethodContainer(
                        methodKey: 'map',
                        title: 'تحديد من الخريطة',
                        icon: Icons.map_outlined,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _selectedLocationMethod = 'map'),
                          icon: const Icon(Icons.pin_drop, color: Colors.white),
                          label: const Text('فتح الخريطة التفاعلية', style: TextStyle(fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, minimumSize: const Size.fromHeight(45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildMethodContainer(
                        methodKey: 'link',
                        title: 'لصق رابط Google Maps',
                        icon: Icons.link_rounded,
                        child: TextField(
                          controller: _mapsLinkController,
                          onTap: () => setState(() => _selectedLocationMethod = 'link'),
                          decoration: InputDecoration(hintText: 'http://googleusercontent.com/maps...', fillColor: AppColors.background, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildMethodContainer(
                        methodKey: 'manual',
                        title: 'كتابة العنوان يدوياً',
                        icon: Icons.edit_location_alt_outlined,
                        child: TextField(
                          controller: _manualAddressController,
                          onTap: () => setState(() => _selectedLocationMethod = 'manual'),
                          maxLines: 2,
                          decoration: InputDecoration(hintText: 'اكتب اسم المحل وعنوانه بالتفصيل...', fillColor: AppColors.background, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GestureDetector(
                  onTap: _navigateToNextStep,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('التالي: مراجعة وإرسال الطلب 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodContainer({required String methodKey, required String title, required IconData icon, required Widget child}) {
    bool isSelected = _selectedLocationMethod == methodKey;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
              const Spacer(),
              Radio<String>(value: methodKey, groupValue: _selectedLocationMethod, activeColor: AppColors.primary, onChanged: (v) => setState(() => _selectedLocationMethod = v!))
            ],
          ),
          if (isSelected) ...[const Divider(), const SizedBox(height: 10), child],
        ],
      ),
    );
  }
}