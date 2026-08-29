// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// // 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
// import 'package:wasl_app/core/theme/app_colors.dart';
//
// class WaslOrderAnyplaceDetailsScreen extends StatefulWidget {
//   final String? selectedAddress;
//
//   const WaslOrderAnyplaceDetailsScreen({Key? key, this.selectedAddress}) : super(key: key);
//
//   @override
//   State<WaslOrderAnyplaceDetailsScreen> createState() => _WaslOrderAnyplaceDetailsScreenState();
// }
//
// class _WaslOrderAnyplaceDetailsScreenState extends State<WaslOrderAnyplaceDetailsScreen> {
//   final _formKey = GlobalKey<FormState>();
//
//   final TextEditingController _storeNameController = TextEditingController();
//   final TextEditingController _addressDetailsController = TextEditingController();
//   final TextEditingController _orderItemsController = TextEditingController();
//   final TextEditingController _voiceNoteController = TextEditingController();
//
//   File? _attachedImage;
//   final ImagePicker _picker = ImagePicker();
//   bool _isSubmitting = false;
//
//   @override
//   void dispose() {
//     _storeNameController.dispose();
//     _addressDetailsController.dispose();
//     _orderItemsController.dispose();
//     _voiceNoteController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _pickImage(ImageSource source) async {
//     try {
//       final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
//       if (pickedFile != null) {
//         setState(() => _attachedImage = File(pickedFile.path));
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('حدث خطأ أثناء اختيار الصورة', style: TextStyle(fontFamily: 'Cairo')),
//           backgroundColor: AppColors.danger,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//     }
//   }
//
//   void _showImageSourceBottomSheet() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppColors.white,
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
//       builder: (_) => Directionality(
//         textDirection: TextDirection.rtl,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 40,
//                 height: 4,
//                 margin: const EdgeInsets.only(bottom: 18),
//                 decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
//               ),
//               const Text('إرفاق صورة (روشتة، منتج، إلخ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//               const SizedBox(height: 16),
//               _buildSheetOption(Icons.camera_alt_outlined, 'استخدام الكاميرا', () {
//                 Navigator.pop(context);
//                 _pickImage(ImageSource.camera);
//               }),
//               const SizedBox(height: 10),
//               _buildSheetOption(Icons.photo_library_outlined, 'اختيار من المعرض', () {
//                 Navigator.pop(context);
//                 _pickImage(ImageSource.gallery);
//               }),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSheetOption(IconData icon, String label, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         decoration: BoxDecoration(
//           color: AppColors.background,
//           borderRadius: BorderRadius.circular(14),
//         ),
//         child: Row(
//           children: [
//             Icon(icon, color: AppColors.primary), // 🎯 الأيقونة باللون الأساسي لوصل
//             const SizedBox(width: 14),
//             Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _submitOrder() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _isSubmitting = true);
//     await Future.delayed(const Duration(milliseconds: 900));
//     if (!mounted) return;
//     setState(() => _isSubmitting = false);
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('جاري إرسال طلبك الخاص للمناديب القريبة... 🚀', style: TextStyle(fontFamily: 'Cairo')),
//         backgroundColor: AppColors.success,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background, // 🎯 لون الخلفية الموحد
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildHeader(),
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _buildLocationCard(),
//                         const SizedBox(height: 20),
//                         _buildFormCard(),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               _buildSubmitBar(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
//       child: Row(
//         children: [
//           GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: Container(
//               width: 44,
//               height: 44,
//               decoration: BoxDecoration(
//                 color: AppColors.white,
//                 borderRadius: BorderRadius.circular(14),
//                 boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
//               ),
//               child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
//             ),
//           ),
//           const SizedBox(width: 14),
//           const Text('تفاصيل الطلب الخاص', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLocationCard() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.primary.withOpacity(0.08), // 🎯 كارت الموقع بخلفية زرقاء ناعمة متناسقة مع وصل
//         borderRadius: BorderRadius.circular(18),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
//             child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('الموقع المختار على الخريطة', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                 const SizedBox(height: 4),
//                 Text(
//                   widget.selectedAddress ?? 'حي الملك فهد، الرياض، المملكة العربية السعودية',
//                   style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5, fontFamily: 'Cairo'),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFormCard() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         borderRadius: BorderRadius.circular(22),
//         boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildFieldLabel('اسم المكان / المتجر'),
//           TextFormField(
//             controller: _storeNameController,
//             textDirection: TextDirection.rtl,
//             style: const TextStyle(color: AppColors.textPrimary),
//             decoration: _buildInputDecoration('مثال: صيدلية الشفاء، سوبرماركت الأمانة...'),
//             validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال اسم المكان المراد الشراء منه' : null,
//           ),
//           const SizedBox(height: 20),
//           _buildFieldLabel('العنوان بالتفصيل الموضح للمندوب'),
//           TextFormField(
//             controller: _addressDetailsController,
//             textDirection: TextDirection.rtl,
//             maxLines: 2,
//             style: const TextStyle(color: AppColors.textPrimary),
//             decoration: _buildInputDecoration('مثال: الدور الأرضي، بجوار صرافة الراجحي، شقة رقم 3...'),
//             validator: (v) => (v == null || v.isEmpty) ? 'يرجى كتابة تفاصيل العنوان لمساعدة المندوب' : null,
//           ),
//           const SizedBox(height: 20),
//           _buildFieldLabel('ما هي الأشياء التي تحتاجها؟'),
//           TextFormField(
//             controller: _orderItemsController,
//             textDirection: TextDirection.rtl,
//             maxLines: 4,
//             style: const TextStyle(color: AppColors.textPrimary),
//             decoration: _buildInputDecoration('اكتب طلباتك بالتفصيل هنا (مثال: علبة دواء بنادول اكسترا، 2 لتر حليب...)'),
//             validator: (v) => (v == null || v.isEmpty) ? 'يرجى كتابة الطلبات المراد إحضارها' : null,
//           ),
//           const SizedBox(height: 20),
//           _buildFieldLabel('ملاحظات صوتية أو إضافية (اختياري)'),
//           TextFormField(
//             controller: _voiceNoteController,
//             textDirection: TextDirection.rtl,
//             style: const TextStyle(color: AppColors.textPrimary),
//             decoration: _buildInputDecoration('أي تفاصيل إضافية تساعد المندوب'),
//           ),
//           const SizedBox(height: 24),
//           const Text('هل تود إرفاق صورة؟ (اختياري)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//           const SizedBox(height: 10),
//           _attachedImage == null
//               ? OutlinedButton.icon(
//             onPressed: _showImageSourceBottomSheet,
//             icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
//             label: const Text('إرفاق صورة / روشتة طبية', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//             style: OutlinedButton.styleFrom(
//               minimumSize: const Size.fromHeight(54),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//               side: const BorderSide(color: AppColors.primary, width: 1.2),
//             ),
//           )
//               : Stack(
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(16),
//                 child: Image.file(_attachedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
//               ),
//               Positioned(
//                 top: 8,
//                 left: 8,
//                 child: GestureDetector(
//                   onTap: () => setState(() => _attachedImage = null),
//                   child: Container(
//                     width: 36,
//                     height: 36,
//                     decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
//                     child: const Icon(Icons.delete_outline, color: AppColors.white, size: 18),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFieldLabel(String text) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8.0),
//       child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//     );
//   }
//
//   InputDecoration _buildInputDecoration(String hint) {
//     return InputDecoration(
//       hintText: hint,
//       hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo'),
//       fillColor: AppColors.background,
//       filled: true,
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
//       errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.danger)),
//       focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
//       focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.secondary, width: 1.2)),
//       contentPadding: const EdgeInsets.all(16),
//     );
//   }
//
//   Widget _buildSubmitBar() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//       decoration: BoxDecoration(
//         color: AppColors.white,
//         boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -4))],
//       ),
//       child: GestureDetector(
//         onTap: _isSubmitting ? null : _submitOrder,
//         child: Container(
//           height: 56,
//           decoration: BoxDecoration(
//             gradient: _isSubmitting ? null : AppColors.logoGradient, // 🎯 تفعيل التدرج اللوني الفخم للزر الرئيسي
//             color: _isSubmitting ? Colors.grey.shade300 : null,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: _isSubmitting ? null : [
//               BoxShadow(
//                 color: AppColors.primary.withOpacity(0.24),
//                 blurRadius: 16,
//                 offset: const Offset(0, 6),
//               )
//             ],
//           ),
//           child: Center(
//             child: _isSubmitting
//                 ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5))
//                 : const Text('تأكيد وإرسال الطلب', style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//           ),
//         ),
//       ),
//     );
//   }
// }




