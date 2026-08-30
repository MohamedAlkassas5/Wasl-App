// import 'dart:async'; // 🎯 مستدعى ومفعل للـ Polling المستمر
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:wasl_app/core/theme/app_colors.dart';
// // 🎯 استيراد شاشة الفاتورة الجديدة لضمان سلامة التنقل اللوجستي
// import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderInvoiceScreen.dart';
//
// class WaslOrderTrackingScreen extends StatefulWidget {
//   final Map<String, dynamic> orderData;
//
//   const WaslOrderTrackingScreen({
//     Key? key,
//     required this.orderData,
//   }) : super(key: key);
//
//   @override
//   State<WaslOrderTrackingScreen> createState() => _WaslOrderTrackingScreenState();
// }
//
// class _WaslOrderTrackingScreenState extends State<WaslOrderTrackingScreen> {
//   late Map<String, dynamic> _liveOrder;
//   Timer? _pollingTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     _liveOrder = widget.orderData;
//     _startLiveTracking(); // 🎯 تشغيل التتبع الدوري اللحظي فور الدخول للشاشة
//   }
//
//   // 📡 المزامنة الحية والشاملة لتحديث الحالات وبيانات الكابتن والانتقال للفاتورة تلقائياً
//   void _startLiveTracking() {
//     _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
//       final String orderId = _liveOrder['id']?.toString() ?? '';
//       if (orderId.isEmpty) return;
//
//       final url = Uri.parse('http://10.0.2.2:3000/orders/$orderId/customer-details');
//       try {
//         final response = await http.get(url);
//         if (response.statusCode == 200 && mounted) {
//           final Map<String, dynamic> newData = jsonDecode(response.body);
//
//           setState(() {
//             _liveOrder = newData; // تحديث كائن الطلب الشامل لايف بكل تفاصيله
//           });
//
//           debugPrint("📡 [TRACKING SYNC SUCCESS] الحالة المزامنة حالياً: ${newData['status']}");
//
//           // 🎯 [الحركة الذكية والـ Live]: إذا اكتمل الطلب، الغي التايمر وانقله فوراً لصفحة الفاتورة دون تدخل منه
//           if (newData['status']?.toString().toLowerCase() == 'completed') {
//             _pollingTimer?.cancel(); // إيقاف الاستماع لحفظ موارد البطارية والجهاز
//
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => WaslOrderInvoiceScreen(orderData: newData),
//               ),
//             );
//           }
//         }
//       } catch (e) {
//         debugPrint('💥 [TRACKING POLLING ERROR]: $e');
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _pollingTimer?.cancel(); // 🛡️ إلغاء التايمر فور الخروج كخطوة حماية إضافية
//     super.dispose();
//   }
//
//   // 🎯 xريطة مطابقة الحالات بدقة تامة مع الـ Backend
//   int _mapStatusToStep(String? status) {
//     final String currentStatus = status?.toLowerCase().trim() ?? 'pending_offers';
//     if (currentStatus == 'accepted') return 0;
//     if (currentStatus == 'at_store') return 1;
//     if (currentStatus == 'items_bought' || currentStatus == 'delivering') return 2;
//     if (currentStatus == 'completed') return 3;
//     return 0;
//   }
//
//   void _makePhoneCall(String phone) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('جاري الاتصال بالكابتن: $phone 📞', style: const TextStyle(fontFamily: 'Cairo')),
//         backgroundColor: AppColors.primary,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final order = _liveOrder;
//
//     final int currentStep = _mapStatusToStep(order['status']);
//     final String safeOrderId = order['id']?.toString() ?? '';
//     final String storeName = order['storeName']?.toString() ?? 'من أقرب مكان متاح';
//
//     final Map<String, dynamic>? driverData = order['acceptedDriver'];
//     final String driverName = driverData?['fullName'] ?? driverData?['name'] ?? 'جاري تعيين الكابتن...';
//     final String driverPhone = driverData?['phone'] ?? driverData?['phoneNumber'] ?? 'لا يوجد رقم هاتف حالياً';
//
//     final dynamic rawFinalFee = order['finalDeliveryFee'];
//     final dynamic rawFee = order['deliveryFee'];
//     final double agreedFee = rawFinalFee != null
//         ? (rawFinalFee is num ? rawFinalFee.toDouble() : double.tryParse(rawFinalFee.toString()) ?? 25.0)
//         : (rawFee != null ? (rawFee is num ? rawFee.toDouble() : double.tryParse(rawFee.toString()) ?? 25.0) : 25.0);
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
//           'تتبع الطلب FL-$safeOrderId',
//           style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
//         ),
//         centerTitle: true,
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: Column(
//             children: [
//               // 1️⃣ لوحة الخريطة التوضيحية
//               Container(
//                 height: 180,
//                 color: const Color(0xFFE2E8F0),
//                 child: Stack(
//                   children: [
//                     const Center(child: Icon(Icons.map_outlined, size: 64, color: Color(0xFF94A3B8))),
//                     Positioned(
//                       bottom: 16,
//                       right: 16,
//                       left: 16,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                         decoration: BoxDecoration(
//                           color: AppColors.textPrimary.withOpacity(0.9),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Row(
//                           children: const [
//                             Icon(Icons.directions_bike_rounded, color: Colors.white, size: 18),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'نطاق التتبع اللحظي نشط الآن داخل مركز كوم حمادة 📍',
//                                 style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//
//               // 2️⃣ بطاقة تفاصيل الكابتن الحقيقي (تم حقن التقييم التراكمي الحي مدمجاً هنا)
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 color: AppColors.white,
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       radius: 24,
//                       backgroundColor: AppColors.primary.withOpacity(0.1),
//                       child: const Icon(Icons.person, color: AppColors.primary, size: 28),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             driverName,
//                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//                           ),
//                           const SizedBox(height: 4),
//                           Row(
//                             children: [
//                               const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
//                               const SizedBox(width: 4),
//                               Text(
//                                 '${driverData?['rating'] ?? '5.00'} ★',
//                                 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//                               ),
//                               const SizedBox(width: 10),
//                               Text(
//                                 driverPhone,
//                                 style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo'),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (driverData?['phone'] != null || driverData?['phoneNumber'] != null)
//                       Container(
//                         decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
//                         child: IconButton(
//                           icon: const Icon(Icons.phone_forwarded_rounded, color: Color(0xFF16A34A), size: 20),
//                           onPressed: () {
//                             _makePhoneCall(driverPhone);
//                           },
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 12),
//
//               // 3️⃣ الـ Stepper Flow التفاعلي المتزامن ثانية بثانية مع الباك إند
//               Expanded(
//                 child: Container(
//                   color: AppColors.white,
//                   child: ListView(
//                     padding: const EdgeInsets.all(24),
//                     physics: const BouncingScrollPhysics(),
//                     children: [
//                       const Text(
//                         'خط سير العمليات اللوجستية:',
//                         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//                       ),
//                       const SizedBox(height: 20),
//                       _buildTrackingStep(stepIndex: 0, currentStep: currentStep, title: 'تم قبول طلبك الموحد', subtitle: 'وافق العميل على عرض سعر الكابتن وجاري التحرك لبدء الدورة.'),
//                       _buildTrackingStep(stepIndex: 1, currentStep: currentStep, title: 'الكابتن في طريقه إلى $storeName', subtitle: 'يتحرك المندوب الآن متوجهاً لموقع الشراء لإحضار قائمة المنتجات.'),
//                       _buildTrackingStep(stepIndex: 2, currentStep: currentStep, title: 'تم شراء المشتريات وتأكيد الفاتورة', subtitle: 'قام الكابتن بإنهاء الدفع ورفع صورة الإيصال، إجمالي التوصيل: ${agreedFee.toStringAsFixed(2)} ج.م.'),
//                       _buildTrackingStep(stepIndex: 3, currentStep: currentStep, title: 'جاري التوصيل إلى عنوانك المعتمد', subtitle: 'الكابتن يقود الآن في طريقه إليك، يرجى تجهيز مبلغ الكاش المستحق للاستلام.'),
//                     ],
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
//   Widget _buildTrackingStep({required int stepIndex, required int currentStep, required String title, required String subtitle}) {
//     bool isDone = stepIndex <= currentStep;
//     bool isCurrent = stepIndex == currentStep;
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Column(
//           children: [
//             Container(
//               width: 24,
//               height: 24,
//               decoration: BoxDecoration(
//                 color: isDone ? AppColors.primary : const Color(0xFFE2E8F0),
//                 shape: BoxShape.circle,
//                 border: isCurrent ? Border.all(color: AppColors.secondary, width: 3) : null,
//               ),
//               child: isDone && !isCurrent ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
//             ),
//             if (stepIndex < 3) Container(width: 2, height: 45, color: stepIndex < currentStep ? AppColors.primary : const Color(0xFFE2E8F0)),
//           ],
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: Column(
//             // 🎯 [تم الإصلاح]: صياغة برامتر المحاذاة العرضية بشكل سليم للـ Column
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDone ? AppColors.textPrimary : AppColors.textSecondary, fontFamily: 'Cairo')),
//               const SizedBox(height: 4),
//               Text(subtitle, style: TextStyle(fontSize: 11, color: isDone ? AppColors.textPrimary.withOpacity(0.7) : AppColors.textSecondary.withOpacity(0.6), fontFamily: 'Cairo', height: 1.4)),
//               const SizedBox(height: 12),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }






