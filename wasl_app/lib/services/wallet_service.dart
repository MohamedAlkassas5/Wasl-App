import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:wasl_app/core/config/api_config.dart';
import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/network/image_upload.dart';
import 'package:wasl_app/core/ui/wasl_failure.dart';

/// محفظة الكابتن — الرصيد وطلبات الشحن.
///
/// نفس أسلوب `WaslChatService` و`WaslCancellationService`: كل دالة بترجّع
/// `{'success': bool, ...}` وما بترميش استثناءات على الشاشة.
///
/// **الرصيد ليه مصدر واحد بس.** كل شاشة بتعرض رصيد بتقراه من
/// `GET /wallet/summary`، والمسار ده ما بياخدش رقم كابتن — المحفظة بتاعة صاحب
/// التوكن. الشاشات قبل كده كانت بتقرا الرصيد من
/// `/orders/driver/:id/dashboard-stats` برقم متخزّن في `SharedPreferences`،
/// وكل شاشة بترجع لرقم افتراضي مختلف لما القراءة تفشل — فالشاشة الرئيسية
/// تعرض رقم والمحفظة تعرض غيره. المسار ده ما ينفعش يتوجّه لصف غلط.
///
/// **وطلب الشحن مش شحن.** `submitTopUp` بيعمل طلب حالته `pending` وخلاص؛
/// الفلوس ما بتتحركش غير لما الإدارة تراجع صورة التحويل وتوافق. أي رسالة في
/// الواجهة لازم تقول كده.
class WaslWalletService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  static const _timeout = Duration(seconds: 15);

  /// الرصيد المعتمد + عدد طلبات الشحن اللي لسه تحت المراجعة.
  Future<Map<String, dynamic>> getSummary() async {
    return _get('$baseUrl/wallet/summary', 'تعذّر تحميل رصيد المحفظة');
  }

  /// حسابات فودافون كاش / إنستاباي اللي الكابتن بيحوّل عليها، وحدود المبلغ.
  Future<Map<String, dynamic>> getPaymentAccounts() async {
    return _get(
      '$baseUrl/wallet/payment-accounts',
      'تعذّر تحميل بيانات التحويل',
    );
  }

  /// طلبات الشحن السابقة للكابتن — بحالتها وسبب الرفض لو اترفضت.
  Future<Map<String, dynamic>> getMyRequests() async {
    final result = await _get(
      '$baseUrl/wallet/topup-requests/mine',
      'تعذّر تحميل طلبات الشحن',
      expectList: true,
    );
    if (result['success'] != true) return result;
    return {
      'success': true,
      'requests': (result['items'] as List)
          .map((item) => WaslTopUpRequest.fromJson(item as Map<String, dynamic>))
          .toList(),
    };
  }

  /// حركات المحفظة (شحن، عمولة، غرامة...) — نفس السجل اللي الإدارة بتشوفه.
  Future<Map<String, dynamic>> getTransactions() async {
    final result = await _get(
      '$baseUrl/wallet/transactions/mine',
      'تعذّر تحميل حركات المحفظة',
      expectList: true,
    );
    if (result['success'] != true) return result;
    return {
      'success': true,
      'transactions': (result['items'] as List)
          .map((item) =>
              WaslWalletTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
    };
  }

  /// تقديم طلب شحن مع صورة التحويل.
  ///
  /// الصورة **مطلوبة**: من غيرها مفيش حاجة الإدارة تراجعها، والسيرفر بيرفض
  /// الطلب. والمبلغ اللي بيتسجّل هو اللي السيرفر بيتحقق منه، مش اللي التطبيق
  /// بيبعته.
  Future<Map<String, dynamic>> submitTopUp({
    required double amount,
    required WaslTopUpMethod method,
    required File proofImage,
    String? senderReference,
  }) async {
    try {
      // جوه closure لأن الـ multipart بيتبعت مرة واحدة؛ لو التوكن اتجدد،
      // الإعادة محتاجة request جديد من الأول.
      final response = await WaslAuthedHttp.instance.sendMultipart(
        () async {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/wallet/topup-requests'),
          );
          request.fields['amount'] = amount.toString();
          request.fields['method'] = method.wire;
          final reference = senderReference?.trim() ?? '';
          if (reference.isNotEmpty) {
            request.fields['senderReference'] = reference;
          }
          // ⚠️ مش `fromPath`: دي بتبعت `application/octet-stream` والسيرفر
          // بيرفضها بـ "Only JPEG, PNG, and WebP image uploads are allowed"،
          // فأي سكرين شوت عادي كان بيترفض. `WaslImageUpload` بتقرا التوقيع من
          // بايتات الملف نفسه وتعلن النوع الصح.
          request.files.add(
            await WaslImageUpload.multipartFile('proofImage', proofImage),
          );
          return request;
        },
        timeout: const Duration(seconds: 40),
      );

      final decoded = _decode(response);
      if (_ok(response)) {
        return {
          'success': true,
          'message': decoded['message'],
          'request': decoded['request'] is Map<String, dynamic>
              ? WaslTopUpRequest.fromJson(
                  decoded['request'] as Map<String, dynamic>)
              : null,
        };
      }
      return _failure(decoded, 'تعذّر إرسال طلب الشحن');
    } on WaslImageUploadException catch (e) {
      // الصورة اترفضت قبل ما تتبعت — السبب بيتعرض زي ما هو.
      return {'success': false, 'message': e.message};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  // ─── مساعدات ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(
    String url,
    String fallback, {
    bool expectList = false,
  }) async {
    try {
      final response = await WaslAuthedHttp.instance
          .get(Uri.parse(url))
          .timeout(_timeout);

      if (_ok(response)) {
        if (expectList) {
          final decoded = response.body.isEmpty ? [] : jsonDecode(response.body);
          return {
            'success': true,
            'items': decoded is List ? decoded : const [],
          };
        }
        return {'success': true, ..._decode(response)};
      }
      return _failure(_decode(response), fallback);
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _failure(Map<String, dynamic> decoded, String fallback) {
    final message = decoded['message'];
    return {
      'success': false,
      'message': message is List
          ? message.join('، ')
          : (message?.toString().isNotEmpty == true
              ? message.toString()
              : fallback),
    };
  }
}

/// طرق التحويل المدعومة. القيم دي هي اللي السيرفر بيقبلها (`TopUpMethod`).
enum WaslTopUpMethod {
  vodafoneCash('vodafone_cash', 'فودافون كاش'),
  instapay('instapay', 'إنستاباي');

  const WaslTopUpMethod(this.wire, this.label);

  final String wire;
  final String label;

  static WaslTopUpMethod fromWire(String? value) =>
      value == 'instapay' ? WaslTopUpMethod.instapay : WaslTopUpMethod.vodafoneCash;
}

/// حالة طلب الشحن. الفلوس بتتحرك في `approved` بس.
enum WaslTopUpStatus {
  pending('قيد المراجعة'),
  approved('تمت الإضافة'),
  rejected('مرفوض');

  const WaslTopUpStatus(this.label);

  final String label;

  static WaslTopUpStatus fromWire(String? value) {
    switch (value) {
      case 'approved':
        return WaslTopUpStatus.approved;
      case 'rejected':
        return WaslTopUpStatus.rejected;
      default:
        return WaslTopUpStatus.pending;
    }
  }
}

class WaslTopUpRequest {
  const WaslTopUpRequest({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.adminNote,
    this.senderReference,
  });

  final int id;
  final double amount;
  final WaslTopUpMethod method;
  final WaslTopUpStatus status;
  final DateTime? createdAt;

  /// ملاحظة الإدارة — وهي سبب الرفض لما الطلب يترفض.
  final String? adminNote;
  final String? senderReference;

  bool get isPending => status == WaslTopUpStatus.pending;

  factory WaslTopUpRequest.fromJson(Map<String, dynamic> json) {
    return WaslTopUpRequest(
      id: _asInt(json['id']),
      amount: _asDouble(json['amount']),
      method: WaslTopUpMethod.fromWire(json['method']?.toString()),
      status: WaslTopUpStatus.fromWire(json['status']?.toString()),
      createdAt: _asDate(json['createdAt']),
      adminNote: json['adminNote']?.toString(),
      senderReference: json['senderReference']?.toString(),
    );
  }
}

class WaslWalletTransaction {
  const WaslWalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.balanceAfter,
    required this.createdAt,
    this.note,
  });

  final int id;
  final double amount;
  final String type;

  /// الرصيد بعد الحركة دي — بيتكتب على السيرفر في نفس المعاملة اللي بتحرك
  /// الرصيد، فهو دايماً متطابق مع الرصيد في `summary` عند آخر حركة.
  final double balanceAfter;
  final DateTime? createdAt;
  final String? note;

  bool get isCredit => amount > 0;

  factory WaslWalletTransaction.fromJson(Map<String, dynamic> json) {
    return WaslWalletTransaction(
      id: _asInt(json['id']),
      amount: _asDouble(json['amount']),
      type: json['type']?.toString() ?? '',
      balanceAfter: _asDouble(json['balanceAfter']),
      createdAt: _asDate(json['createdAt']),
      note: json['note']?.toString(),
    );
  }
}

/// أعمدة الفلوس بترجع نص من Postgres (numeric)، فالتحويل لازم يتعامل مع الاتنين.
double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _asDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
