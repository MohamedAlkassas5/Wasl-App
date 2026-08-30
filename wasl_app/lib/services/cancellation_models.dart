/// سجل إلغاء واحد على طلب — مين طلب الإلغاء، ليه، مين قرر، وكام كلّف.
///
/// نفس الجدول بيخدم الحالتين (العميل بيطلب والكابتن بيوافق، أو الكابتن بيلغي
/// من نفسه)، فالموديل ده واحد للاتنين — بالظبط زي ما السيرفر عامله.
///
/// الفلوس مش بتتحسب هنا. `penaltyAmount` نسخة للقراءة بس؛ السجل الحقيقي هو
/// حركة المحفظة اللي اسمها في `penaltyReference`.
class WaslCancellation {
  const WaslCancellation({
    required this.id,
    required this.orderId,
    required this.requestedBy,
    required this.requestedByRole,
    required this.reason,
    required this.status,
    this.decisionReason,
    this.penaltyAmount = 0,
    this.penaltyReference,
    this.appealStatus = 'none',
    this.appealReason,
    this.refundAmount = 0,
    this.reviewNote,
  });

  final int id;
  final int orderId;
  final int requestedBy;

  /// `customer` أو `driver` — مين فتح السجل ده.
  final String requestedByRole;
  final String reason;

  /// `pending` / `approved` / `rejected`.
  final String status;
  final String? decisionReason;

  final double penaltyAmount;
  final String? penaltyReference;

  /// `none` / `pending` / `upheld` / `refunded`.
  final String appealStatus;
  final String? appealReason;
  final double refundAmount;
  final String? reviewNote;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  /// السجل ده اتفتح بطلب من العميل (يعني الكابتن هو اللي بيرد عليه).
  bool get openedByCustomer => requestedByRole == 'customer';

  /// اتخصمت غرامة فعلاً.
  ///
  /// بنسأل على المرجع مش على المبلغ: تحت قرار Q-B3 الموافقة على طلب العميل
  /// بتسيب `penaltyAmount = 0` **ومن غير مرجع أصلاً**، وده الفرق بين
  /// «مفيش غرامة» و«غرامة بصفر».
  bool get wasCharged => (penaltyReference?.isNotEmpty ?? false);

  /// الكابتن يقدر يعترض: فيه غرامة اتخصمت، ولسه ما اعترضش.
  bool get canAppeal => isApproved && wasCharged && appealStatus == 'none';

  bool get appealIsOpen => appealStatus == 'pending';
  bool get appealRefunded => appealStatus == 'refunded';
  bool get appealUpheld => appealStatus == 'upheld';

  factory WaslCancellation.fromJson(Map<String, dynamic> json) {
    return WaslCancellation(
      id: _asInt(json['id']),
      orderId: _asInt(json['orderId']),
      requestedBy: _asInt(json['requestedBy']),
      requestedByRole: json['requestedByRole']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      decisionReason: _asNullableString(json['decisionReason']),
      penaltyAmount: _asDouble(json['penaltyAmount']),
      penaltyReference: _asNullableString(json['penaltyReference']),
      appealStatus: json['appealStatus']?.toString() ?? 'none',
      appealReason: _asNullableString(json['appealReason']),
      refundAmount: _asDouble(json['refundAmount']),
      reviewNote: _asNullableString(json['reviewNote']),
    );
  }

  // Postgres بيرجّع أعمدة الـ decimal كنص، فالتحويل لازم يستحمل الاتنين.
  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
