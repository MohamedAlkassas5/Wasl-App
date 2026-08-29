import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// لماذا فشل الطلب، بالشكل اللي المستخدم يحتاج يعرفه.
///
/// مش كل فشل زي التاني: انقطاع الشبكة بيتصلح بإعادة المحاولة، والصلاحية
/// المرفوضة لأ. التصنيف ده هو اللي بيحدد الرسالة وهل نعرض زرار «إعادة
/// المحاولة» أصلاً.
enum WaslFailureKind {
  /// مفيش اتصال بالشبكة أو السيرفر مش راضي يرد.
  offline,

  /// الاتصال اشتغل بس خد وقت أطول من اللازم.
  timeout,

  /// السيرفر رد بخطأ من عنده (5xx).
  server,

  /// الجلسة انتهت أو مش مصرّح.
  unauthorized,

  /// الطلب نفسه مرفوض (4xx) — غالباً رسالة السيرفر هي الأوضح.
  request,

  /// حاجة مش متوقعة.
  unknown,
}

/// فشل عملية، جاهز للعرض.
///
/// **مبدأ أساسي:** الرسالة اللي جوه دي بتتعرض للمستخدم، فلازم تكون عربي مفهوم.
/// نص الاستثناء الإنجليزي وأكواد HTTP بيفضلوا في اللوج للمطوّر ومابيوصلوش
/// للشاشة أبداً — المستخدم مش هيستفيد من «SocketException: Failed host lookup»
/// ولا من «500»، ودي كانت بتتحط حرفياً في رسائل الخطأ قبل كده.
class WaslFailure {
  const WaslFailure({
    required this.kind,
    required this.message,
    this.technicalDetail,
  });

  final WaslFailureKind kind;

  /// عربي، بصيغة تقول للمستخدم يعمل إيه.
  final String message;

  /// للّوج فقط. ممنوع عرضها.
  final String? technicalDetail;

  /// هل يستاهل نعرض «إعادة المحاولة»؟
  ///
  /// إعادة المحاولة منطقية للشبكة والسيرفر، ومش منطقية لطلب مرفوض أو جلسة
  /// منتهية — زرار بيفشل كل مرة أسوأ من مفيش زرار.
  bool get isRetryable =>
      kind == WaslFailureKind.offline ||
      kind == WaslFailureKind.timeout ||
      kind == WaslFailureKind.server ||
      kind == WaslFailureKind.unknown;

  /// هل ده انقطاع شبكة؟ الشاشات بتعرض شريط «مفيش اتصال» بناءً عليه.
  bool get isOffline => kind == WaslFailureKind.offline;

  /// يترجم أي استثناء لفشل بصيغة معروضة.
  ///
  /// الاتصال بيتقاس من فشل الطلب نفسه — من غير أي مكتبة خارجية لمراقبة
  /// الشبكة. ده مقصود: اللي يهم مش إن الموبايل واصل بواي فاي، اللي يهم إننا
  /// قدرنا نوصل للسيرفر بتاعنا فعلاً.
  factory WaslFailure.from(Object error) {
    if (error is WaslFailure) return error;

    if (error is SocketException || error is http.ClientException) {
      return WaslFailure(
        kind: WaslFailureKind.offline,
        message: 'تعذّر الاتصال بالإنترنت، تأكد من الشبكة وحاول مرة أخرى',
        technicalDetail: error.toString(),
      );
    }

    if (error is TimeoutException) {
      return WaslFailure(
        kind: WaslFailureKind.timeout,
        message: 'الاتصال أخذ وقتاً أطول من المعتاد، حاول مرة أخرى',
        technicalDetail: error.toString(),
      );
    }

    if (error is HttpException) {
      return WaslFailure(
        kind: WaslFailureKind.offline,
        message: 'تعذّر الوصول إلى الخادم، حاول مرة أخرى',
        technicalDetail: error.toString(),
      );
    }

    return WaslFailure(
      kind: WaslFailureKind.unknown,
      message: 'حدث خطأ غير متوقع، حاول مرة أخرى',
      technicalDetail: error.toString(),
    );
  }

  /// يبني فشل من رد السيرفر.
  ///
  /// [serverMessage] بتتعرض لو السيرفر بعت رسالة عربية مفهومة — الباك إند
  /// بيرجّع رسايله بالعربي أصلاً. لو مبعتش، بنستخدم نص عام حسب كود الحالة،
  /// والكود نفسه مابيتعرضش.
  factory WaslFailure.fromResponse(int statusCode, {String? serverMessage}) {
    final trimmed = serverMessage?.trim();
    final usable = (trimmed != null && trimmed.isNotEmpty && !_looksTechnical(trimmed))
        ? trimmed
        : null;

    if (statusCode == 401 || statusCode == 403) {
      return WaslFailure(
        kind: WaslFailureKind.unauthorized,
        message: usable ?? 'انتهت الجلسة، سجّل دخولك مرة أخرى',
        technicalDetail: 'HTTP $statusCode',
      );
    }

    if (statusCode >= 500) {
      return WaslFailure(
        kind: WaslFailureKind.server,
        message: 'الخدمة غير متاحة مؤقتاً، حاول بعد قليل',
        technicalDetail: 'HTTP $statusCode',
      );
    }

    return WaslFailure(
      kind: WaslFailureKind.request,
      message: usable ?? 'تعذّر إتمام العملية، حاول مرة أخرى',
      technicalDetail: 'HTTP $statusCode',
    );
  }

  /// يحوّل الفشل لنفس شكل الـ Map اللي الخدمات بترجّعه.
  ///
  /// الخدمات كلها بترجّع `{'success': bool, 'message': String}`، والشاشات
  /// متعوّدة على الشكل ده. بنضيف `kind` عشان الشاشة تعرف تفرّق بين انقطاع
  /// شبكة (يستاهل «إعادة المحاولة» وشريط «مفيش اتصال») وبين طلب مرفوض.
  Map<String, dynamic> toResult() => {
        'success': false,
        'message': message,
        'kind': kind.name,
      };

  /// يقرا الفشل من نتيجة خدمة.
  ///
  /// لو الخدمة بعتت `kind` بنستخدمه؛ لو لأ — وده حال الأكواد القديمة — بنفترض
  /// إنه فشل يستاهل إعادة المحاولة، لأن ده أفيد للمستخدم من رسالة نهائية.
  factory WaslFailure.fromResult(Map<String, dynamic> result) {
    final rawKind = result['kind']?.toString();
    final kind = WaslFailureKind.values.firstWhere(
      (candidate) => candidate.name == rawKind,
      orElse: () => WaslFailureKind.unknown,
    );

    final message = result['message']?.toString().trim();
    final usable =
        (message != null && message.isNotEmpty && !_looksTechnical(message))
            ? message
            : null;

    return WaslFailure(
      kind: kind,
      message: usable ?? 'تعذّر تحميل البيانات، حاول مرة أخرى',
    );
  }

  /// هل النص ده شكله رسالة مطوّر مش رسالة مستخدم؟
  ///
  /// السيرفر بيرجّع عربي، لكن بعض الأخطاء (خصوصاً من الـ framework) بترجع
  /// إنجليزي زي "Internal server error" أو "Cannot POST /x" — دي ماينفعش
  /// تتعرض لمستخدم بيقرا عربي.
  static bool _looksTechnical(String message) {
    if (RegExp(r'^[\x00-\x7F\s]+$').hasMatch(message)) return true;
    return message.contains('Exception') ||
        message.contains('Error:') ||
        message.contains('http://') ||
        message.contains('https://');
  }

  @override
  String toString() => 'WaslFailure(${kind.name}): $message';
}
