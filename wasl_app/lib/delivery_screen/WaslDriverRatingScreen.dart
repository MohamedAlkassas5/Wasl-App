// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:wasl_app/core/theme/app_colors.dart';
//
// class WaslDriverRatingScreen extends StatefulWidget {
//   final Map<String, dynamic> orderData;
//
//   const WaslDriverRatingScreen({Key? key, required this.orderData}) : super(key: key);
//
//   @override
//   State<WaslDriverRatingScreen> createState() => _WaslDriverRatingScreenState();
// }
//
// class _WaslDriverRatingScreenState extends State<WaslDriverRatingScreen> {
//   int _selectedRating = 5;
//   bool _isSubmitting = false;
//
//   // 🎯 إرسال التقييم الفعلي للسيرفر لايف
//   Future<void> _submitRating() async {
//     final int driverId = widget.orderData['acceptedDriverId'] ?? 21;
//     final url = Uri.parse('http://10.0.2.2:3000/orders/driver/$driverId/rate');
//
//     setState(() => _isSubmitting = true);
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'rating': _selectedRating}),
//       );
//
//       if (response.statusCode == 201 && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('شكراً لتقييمك! تم تحديث تقييم الكابتن بنجاح 🌟', style: TextStyle(fontFamily: 'Cairo')),
//             backgroundColor: Color(0xFF22C55E),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//         Navigator.of(context).popUntil((route) => route.isFirst);
//       }
//     } catch (e) {
//       debugPrint('💥 [SUBMIT RATING ERROR]: $e');
//     }
//     if (mounted) setState(() => _isSubmitting = false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const Text(
//                   'قيم تجربتك مع الكابتن ⭐',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
//                 ),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'رأيك يساعدنا في تحسين جودة خدمات فلاش الموحدة',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
//                 ),
//                 const SizedBox(height: 32),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: List.generate(5, (index) {
//                     return IconButton(
//                       icon: Icon(
//                         index < _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
//                         color: Colors.amber,
//                         size: 44,
//                       ),
//                       onPressed: () {
//                         setState(() {
//                           _selectedRating = index + 1;
//                         });
//                       },
//                     );
//                   }),
//                 ),
//                 const SizedBox(height: 40),
//                 ElevatedButton(
//                   onPressed: _isSubmitting ? null : _submitRating,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primary,
//                     minimumSize: const Size.fromHeight(54),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                   ),
//                   child: _isSubmitting
//                       ? const CircularProgressIndicator(color: Colors.white)
//                       : const Text(
//                     'إنهاء وإرسال التقييم 🏁',
//                     style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslDriverRatingScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const WaslDriverRatingScreen({Key? key, required this.orderData}) : super(key: key);

  @override
  State<WaslDriverRatingScreen> createState() => _WaslDriverRatingScreenState();
}

class _WaslDriverRatingScreenState extends State<WaslDriverRatingScreen> {
  int _selectedRating = 5;
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    final driver = widget.orderData['acceptedDriver'] ?? {};
    final int driverId = driver['id'] ?? 21;

    setState(() => _isSubmitting = true);

    final result = await FlutterOrdersService().rateDriver(
      driverId: driverId,
      rating: _selectedRating,
    );

    if (result['success'] == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.orderData['acceptedDriver'] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                // صورة الكابتن (لإضفاء طابع شخصي)
                const CircleAvatar(radius: 50, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 60, color: Colors.white)),
                const SizedBox(height: 20),
                Text('كيف كانت رحلتك مع ${driver['fullName'] ?? 'الكابتن'}؟',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),

                // النجوم مع أنيميشن بسيط
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(index < _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber, size: 50),
                    onPressed: () => setState(() => _selectedRating = index + 1),
                  );
                })),

                const SizedBox(height: 40),
                // زر الإرسال
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال التقييم', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(height: 20),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('تخطي')),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}