import 'package:flutter/widgets.dart';

/// يمنع تنفيذ نفس العملية مرتين.
///
/// الضغط المزدوج على زرار مش حالة نادرة — الشبكة بتبقى بطيئة، الزرار مابيتغيرش
/// شكله فوراً، فالمستخدم بيضغط تاني. على زرار «إلغاء الطلب» أو «إتمام التوصيل»
/// ده معناه طلبين على السيرفر، وبالتالي احتمال غرامة أو عمولة مرتين.
///
/// السيرفر أصلاً محمي: `wallet_transactions.reference` عليه قيد UNIQUE،
/// فالتحصيل مستحيل يتكرر. لكن الاعتماد على ده وحده معناه إن المستخدم بيشوف
/// رسالة خطأ غامضة على ضغطة تانية شرعية تماماً — الحارس هنا بيمنع الطلب
/// التاني من أصله بدل ما يستنى السيرفر يرفضه.
///
/// الاستخدام:
///
/// ```dart
/// class _MyScreenState extends State<MyScreen> with WaslSubmitGuard<MyScreen> {
///   void _cancel() => guardedSubmit(() async {
///         await service.cancelOrder(id);
///       });
/// }
/// ```
///
/// و`isSubmitting` بيستخدم عشان الزرار يتعطّل ويعرض مؤشر تحميل.
mixin WaslSubmitGuard<T extends StatefulWidget> on State<T> {
  final WaslSubmitLatch _latch = WaslSubmitLatch();

  /// هل فيه عملية شغالة دلوقتي؟ اربط بيها `onPressed` عشان الزرار يتعطّل.
  bool get isSubmitting => _latch.isBusy;

  /// ينفّذ [action] مرة واحدة بس لو فيه واحدة شغالة.
  ///
  /// بترجع `true` لو اتنفذت فعلاً، و`false` لو اتمنعت — الشاشات نادراً
  /// بتحتاج ده، لكنه بيخلي الاختبار يقدر يتأكد إن المنع حصل.
  Future<bool> guardedSubmit(Future<void> Function() action) async {
    if (_latch.isBusy) return false;

    // الـ setState هنا عشان الواجهة تعرف تعطّل الزرار وتعرض مؤشر تحميل.
    setState(() {});
    try {
      return await _latch.run(action);
    } finally {
      // `mounted` مهمة: العملية ممكن تنقل المستخدم لشاشة تانية، والـ setState
      // بعد كده بترمي استثناء يخفي نتيجة العملية الأصلية.
      if (mounted) setState(() {});
    }
  }
}

/// نفس الحارس، من غير ما يحتاج `State`.
///
/// بعض الشاشات لسه `StatelessWidget` وبتبعت الطلب من غير حالة داخلية.
/// تحويلها لـ `StatefulWidget` مجرد عشان الحارس تغيير أكبر من اللازم، فبتاخد
/// نسخة `final` من ده بدل الـ mixin. المنطق واحد — والـ mixin نفسه بيستخدمه
/// جواه عشان مايبقاش فيه تطبيقين للفكرة.
class WaslSubmitLatch {
  bool _busy = false;

  bool get isBusy => _busy;

  /// ينفّذ [action] لو مفيش واحدة شغالة. بترجع `false` لو اتمنعت.
  Future<bool> run(Future<void> Function() action) async {
    if (_busy) return false;

    _busy = true;
    try {
      await action();
      return true;
    } finally {
      _busy = false;
    }
  }
}
