import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:wasl_app/core/network/authed_http.dart';
import 'package:http/http.dart' as http;

import 'package:wasl_app/core/config/api_config.dart';
import 'package:wasl_app/customer_screen/chat/chat_models.dart';

/// محادثة الطلب — عميل ↔ كابتن.
///
/// نفس أسلوب `FlutterOrdersService`: كل دالة بترجّع
/// `{'success': bool, ...}` وما بترميش استثناءات على الشاشة.
///
/// السيرفر هو اللي بيقرر مين يقدر يقرأ ويكتب في المحادثة، وبيرفض الكتابة بعد
/// ما الطلب يخلص أو يتلغي. التطبيق بيعكس القرار ده في الواجهة بس.
class WaslChatService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  String _chatUrl(int orderId) => '$baseUrl/orders/$orderId/chat';

  static const _timeout = Duration(seconds: 15);

  /// الرسائل. `after` بيخلي الـ polling يجيب الجديد بس.
  Future<Map<String, dynamic>> getMessages(int orderId, {int? after}) async {
    final query = after != null && after > 0 ? '?after=$after' : '';
    try {
      final response = await WaslAuthedHttp.instance
          .get(
            Uri.parse('${_chatUrl(orderId)}/messages$query'),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) {
        final raw = (decoded['messages'] as List?) ?? const [];
        return {
          'success': true,
          'closed': decoded['closed'] == true,
          'messages': raw
              .map((item) =>
                  WaslChatMessage.fromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return _failure(decoded, 'تعذّر تحميل المحادثة');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  Future<Map<String, dynamic>> sendText(int orderId, String body) async {
    try {
      final response = await WaslAuthedHttp.instance
          .post(
            Uri.parse('${_chatUrl(orderId)}/messages'),
            body: jsonEncode({'body': body}),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) return {'success': true, 'data': decoded};
      return _failure(decoded, 'تعذّر إرسال الرسالة');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// إرسال صورة. الملف بيتبعت multipart وبيتخزّن على السيرفر بعد التحقق من
  /// نوعه الحقيقي — التطبيق ما بيحددش اسم الملف ولا مكانه.
  Future<Map<String, dynamic>> sendImage(
    int orderId,
    File image, {
    String? caption,
  }) async {
    try {
      // مبنيّة جوه closure عشان الـ multipart بيتبعت مرة واحدة بس؛ لو التوكن
      // خلص و اتجدد، الإعادة محتاجة request جديد من الأول.
      final response = await WaslAuthedHttp.instance.sendMultipart(
        () async {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('${_chatUrl(orderId)}/messages/image'),
          );

          if (caption != null && caption.trim().isNotEmpty) {
            request.fields['body'] = caption.trim();
          }
          request.files
              .add(await http.MultipartFile.fromPath('attachment', image.path));
          return request;
        },
        timeout: const Duration(seconds: 30),
      );

      final decoded = _decode(response);
      if (_ok(response)) return {'success': true, 'data': decoded};
      return _failure(decoded, 'تعذّر إرسال الصورة');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  Future<Map<String, dynamic>> markRead(int orderId) async {
    try {
      final response = await WaslAuthedHttp.instance
          .post(Uri.parse('${_chatUrl(orderId)}/read'))
          .timeout(_timeout);
      return {'success': _ok(response)};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<int> unreadCount(int orderId) async {
    try {
      final response = await WaslAuthedHttp.instance
          .get(
            Uri.parse('${_chatUrl(orderId)}/unread-count'),
          )
          .timeout(_timeout);
      if (!_ok(response)) return 0;
      return (_decode(response)['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ─── تعديل السعر ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPriceProposals(int orderId) async {
    try {
      final response = await WaslAuthedHttp.instance
          .get(
            Uri.parse('${_chatUrl(orderId)}/price-proposals'),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) {
        final raw = (decoded['proposals'] as List?) ?? const [];
        return {
          'success': true,
          'proposals': raw
              .map((item) =>
                  WaslPriceProposal.fromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return _failure(decoded, 'تعذّر تحميل طلبات تعديل السعر');
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// الكابتن بيطلب تعديل السعر. ما بيغيّرش أي حاجة في الطلب لوحده.
  Future<Map<String, dynamic>> proposePriceChange(
    int orderId, {
    required double newItemsPrice,
    String? reason,
  }) async {
    try {
      final response = await WaslAuthedHttp.instance
          .post(
            Uri.parse('${_chatUrl(orderId)}/price-proposals'),
            body: jsonEncode({
              'newItemsPrice': newItemsPrice,
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
            }),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) return {'success': true, 'data': decoded};
      return _failure(decoded, 'تعذّر إرسال طلب تعديل السعر');
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// رد العميل. زرار صريح — مش نص مكتوب في المحادثة.
  Future<Map<String, dynamic>> decidePriceProposal(
    int orderId,
    int proposalId, {
    required bool approve,
  }) async {
    final action = approve ? 'approve' : 'reject';
    try {
      final response = await WaslAuthedHttp.instance
          .post(
            Uri.parse('${_chatUrl(orderId)}/price-proposals/$proposalId/$action'),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) return {'success': true, 'data': decoded};
      return _failure(decoded, 'تعذّر إرسال ردك');
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // ─── مساعدات ─────────────────────────────────────────────────────────────

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
