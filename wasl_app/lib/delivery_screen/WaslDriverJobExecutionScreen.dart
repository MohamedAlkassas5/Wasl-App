import 'package:flutter/material.dart';
import 'package:wasl_app/core/ui/wasl_submit_guard.dart';
// 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
import 'package:wasl_app/core/theme/app_colors.dart';
// 🎯 استيراد الـ Service الخاصة بالطلبات
import 'package:wasl_app/services/orders_service.dart';
// 💬 محادثة الطلب — نفس الشاشة اللي بيستخدمها العميل
import 'package:wasl_app/customer_screen/chat/WaslOrderChatScreen.dart';
import 'package:wasl_app/services/chat_service.dart';

class WaslDriverJobExecutionScreen extends StatefulWidget {
  // 1️⃣ [تم التحديث]: استقبال كائن البيانات الحي والشامل للطلب المقبول من قاعدة البيانات
  final Map<String, dynamic> orderData;

  const WaslDriverJobExecutionScreen({
    Key? key,
    required this.orderData,
  }) : super(key: key);

  @override
  State<WaslDriverJobExecutionScreen> createState() => _WaslDriverJobExecutionScreenState();
}

class _WaslDriverJobExecutionScreenState
    extends State<WaslDriverJobExecutionScreen>
    with WaslSubmitGuard<WaslDriverJobExecutionScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();

  // تتبع حالة التنفيذ الحالية (من 0 إلى 3)
  // 0: تم قبول الطلب، 1: في الطريق للمتجر، 2: تم الشراء (مرحلة الفاتورة)، 3: جاري التوصيل
  int _currentStep = 0;

  final _receiptPriceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _receiptPrice = 0.0;
  bool _isReceiptConfirmed = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _receiptPriceController.dispose();
    super.dispose();
  }

  /// خطوات الرحلة، مطابقة لمخطط الحالات في السيرفر:
  /// `accepted → at_store → items_bought → delivering` ثم تأكيد التسليم.
  ///
  /// الخطوة الأخيرة مالهاش `backendStatus`: إنهاء الطلب بقى ليه مسار مخصص
  /// (`POST /orders/:id/complete`) لأنه بيحرّك فلوس، والسيرفر بيرفض إنهاء
  /// الطلب من مسار تحديث الحالة العادي.
  final List<Map<String, String?>> _stepsData = [
    {'btnText': 'أنا في الطريق للمحل الآن 🚴', 'statusText': 'تم قبول الطلب', 'backendStatus': 'at_store'},
    {'btnText': 'وصلت للمحل وجاري الشراء 🛒', 'statusText': 'في الطريق للمحل', 'backendStatus': 'items_bought'},
    {'btnText': 'تأكيد الفاتورة وبدء التوصيل 📦', 'statusText': 'جاري الشراء', 'backendStatus': 'delivering'},
    {'btnText': 'تم تسليم الطلب وتحصيل الكاش 🎉', 'statusText': 'في الطريق للعميل', 'backendStatus': null},
  ];

  /// كل خطوات الرحلة بتعدي من هنا: تحديث الحالة، طلب تعديل السعر، وإنهاء
  /// الطلب (اللي بيخصم العمولة).
  ///
  /// `if (_isLoading) return` كان موجود، لكنه مش كفاية: في خطوة الفاتورة فيه
  /// `await` على موافقة العميل **قبل** ما `_isLoading` يتحط، فضغطتين سريعتين
  /// كانوا يعدّوا الاتنين. الحارس بيتحط على الدالة كلها.
  ///
  /// الحارس واحد للدالة بالكامل عن قصد — `proposePriceChange` بتتنادى من جوه
  /// عن طريق `_ensurePriceApproved`، ولو كان عليها حارس تاني كان هيتمنع
  /// بالحارس الخارجي وميتبعتش أصلاً.
  Future<void> _moveToNextStep() => guardedSubmit(_advanceOrderStep);

  Future<void> _advanceOrderStep() async {
    if (_isLoading) return;

    final dynamic rawId = widget.orderData['id'];
    final int parsedOrderId = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '1') ?? 1;

    final String? nextStatus = _stepsData[_currentStep]['backendStatus'];
    double? priceToSend;

    if (_currentStep == 2) {
      if (!_formKey.currentState!.validate()) return;
      _receiptPrice = double.parse(_receiptPriceController.text.trim());

      // 💰 السعر مش بتاع الكابتن يغيّره لوحده. لو الفاتورة طلعت مختلفة عن
      // السعر المتفق عليه، بيتبعت طلب تعديل للعميل ويستنى موافقته — السيرفر
      // كمان بيرفض أي تعديل مباشر، فده مش مجرد فحص في التطبيق.
      final approved = await _ensurePriceApproved(parsedOrderId, _receiptPrice);
      if (!approved || !mounted) return;

      _isReceiptConfirmed = true;
      priceToSend = _receiptPrice;
    }

    setState(() => _isLoading = true);

    final result = nextStatus == null
        ? await _ordersService.completeOrder(parsedOrderId)
        : await _ordersService.updateOrderStatus(
            orderId: parsedOrderId,
            status: nextStatus,
            itemsPrice: priceToSend,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (nextStatus == null) {
        // إعادة الإرسال بترجع نفس النتيجة من غير خصم تاني، فالرسالة بتفرّق
        // بين إنهاء جديد وتأكيد لإنهاء حصل قبل كده.
        _showSnackBar(
          result['alreadySettled'] == true
              ? 'الطلب كان متأكد تسليمه بالفعل ✅'
              : 'تم إكمال الطلب بنجاح وخصم عمولة التوصيل 🏁',
          const Color(0xFF16A34A),
        );
        Navigator.pop(context, true);
        return;
      }

      setState(() => _currentStep++);
    } else {
      // السيرفر بيرفض أي انتقال مش مسموح بيه ويقول السبب — بنعرضه زي ما هو
      // بدل رسالة عامة، عشان الكابتن يعرف يعمل إيه.
      _showSnackBar(
        (result['message'] ?? 'حدث خطأ أثناء تحديث حالة الطلب').toString(),
        AppColors.danger,
      );
    }
  }

  /// هل السعر اللي الكابتن كتبه معتمد من العميل؟
  ///
  /// بيقارن بالسعر اللي على الطلب في السيرفر دلوقتي (مش النسخة المحفوظة في
  /// الشاشة). لو نفس السعر → كمّل عادي. لو مختلف → بيتبعت طلب تعديل وبيستنى.
  Future<bool> _ensurePriceApproved(int orderId, double receiptPrice) async {
    setState(() => _isLoading = true);
    final details = await _ordersService.getOrderCustomerDetails(orderId);
    if (!mounted) return false;
    setState(() => _isLoading = false);

    if (details['success'] != true) {
      _showSnackBar('تعذّر التأكد من سعر الطلب، حاول تاني', AppColors.danger);
      return false;
    }

    final serverPrice =
        double.tryParse(details['data']?['itemsPrice']?.toString() ?? '') ?? 0;

    // فرق أقل من قرش يعتبر نفس الرقم.
    if ((serverPrice - receiptPrice).abs() < 0.01) return true;

    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('السعر مختلف عن المتفق عليه',
            style: TextStyle(fontFamily: 'Cairo')),
        content: Text(
          'السعر على الطلب ${serverPrice.toStringAsFixed(2)} ج.م، والفاتورة '
          '${receiptPrice.toStringAsFixed(2)} ج.م.\n\n'
          'العميل لازم يوافق على التعديل قبل ما تكمّل.',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اطلب موافقة العميل'),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return false;

    final result = await WaslChatService().proposePriceChange(
      orderId,
      newItemsPrice: receiptPrice,
      reason: 'سعر الفاتورة الفعلي',
    );
    if (!mounted) return false;

    // 409 معناها فيه طلب مستني رد أصلاً — الاتنين بيروحوا نفس المكان.
    _showSnackBar(
      result['success'] == true
          ? 'تم إرسال طلب تعديل السعر للعميل، استنى موافقته'
          : (result['message']?.toString() ?? 'تعذّر إرسال طلب التعديل'),
      result['success'] == true ? AppColors.primary : AppColors.danger,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WaslOrderChatScreen(orderId: orderId)),
    );
    return false;
  }

  void _showSnackBar(String text, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 [تم التأمين والجبر]: معالجة الـ finalDeliveryFee والـ deliveryFee بأمان تام ضد الـ Null أو الـ String القادم من السيرفر
    final dynamic rawFinalFee = widget.orderData['finalDeliveryFee'];
    final dynamic rawFee = widget.orderData['deliveryFee'];

    final double agreedFee = rawFinalFee != null
        ? (rawFinalFee is num ? rawFinalFee.toDouble() : double.tryParse(rawFinalFee.toString()) ?? 25.0)
        : (rawFee != null ? (rawFee is num ? rawFee.toDouble() : double.tryParse(rawFee.toString()) ?? 25.0) : 25.0);

    double totalBill = agreedFee + _receiptPrice;

    // تأمين جلب رقم الطلب كنص آمن
    final String safeOrderId = widget.orderData['id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Text(
          'FL-$safeOrderId تنفيذ طلب', // 🎯 [تم التأمين بنجاح]
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          // 💬 محادثة الطلب: من هنا الكابتن بيطلب تعديل السعر لو اختلف عن
          // المتوقع — ما بقاش ينفع يكتبه بنفسه من غير موافقة العميل.
          IconButton(
            tooltip: 'محادثة الطلب',
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            onPressed: () {
              final orderId = int.tryParse(safeOrderId);
              if (orderId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WaslOrderChatScreen(orderId: orderId),
                ),
              );
            },
          ),
        ],
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
                      // 1️⃣ كارت تتبع الحالة اللوجستية الحالية حية للرحلة
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            const Icon(Icons.route_rounded, color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('الحالة الحالية للطلب:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                                  Text(_stepsData[_currentStep]['statusText'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2️⃣ تفاصيل الوظيفة وموقع الاستلام والتوصيل (Job Metadata الديناميكي المأمن)
                      _buildInfoSection(
                        title: 'بيانات الاستلام والشراء 🛒',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.orderData['categoryType']?.toString() ?? 'طلبات عامة',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary, fontFamily: 'Cairo'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المحل: ${widget.orderData['storeName']?.toString() ?? 'من أقرب مكان متاح'}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                            ),
                            const Divider(height: 20),
                            const Text('المنتجات المطلوبة يدوياً:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                            const SizedBox(height: 4),
                            Text(
                              widget.orderData['itemsDescription']?.toString() ?? 'لا توجد تفاصيل إضافية مكتوبة',
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo', height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildInfoSection(
                        title: 'وجهة توصيل العميل 📍',
                        content: Text(
                          widget.orderData['deliveryAddressText']?.toString() ?? 'العنوان يدوي',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo', height: 1.4, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3️⃣ لوحة الحسابات الفورية والـ Receipt Price Input الحاسم
                      _buildInfoSection(
                        title: 'الحساب المالي للطلب (كاش) 💵',
                        content: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('رسوم التوصيل المتفق عليها:', style: TextStyle(fontSize: 13, fontFamily: 'Cairo', color: AppColors.textSecondary)),
                                Text('${agreedFee.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('سعر المنتجات من الفاتورة:', style: TextStyle(fontSize: 13, fontFamily: 'Cairo', color: AppColors.textSecondary)),
                                Text('${_receiptPrice.toStringAsFixed(2)} ج.م', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isReceiptConfirmed ? const Color(0xFF16A34A) : AppColors.danger)),
                              ],
                            ),

                            if (_currentStep == 2 && !_isReceiptConfirmed) ...[
                              const Divider(height: 24),
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('اكتب سعر المنتجات الإجمالي بناءً على فاتورة المحل الفعلية:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _receiptPriceController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'برجاء كتابة الإجمالي المدفوع في المحل';
                                        if (double.tryParse(value) == null) return 'أدخل رقم صحيح';
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'مثال: 150',
                                        prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                                        fillColor: AppColors.background,
                                        filled: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الإجمالي المطلوب تحصيله كاش:', style: TextStyle(fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                Text('${totalBill.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4️⃣ الزر السفلي الديناميكي لتحديث خط سير العملية
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GestureDetector(
                  onTap: _moveToNextStep,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: _currentStep == 3 ? const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)]) : AppColors.logoGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                        _stepsData[_currentStep]['btnText'] ?? '',
                        style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.textPrimary.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}