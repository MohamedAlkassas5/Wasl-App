import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:wasl_app/core/config/api_config.dart';
import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/ui/wasl_failure.dart';
import 'package:wasl_app/services/cancellation_models.dart';

/// إلغاء طلب اتقبل من كابتن.
///
/// نفس أسلوب `WaslChatService`: كل دالة بترجّع `{'success': bool, ...}` وما
/// بترميش استثناءات على الشاشة.
///
/// السيرفر هو صاحب القرار في كل حاجة هنا:
///
///  - **مفيش مبلغ بيتبعت من التطبيق.** الغرامة بتتحسب على السيرفر من رسوم
///    التوصيل المجمّدة على الطلب. أي رقم التطبيق يبعته هيتجاهل.
///  - **قرار Q-B3 مطبّق على السيرفر:** لما الكابتن يوافق على طلب إلغاء من
///    العميل مفيش غرامة خالص. التطبيق بيعرض القرار ده، مش بينفذه.
///  - **الرفض ما بيحركش فلوس** والطلب بيكمل عادي.
class WaslCancellationService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  static const _timeout = Duration(seconds: 15);

  String _url(int orderId, String path) => '$baseUrl/orders/$orderId/$path';

  // ─── العميل بيطلب ────────────────────────────────────────────────────────

  /// العميل بيطلب إلغاء طلب اتقبل. الكابتن لسه لازم يوافق.
  ///
  /// السبب مطلوب — من غيره الأدمن ما يقدرش يراجع الإلغاء بعدين.
  Future<Map<String, dynamic>> requestCancellation(
    int orderId, {
    required String reason,
  }) async {
    return _post(
      _url(orderId, 'cancellation-request'),
      body: {'reason': reason.trim()},
      fallback: 'تعذّر إرسال طلب الإلغاء',
    );
  }

  // ─── الكابتن بيرد ────────────────────────────────────────────────────────

  /// الكابتن بيوافق على طلب العميل: الطلب بيتلغي **ومن غير غرامة** (Q-B3).
  Future<Map<String, dynamic>> approveCustomerRequest(int orderId) async {
    return _post(
      _url(orderId, 'cancellation-request/approve'),
      fallback: 'تعذّر الموافقة على طلب الإلغاء',
    );
  }

  /// الكابتن بيرفض: الطلب بيكمل ومفيش أي فلوس بتتحرك.
  Future<Map<String, dynamic>> rejectCustomerRequest(
    int orderId, {
    String? decisionReason,
  }) async {
    final reason = decisionReason?.trim() ?? '';
    return _post(
      _url(orderId, 'cancellation-request/reject'),
      body: reason.isEmpty ? null : {'decisionReason': reason},
      fallback: 'تعذّر رفض طلب الإلغاء',
    );
  }

  // ─── الكابتن بيلغي من نفسه ───────────────────────────────────────────────

  /// الكابتن بيسيب طلب كان قابله. **دي الحالة اللي فيها غرامة.**
  ///
  /// المبلغ بيرجع في `penalty` من السيرفر بعد الخصم — التطبيق ما بيحسبوش.
  Future<Map<String, dynamic>> driverCancel(
    int orderId, {
    required String reason,
  }) async {
    return _post(
      _url(orderId, 'driver-cancel'),
      body: {'reason': reason.trim()},
      fallback: 'تعذّر إلغاء الطلب',
    );
  }

  // ─── الاعتراض على الغرامة ────────────────────────────────────────────────

  /// الكابتن بيعترض على غرامة اتخصمت. الدليل هو محادثة الطلب نفسها.
  Future<Map<String, dynamic>> appeal(
    int orderId, {
    required String reason,
  }) async {
    return _post(
      _url(orderId, 'cancellation/appeal'),
      body: {'reason': reason.trim()},
      fallback: 'تعذّر إرسال الاعتراض',
    );
  }

  // ─── قراءة السجل ─────────────────────────────────────────────────────────

  /// سجلات الإلغاء على الطلب — للطرفين وللأدمن.
  Future<Map<String, dynamic>> getForOrder(int orderId) async {
    try {
      final response = await WaslAuthedHttp.instance
          .get(Uri.parse(_url(orderId, 'cancellation')))
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) {
        final raw = (decoded['requests'] as List?) ?? const [];
        return {
          'success': true,
          'requests': raw
              .map((item) =>
                  WaslCancellation.fromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return _failure(decoded, 'تعذّر تحميل حالة الإلغاء');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  /// أحدث طلب إلغاء **مفتوح** على الطلب، لو فيه.
  ///
  /// دي اللي الكابتن محتاج يشوفها: السيرفر بيسمح بواحد مفتوح بس على كل طلب
  /// (قيد في قاعدة البيانات)، فالنتيجة هنا واحدة أو ولا حاجة.
  Future<WaslCancellation?> pendingRequestFor(int orderId) async {
    final result = await getForOrder(orderId);
    if (result['success'] != true) return null;

    final requests = (result['requests'] as List).cast<WaslCancellation>();
    for (final request in requests) {
      if (request.isPending) return request;
    }
    return null;
  }

  // ─── مساعدات ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
    String url, {
    Map<String, dynamic>? body,
    required String fallback,
  }) async {
    try {
      final response = await WaslAuthedHttp.instance
          .post(
            Uri.parse(url),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) {
        return {
          'success': true,
          // بيرجعوا من مسارات الإلغاء اللي بتلغي فعلاً؛ الباقي بيسيبهم فاضيين.
          'cancelled': decoded['cancelled'] == true,
          'repeated': decoded['repeated'] == true,
          'penalty': _asDouble(decoded['penalty']),
          'data': decoded['data'],
        };
      }
      return _failure(decoded, fallback);
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  /// السيرفر بيرجّع أعمدة الفلوس كنص أحياناً (decimal في Postgres).
  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
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
          : (message?.toString() ?? fallback),
    };
  }
}