import 'dart:io';
import 'package:wasl_app/core/ui/wasl_submit_guard.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/services/location_service.dart';

class WaslOrderAnyplaceDetailsScreen extends StatefulWidget {
  final String? selectedAddress;
  // 📍 Exact delivery coordinates picked on the map (real, never hardcoded).
  final double? selectedLatitude;
  final double? selectedLongitude;

  const WaslOrderAnyplaceDetailsScreen({
    Key? key,
    this.selectedAddress,
    this.selectedLatitude,
    this.selectedLongitude,
  }) : super(key: key);

  @override
  State<WaslOrderAnyplaceDetailsScreen> createState() => _WaslOrderAnyplaceDetailsScreenState();
}

class _WaslOrderAnyplaceDetailsScreenState
    extends State<WaslOrderAnyplaceDetailsScreen>
    with WaslSubmitGuard<WaslOrderAnyplaceDetailsScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _addressDetailsController = TextEditingController();
  final TextEditingController _orderItemsController = TextEditingController();
  final TextEditingController _voiceNoteController = TextEditingController();

  File? _attachedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // 📍 Real delivery coordinates: prefer the map-picked point, else live GPS.
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.selectedLatitude;
    _lng = widget.selectedLongitude;
    // If the map didn't supply a point, resolve the device GPS once.
    if (_lat == null || _lng == null) {
      _resolveCurrentLocation();
    }
  }

  Future<void> _resolveCurrentLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressDetailsController.dispose();
    _orderItemsController.dispose();
    _voiceNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() => _attachedImage = File(pickedFile.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('حدث خطأ أثناء اختيار الصورة', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
              const Text('إرفاق صورة (روشتة، منتج، إلخ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
              const SizedBox(height: 16),
              _buildSheetOption(Icons.camera_alt_outlined, 'استخدام الكاميرا', () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              }),
              const SizedBox(height: 10),
              _buildSheetOption(Icons.photo_library_outlined, 'اختيار من المعرض', () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOrder() => guardedSubmit(_createOrderWithImage);

  Future<void> _createOrderWithImage() async {
    if (!_formKey.currentState!.validate()) return;

    // 📍 A real delivery location is mandatory — no hardcoded fallback.
    // Try one more GPS resolve if we still don't have a point.
    if (_lat == null || _lng == null) {
      await _resolveCurrentLocation();
    }
    if (_lat == null || _lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'يرجى تحديد موقع التوصيل على الخريطة أو تفعيل خدمة الموقع أولاً 📍',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final String customerName = prefs.getString('user_name') ?? 'عميل وصل';
      final String customerPhone = prefs.getString('user_phone') ?? '';
      final int customerId = prefs.getInt('user_id') ?? 0;

      final result = await _ordersService.createOrderWithImage(
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        categoryType: 'طلب خاص',
        storeName: _storeNameController.text.trim(),
        itemsDescription: _orderItemsController.text.trim(),
        deliveryAddressText: _addressDetailsController.text.trim(),
        latitude: _lat!,
        longitude: _lng!,
        itemsImage: _attachedImage,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إرسال طلبك بنجاح وجاري المزايدة الآن! 🚀', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'فشل إرسال الطلب', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('💥 [CREATE ORDER ERROR]: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('عفواً، حدث عطل أثناء معالجة الطلب ⚠️', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLocationCard(),
                        const SizedBox(height: 20),
                        _buildFormCard(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSubmitBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          const Text('تفاصيل الطلب الخاص', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الموقع المختار على الخريطة', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                Text(
                  widget.selectedAddress ??
                      (_lat != null && _lng != null
                          ? 'موقعك الحالي (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})'
                          : 'جاري تحديد موقعك...'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5, fontFamily: 'Cairo'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        // 🎯 [تم الإصلاح]: المحاذاة الصحيحة دون typos
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('اسم المكان / المتجر'),
          TextFormField(
            controller: _storeNameController,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _buildInputDecoration('مثال: صيدلية الشفاء، سوبرماركت الأمانة...'),
            validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال اسم المكان المراد الشراء منه' : null,
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('العنوان بالتفصيل الموضح للمندوب (يدوياً)'),
          TextFormField(
            controller: _addressDetailsController,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _buildInputDecoration('مثال: الدور الأرضي، بجوار صرافة الراجحي، شقة رقم 3...'),
            validator: (v) => (v == null || v.isEmpty) ? 'يرجى كتابة تفاصيل العنوان لمساعدة المندوب' : null,
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('ما هي الأشياء التي تحتاجها؟'),
          TextFormField(
            controller: _orderItemsController,
            textDirection: TextDirection.rtl,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _buildInputDecoration('اكتب طلباتك بالتفصيل هنا (مثال: علبة دواء بنادول اكسترا، 2 لتر حليب...)'),
            validator: (v) => (v == null || v.isEmpty) ? 'يرجى كتابة الطلبات المراد إحضارها' : null,
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('ملاحظات صوتية أو إضافية (اختياري)'),
          TextFormField(
            controller: _voiceNoteController,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _buildInputDecoration('أي تفاصيل إضافية تساعد المندوب'),
          ),
          const SizedBox(height: 24),
          const Text('هل تود إرفاق صورة؟ (اختياري)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 10),
          _attachedImage == null
              ? OutlinedButton.icon(
            onPressed: _showImageSourceBottomSheet,
            icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
            label: const Text('إرفاق صورة / روشتة طبية', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.primary, width: 1.2),
            ),
          )
              : Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_attachedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _attachedImage = null),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline, color: AppColors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo'),
      fillColor: AppColors.background,
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.secondary, width: 1.2)),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: GestureDetector(
        onTap: _isSubmitting ? null : _submitOrder,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: _isSubmitting ? null : AppColors.logoGradient,
            color: _isSubmitting ? Colors.grey.shade300 : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isSubmitting ? null : [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.24),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5))
                : const Text('تأكيد وإرسال الطلب', style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ),
      ),
    );
  }
}