import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/widgets/wasl_area_picker.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslLocationSelectionScreen.dart';
import 'package:wasl_app/services/zones_service.dart';

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
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _zonesService = ZonesService();

  double? _latitude;
  double? _longitude;
  bool _isAutoDetecting = false; // 👈 متغير حالة اللودينج الخاص بالزرار

  /// 🚚 وصللي: من فين لفين. السعر ثابت لكل مسار وبيجي من السيرفر.
  WaslZone? _fromArea;
  WaslZone? _toArea;

  double? _routeFee;
  String? _quoteError;
  bool _isQuoting = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _itemsDescriptionController.dispose();
    _deliveryAddressController.dispose();
    _itemsPriceController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  /// Asks the server what this route costs.
  ///
  /// The app never derives the number itself — an unsupported route has to come
  /// back as a refusal, not as an invented fallback price.
  Future<void> _refreshQuote() async {
    final from = _fromArea;
    final to = _toArea;
    if (from == null || to == null) {
      setState(() {
        _routeFee = null;
        _quoteError = null;
      });
      return;
    }

    setState(() {
      _isQuoting = true;
      _quoteError = null;
      _routeFee = null;
    });

    final result = await _zonesService.getWasllyQuote(
      pickupZoneId: from.id,
      dropoffZoneId: to.id,
    );
    if (!mounted) return;

    setState(() {
      _isQuoting = false;
      if (result['success'] == true) {
        final fee = (result['data']?['deliveryFee'] as num?)?.toDouble();
        _routeFee = fee;
        _quoteError = fee == null ? 'تعذّر قراءة سعر المسار' : null;
      } else {
        _quoteError = (result['message'] ?? 'تعذّر حساب سعر المسار').toString();
      }
    });
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
                      // 🚚 من فين لفين — المسار هو اللي بيحدد السعر
                      WaslAreaPicker(
                        label: '🚚 منطقة الاستلام (من)',
                        hint: 'اختر منطقة الاستلام',
                        icon: Icons.storefront_outlined,
                        selectedZoneId: _fromArea?.id,
                        onChanged: (zone) {
                          setState(() => _fromArea = zone);
                          _refreshQuote();
                        },
                      ),
                      const SizedBox(height: 16),
                      WaslAreaPicker(
                        label: '🏁 منطقة التوصيل (إلى)',
                        hint: 'اختر منطقة التوصيل',
                        icon: Icons.flag_outlined,
                        selectedZoneId: _toArea?.id,
                        onChanged: (zone) {
                          setState(() => _toArea = zone);
                          _refreshQuote();
                        },
                      ),
                      _buildRouteFee(),
                      const SizedBox(height: 20),

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
                      const SizedBox(height: 20),

                      // 📦 المستلم — لو الشحنة رايحة لحد تاني غير صاحب الطلب.
                      const Text('👤 المستلم (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 10),
                      TextField(controller: _recipientNameController, decoration: _inputDecoration('اسم المستلم لو غيرك')),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _recipientPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration('رقم هاتف المستلم'),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6, right: 4),
                        child: Text(
                          'الرقم ده مش بيظهر لأي كابتن غير اللي هيقبل الطلب فعلاً',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // زر المتابعة
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: GestureDetector(
                  onTap: () {
                    if (_fromArea == null || _toArea == null) {
                      _showTopSnackBar(context, 'اختر منطقة الاستلام ومنطقة التوصيل 🚚');
                      return;
                    }
                    if (_routeFee == null) {
                      _showTopSnackBar(
                        context,
                        _quoteError ?? 'استنى شوية لحد ما يظهر سعر المسار',
                      );
                      return;
                    }
                    if (_deliveryAddressController.text.trim().isEmpty) {
                      _showTopSnackBar(context, 'برجاء تحديد عنوان التوصيل 📍');
                      return;
                    }
                    // 📍 الموقع لازم يكون حقيقي. النسخة القديمة كانت بتبعت
                    // إحداثيات ثابتة متكتوبة في الكود لو العميل ما حددش موقعه،
                    // يعني الكابتن كان بيتوجّه لمكان مالوش علاقة بالعميل.
                    if (_latitude == null || _longitude == null) {
                      _showTopSnackBar(context, 'دوس على أيقونة الموقع لتحديد مكانك بدقة 📍');
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
                          latitude: _latitude!,
                          longitude: _longitude!,
                          pickupZoneId: _fromArea!.id,
                          dropoffZoneId: _toArea!.id,
                          recipientName: _recipientNameController.text.trim(),
                          recipientPhone: _recipientPhoneController.text.trim(),
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

  /// Shows the server's answer for the chosen route — the price, or plainly
  /// why there isn't one. Never a placeholder number.
  Widget _buildRouteFee() {
    if (_fromArea == null || _toArea == null) return const SizedBox.shrink();

    final Color background;
    final Color foreground;
    final IconData icon;
    final String text;

    if (_isQuoting) {
      background = AppColors.background;
      foreground = AppColors.textSecondary;
      icon = Icons.hourglass_empty_rounded;
      text = 'جاري حساب سعر المسار...';
    } else if (_quoteError != null) {
      background = AppColors.danger.withOpacity(0.08);
      foreground = AppColors.danger;
      icon = Icons.error_outline_rounded;
      text = _quoteError!;
    } else {
      background = AppColors.success.withOpacity(0.08);
      foreground = AppColors.success;
      icon = Icons.local_shipping_outlined;
      text =
          'سعر التوصيل من ${_fromArea!.name} إلى ${_toArea!.name}: ${_routeFee!.toStringAsFixed(0)} ج.م';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: foreground,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
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