import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/utils/phone_format.dart';
import 'package:wasl_app/delivery_screen/WaslDriverRatingScreen.dart';
import 'package:wasl_app/customer_screen/chat/WaslOrderChatScreen.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderInvoiceScreen.dart';
import 'package:wasl_app/services/orders_service.dart';
import 'package:wasl_app/core/ui/wasl_submit_guard.dart';
import 'package:wasl_app/core/widgets/wasl_cancel_dialogs.dart';
import 'package:wasl_app/services/cancellation_models.dart';
import 'package:wasl_app/services/cancellation_service.dart';

class WaslOrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const WaslOrderTrackingScreen({Key? key, required this.orderData}) : super(key: key);

  @override
  State<WaslOrderTrackingScreen> createState() => _WaslOrderTrackingScreenState();
}

class _WaslOrderTrackingScreenState extends State<WaslOrderTrackingScreen>
    with WaslSubmitGuard<WaslOrderTrackingScreen> {
  late Map<String, dynamic> _liveOrder;
  Timer? _pollingTimer;
  final MapController _mapController = MapController();
  bool _invoiceShown = false;

  final WaslCancellationService _cancellationService = WaslCancellationService();

  /// آخر سجل إلغاء على الطلب — مش المفتوح بس.
  ///
  /// لازم يبقى الأحدث مش «المعلّق»، عشان لما الكابتن يرفض السجل بيتغيّر من
  /// `pending` لـ `rejected` وما بيختفيش؛ لو كنا بنمسك المعلّق بس كنا هنقرا
  /// الرفض كأنه «مفيش طلب إلغاء» ونرجّع الزرار من غير ما نقول للعميل حصل إيه.
  WaslCancellation? _latestCancellation;

  @override
  void initState() {
    super.initState();
    _liveOrder = widget.orderData;
    _refreshCancellation();
    _startLiveTracking();
  }

  // ─── الإلغاء ─────────────────────────────────────────────────────────────

  /// الحالات اللي العميل يقدر يطلب فيها الإلغاء.
  ///
  /// `delivering` مش منها عن قصد: الكابتن بيبقى ماسك الطلب على الباب، والخطة
  /// بتقول إن ده قرار دعم مش زرار في التطبيق. والسيرفر بيرفضها برضه.
  static const _cancellableStatuses = {'accepted', 'at_store', 'items_bought'};

  bool get _canRequestCancellation =>
      _cancellableStatuses.contains(
        _liveOrder['status']?.toString().toLowerCase(),
      ) &&
      !(_latestCancellation?.isPending ?? false);

  Future<void> _refreshCancellation() async {
    final orderId = int.tryParse(_liveOrder['id']?.toString() ?? '');
    if (orderId == null) return;

    final result = await _cancellationService.getForOrder(orderId);
    if (!mounted || result['success'] != true) return;

    final requests = (result['requests'] as List).cast<WaslCancellation>();
    setState(
      () => _latestCancellation = requests.isEmpty ? null : requests.last,
    );
  }

  void _requestCancellation() async {
    final orderId = int.tryParse(_liveOrder['id']?.toString() ?? '');
    if (orderId == null) return;

    final reason = await showWaslReasonDialog(
      context,
      title: 'طلب إلغاء الطلب',
      message: 'هيوصل الكابتن طلب إلغاء، وهو اللي يوافق أو يرفض.',
      confirmLabel: 'إرسال الطلب',
      warning: 'الطلب مش هيتلغي دلوقتي — بيتلغي لما الكابتن يوافق.',
    );
    if (reason == null || !mounted) return;

    await guardedSubmit(() async {
      final result = await _cancellationService.requestCancellation(
        orderId,
        reason: reason,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        await _refreshCancellation();
        if (!mounted) return;
        _toast('تم إرسال طلب الإلغاء للكابتن', success: true);
      } else {
        _toast(result['message']?.toString() ?? 'تعذّر إرسال طلب الإلغاء');
      }
    });
  }

  void _toast(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _startLiveTracking() {
    final ordersService = FlutterOrdersService();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final orderId = int.tryParse(_liveOrder['id']?.toString() ?? '');
      if (orderId == null) return;

      final result = await ordersService.getOrderCustomerDetails(orderId);
      if (result['success'] != true || !mounted) return;

      final newData = result['data'];
      final String newStatus = newData['status']?.toString().toLowerCase() ?? '';

      if ((newStatus == 'items_bought' || newStatus == 'delivering') && !_invoiceShown) {
        final double price = double.tryParse(newData['itemsPrice']?.toString() ?? '0') ?? 0;
        if (price > 0) {
          _invoiceShown = true;
          setState(() => _liveOrder = newData);
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WaslOrderInvoiceScreen(orderData: newData)),
          );
          return;
        }
      }

      // الكابتن وافق على الإلغاء: الطلب خلاص اتلغى، فمفيش داعي نفضل نسأل.
      if (newStatus == 'cancelled' &&
          _liveOrder['status']?.toString().toLowerCase() != 'cancelled') {
        setState(() => _liveOrder = newData);
        _pollingTimer?.cancel();
        await _refreshCancellation();
        if (!mounted) return;
        _toast('تم إلغاء الطلب', success: true);
        return;
      }

      // لسه مستنيين رد الكابتن — نسأل على السجل عشان نعرف لو رفض.
      if (_latestCancellation?.isPending == true) {
        await _refreshCancellation();
        if (!mounted) return;
        if (_latestCancellation?.isRejected == true) {
          _toast('رفض الكابتن طلب الإلغاء، والطلب مستمر');
        }
      }

      if (newStatus == 'completed' && _liveOrder['status']?.toString().toLowerCase() != 'completed') {
        setState(() => _liveOrder = newData);
        _pollingTimer?.cancel();
        _showConfirmationDialog(newData);
        return;
      }

      setState(() => _liveOrder = newData);

      if (newData['acceptedDriver']?['latitude'] != null) {
        final double dLat = double.tryParse(newData['acceptedDriver']['latitude'].toString()) ?? 30.46;
        final double dLng = double.tryParse(newData['acceptedDriver']['longitude'].toString()) ?? 30.70;
        _mapController.move(LatLng(dLat, dLng), 16.0);
      }
    });
  }

  /// يفتح محادثة الطلب. نفس الشاشة اللي بيستخدمها الكابتن.
  void _openChat() {
    final orderId = int.tryParse(_liveOrder['id']?.toString() ?? '');
    if (orderId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaslOrderChatScreen(orderId: orderId),
      ),
    );
  }

  void _showConfirmationDialog(Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 تم التوصيل!'),
        content: const Text('نتمنى أن تكون تجربتك مع "وصل" ممتازة. هل ترغب في تقييم الكابتن؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقاً')),
          ElevatedButton(onPressed: () {
            Navigator.pop(context);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WaslDriverRatingScreen(orderData: orderData)));
          }, child: const Text('قيم الآن')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = _liveOrder['acceptedDriver'] ?? {};
    final String name = driver['fullName'] ?? driver['name'] ?? 'كابتن وصل';
    final String phone = formatPhoneForDisplay(driver['phone']);
    final String rating = driver['rating']?.toString() ?? '4.8';

    return Scaffold(
      body: Stack(
        children: [
          // 1. الخريطة في الخلفية
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: LatLng(30.46, 30.70), initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png', userAgentPackageName: 'dev.wasl.app'),
              MarkerLayer(markers: [
                Marker(point: LatLng(30.46, 30.70), child: const Icon(Icons.delivery_dining, color: AppColors.primary, size: 40)),
              ]),
            ],
          ),

          // 2. الـ Bottom Sheet الاحترافي
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            builder: (context, controller) => Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text('بيانات الكابتن', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  // كارت بيانات الكابتن
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: AppColors.primary, child: const Icon(Icons.person, color: Colors.white)),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('⭐ $rating | 📞 $phone', style: TextStyle(color: Colors.grey[600])),
                          ]),
                        ),
                        // 💬 المحادثة بتفتح بعد ما الطلب يتسند لكابتن — قبل كده
                        // مفيش طرف تاني أصلاً، والسيرفر بيرفض الكتابة.
                        if (_liveOrder['acceptedDriverId'] != null)
                          IconButton(
                            tooltip: 'محادثة الطلب',
                            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                            onPressed: _openChat,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // الـ Stepper المحدث
                  ...List.generate(5, (i) => _buildStep(i, _getStep(_liveOrder['status']), ['قبول', 'محل', 'شراء', 'توصيل', 'تم'][i])),
                  const SizedBox(height: 20),
                  _buildCancellationSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// حالة الإلغاء عند العميل: زرار الطلب، أو انتظار رد الكابتن، أو الرفض.
  Widget _buildCancellationSection() {
    final open = _latestCancellation;

    if (open != null && open.isPending) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hourglass_top, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'في انتظار رد الكابتن على طلب الإلغاء',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'السبب: ${open.reason}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!_canRequestCancellation) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: isSubmitting ? null : _requestCancellation,
      icon: isSubmitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cancel_outlined),
      label: const Text('طلب إلغاء الطلب'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildStep(int index, int current, String title) {
    bool isDone = index < current;
    bool isActive = index == current;
    return Row(
      children: [
        Column(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isDone ? Colors.green : (isActive ? AppColors.primary : Colors.grey[300]), shape: BoxShape.circle), child: Icon(isDone ? Icons.check : Icons.circle, color: Colors.white, size: 10)),
          if (index < 4) Container(width: 2, height: 30, color: isDone ? Colors.green : Colors.grey[300]),
        ]),
        const SizedBox(width: 15),
        Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? AppColors.primary : Colors.black)),
      ],
    );
  }

  int _getStep(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted': return 0;
      case 'at_store': return 1;
      case 'items_bought': return 2;
      case 'delivering': return 3;
      case 'completed': return 4;
      default: return 0;
    }
  }

  @override void dispose() { _pollingTimer?.cancel(); super.dispose(); }
}