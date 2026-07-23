import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslLocationSelectionScreen.dart';

class WaslOrderDetailsFormScreen extends StatefulWidget {
  final String category;
  const WaslOrderDetailsFormScreen({Key? key, required this.category}) : super(key: key);

  @override
  State<WaslOrderDetailsFormScreen> createState() => _WaslOrderDetailsFormScreenState();
}

class _WaslOrderDetailsFormScreenState extends State<WaslOrderDetailsFormScreen> {
  final _storeNameController = TextEditingController();
  final _itemsDescriptionController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _itemsPriceController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isAutoDetecting = false; // 👈 متغير حالة اللودينج الخاص بالزرار

  @override
  void dispose() {
    _storeNameController.dispose();
    _itemsDescriptionController.dispose();
    _deliveryAddressController.dispose();
    _itemsPriceController.dispose();
    super.dispose();
  }

  // 🛰️ دالة سحب الموقع التلقائي عند الضغط على الزرار
  Future<void> _detectLocationAutomatically() async {
    setState(() => _isAutoDetecting = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];

      String fullAddress = "${place.street ?? ''}، ${place.subLocality ?? ''}، ${place.locality ?? ''}";

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _deliveryAddressController.text = fullAddress;
        _isAutoDetecting = false;
      });
    } catch (e) {
      debugPrint('💥 Error: $e');
      setState(() => _isAutoDetecting = false);
      _showTopSnackBar(context, 'تعذر الوصول لموقعك، يرجى تفعيل الـ GPS');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
          backgroundColor: AppColors.white, elevation: 0,
          title: Text('تفاصيل طلب ${widget.category}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          centerTitle: true
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // حقل العنوان مع زرار التحديد التلقائي
                      const Text('📍 عنوان التوصيل', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _deliveryAddressController,
                        decoration: _inputDecoration('مثال: شارع الجمهورية، عمارة 4...').copyWith(
                          suffixIcon: IconButton(
                            icon: _isAutoDetecting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, color: AppColors.primary),
                            onPressed: _detectLocationAutomatically,
                            tooltip: 'سحب موقعي الحالي',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // السعر التقديري
                      const Text('💰 السعر التقديري للمشتريات (ج.م)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 10),
                      TextField(controller: _itemsPriceController, keyboardType: TextInputType.number, decoration: _inputDecoration('مثال: 150')),
                      const SizedBox(height: 20),

                      // اسم المحل
                      const Text('🏪 اسم المحل (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 10),
                      TextField(controller: _storeNameController, decoration: _inputDecoration('مثال: صيدلية العزبي...')),
                      const SizedBox(height: 20),

                      // وصف الطلبات
                      const Text('📝 ماذا تريد؟ (الطلبات والكميات)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 10),
                      TextField(controller: _itemsDescriptionController, maxLines: 4, decoration: _inputDecoration('أريد: 2 لتر لبن، 1 كيلو أرز...')),
                    ],
                  ),
                ),
              ),

              // زر المتابعة
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: GestureDetector(
                  onTap: () {
                    if (_deliveryAddressController.text.trim().isEmpty) {
                      _showTopSnackBar(context, 'برجاء تحديد عنوان التوصيل 📍');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WaslLocationSelectionScreen(
                          category: widget.category,
                          storeName: _storeNameController.text.trim(),
                          items: _itemsDescriptionController.text.trim(),
                          address: _deliveryAddressController.text.trim(),
                          itemsPrice: double.tryParse(_itemsPriceController.text.trim()) ?? 0,
                          latitude: _latitude ?? 30.463284,
                          longitude: _longitude ?? 30.702954,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('التالي: تحديد موقع الشراء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      fillColor: AppColors.background,
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  void _showTopSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger));
  }
}
















// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:record/record.dart';
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/customer_screen/order_anywhere/WaslLocationSelectionScreen.dart';
//
// class WaslOrderDetailsFormScreen extends StatefulWidget {
//   final String category;
//   const WaslOrderDetailsFormScreen({Key? key, required this.category}) : super(key: key);
//
//   @override
//   State<WaslOrderDetailsFormScreen> createState() => _WaslOrderDetailsFormScreenState();
// }
//
// class _WaslOrderDetailsFormScreenState extends State<WaslOrderDetailsFormScreen> {
//   final _storeNameController = TextEditingController();
//   final _itemsDescriptionController = TextEditingController();
//   final _deliveryAddressController = TextEditingController();
//   final _itemsPriceController = TextEditingController();
//
//   double? _latitude;
//   double? _longitude;
//   bool _isAutoDetecting = false;
//
//   // الميديا الجديدة
//   File? _selectedImage;
//   String? _voiceNotePath;
//   final AudioRecorder _audioRecorder = AudioRecorder();
//
//   @override
//   void dispose() {
//     _storeNameController.dispose();
//     _itemsDescriptionController.dispose();
//     _deliveryAddressController.dispose();
//     _itemsPriceController.dispose();
//     _audioRecorder.dispose();
//     super.dispose();
//   }
//
//   Future<void> _pickImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(source: ImageSource.gallery);
//     if (image != null) setState(() => _selectedImage = File(image.path));
//   }
//
//   Future<void> _startRecording() async {
//     if (await _audioRecorder.hasPermission()) {
//       _showTopSnackBar(context, 'جارٍ تسجيل الصوت...');
//       // قم بتحديد مسار الحفظ وابدأ التسجيل هنا
//     }
//   }
//
//   Future<void> _detectLocationAutomatically() async {
//     setState(() => _isAutoDetecting = true);
//     try {
//       Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//       List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
//       Placemark place = placemarks[0];
//       String fullAddress = "${place.street ?? ''}، ${place.subLocality ?? ''}، ${place.locality ?? ''}";
//
//       setState(() {
//         _latitude = position.latitude;
//         _longitude = position.longitude;
//         _deliveryAddressController.text = fullAddress;
//         _isAutoDetecting = false;
//       });
//     } catch (e) {
//       setState(() => _isAutoDetecting = false);
//       _showTopSnackBar(context, 'تعذر الوصول لموقعك، يرجى تفعيل الـ GPS');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: AppBar(
//           backgroundColor: AppColors.white, elevation: 0,
//           title: Text('تفاصيل طلب ${widget.category}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//           centerTitle: true
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(24.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text('📍 عنوان التوصيل', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                       const SizedBox(height: 10),
//                       TextField(
//                         controller: _deliveryAddressController,
//                         decoration: _inputDecoration('مثال: شارع الجمهورية، عمارة 4...').copyWith(
//                           suffixIcon: IconButton(
//                             icon: _isAutoDetecting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location, color: AppColors.primary),
//                             onPressed: _detectLocationAutomatically,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       const Text('💰 السعر التقديري (ج.م)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                       const SizedBox(height: 10),
//                       TextField(controller: _itemsPriceController, keyboardType: TextInputType.number, decoration: _inputDecoration('مثال: 150')),
//                       const SizedBox(height: 20),
//
//                       // قسم الميديا الجديد
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 8),
//                         decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
//                         child: Row(
//                           children: [
//                             IconButton(icon: Icon(_selectedImage == null ? Icons.camera_alt : Icons.check_circle, color: AppColors.primary), onPressed: _pickImage),
//                             const Text("صورة للطلب", style: TextStyle(fontFamily: 'Cairo')),
//                             const Spacer(),
//                             IconButton(icon: const Icon(Icons.mic, color: AppColors.primary), onPressed: _startRecording),
//                             const Text("رسالة صوتية", style: TextStyle(fontFamily: 'Cairo')),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       const Text('📝 ماذا تريد؟', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                       const SizedBox(height: 10),
//                       TextField(controller: _itemsDescriptionController, maxLines: 4, decoration: _inputDecoration('أريد: 2 لتر لبن، 1 كيلو أرز...')),
//                     ],
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(24.0),
//                 child: GestureDetector(
//                   onTap: () {
//                     // هنا يتم التمرير للـ WaslLocationSelectionScreen مع إضافة الصور والصوت
//                     Navigator.push(context, MaterialPageRoute(builder: (_) => WaslLocationSelectionScreen(
//                       category: widget.category,
//                       storeName: _storeNameController.text.trim(),
//                       items: _itemsDescriptionController.text.trim(),
//                       address: _deliveryAddressController.text.trim(),
//                       itemsPrice: double.tryParse(_itemsPriceController.text.trim()) ?? 0,
//                       latitude: _latitude ?? 30.463284,
//                       longitude: _longitude ?? 30.702954,
//                       // أضف هنا المتغيرات الجديدة: imageFile: _selectedImage, voicePath: _voiceNotePath
//                     )));
//                   },
//                   child: Container(
//                     height: 56,
//                     decoration: BoxDecoration(gradient: AppColors.logoGradient, borderRadius: BorderRadius.circular(16)),
//                     child: const Center(child: Text('التالي: تحديد موقع الشراء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
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
//   InputDecoration _inputDecoration(String hint) {
//     return InputDecoration(hintText: hint, fillColor: AppColors.background, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16));
//   }
//
//   void _showTopSnackBar(BuildContext context, String message) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating));
//   }
// }