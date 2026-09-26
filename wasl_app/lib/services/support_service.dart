import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:wasl_app/core/config/api_config.dart';
import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/network/image_upload.dart';
import 'package:wasl_app/core/ui/wasl_failure.dart';

/// محادثة الدعم الفني — الكابتن ↔ الإدارة.
///
/// **دي مش محادثة الطلب.** محادثة الطلب (`WaslChatService`) بين العميل
/// والكابتن ومربوطة بطلب معيّن؛ دي بين الكابتن والمنصة نفسها، وغالباً في حاجة
/// مالهاش طلب أصلاً — «حوّلت ١٠٠ جنيه والمحفظة زي ما هي».
///
/// **مفيش رقم محادثة في أي مسار هنا.** المحادثة بتاعة صاحب التوكن، فمفيش
/// بارامتر أصلاً يتطلب بيه حد محادثة حد تاني — نفس مبدأ `/wallet/summary`.
class WaslSupportService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  static const _timeout = Duration(seconds: 15);

  /// الرسائل، الأقدم الأول. `after` بيخلي الـ polling يجيب الجديد بس.
  Future<Map<String, dynamic>> getMessages({int? after}) async {
    final query = after != null && after > 0 ? '?after=$after' : '';
    try {
      final response = await WaslAuthedHttp.instance
          .get(Uri.parse('$baseUrl/support/messages$query'))
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) {
        final raw = (decoded['messages'] as List?) ?? const [];
        return {
          'success': true,
          'conversationId': decoded['conversationId'],
          'status': decoded['status']?.toString() ?? 'open',
          'messages': raw
              .map((m) => WaslSupportMessage.fromJson(m as Map<String, dynamic>))
              .toList(),
        };
      }
      return _failure(decoded, 'تعذّر تحميل محادثة الدعم');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  /// عدد ردود الإدارة اللي الكابتن ما قراهاش — الشارة على بند الإعدادات.
  Future<int> unreadCount() async {
    try {
      final response = await WaslAuthedHttp.instance
          .get(Uri.parse('$baseUrl/support/unread-count'))
          .timeout(_timeout);
      if (!_ok(response)) return 0;
      final decoded = _decode(response);
      return (decoded['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // شارة مش رقم مهم — لو فشلت القراءة ما نزعجش الكابتن برسالة خطأ.
      return 0;
    }
  }

  Future<void> markRead() async {
    try {
      await WaslAuthedHttp.instance
          .post(Uri.parse('$baseUrl/support/read'))
          .timeout(_timeout);
    } catch (_) {
      // مجرد إزالة شارة؛ فشلها ما بيمنعش الكابتن من القراءة.
    }
  }

  Future<Map<String, dynamic>> sendMessage(String body) async {
    final text = body.trim();
    if (text.isEmpty) {
      return {'success': false, 'message': 'اكتب رسالتك الأول'};
    }
    try {
      final response = await WaslAuthedHttp.instance
          .post(
            Uri.parse('$baseUrl/support/messages'),
            body: jsonEncode({'body': text}),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) {
        return {
          'success': true,
          'data': decoded['data'] is Map<String, dynamic>
              ? WaslSupportMessage.fromJson(
                  decoded['data'] as Map<String, dynamic>)
              : null,
        };
      }
      return _failure(decoded, 'تعذّر إرسال الرسالة');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  /// إرفاق صورة — إيصال التحويل ورا شكوى المحفظة هو الحالة الشائعة.
  ///
  /// بيعدّي على نفس `WaslImageUpload` بتاعة شحن المحفظة، فنوع المحتوى بيتقرا
  /// من بايتات الملف والسيرفر ما بيرفضش سكرين شوت سليم.
  Future<Map<String, dynamic>> sendImage(File image, {String? caption}) async {
    try {
      final response = await WaslAuthedHttp.instance.sendMultipart(
        () async {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/support/messages/image'),
          );
          final text = caption?.trim() ?? '';
          if (text.isNotEmpty) request.fields['body'] = text;
          request.files
              .add(await WaslImageUpload.multipartFile('attachment', image));
          return request;
        },
        timeout: const Duration(seconds: 40),
      );

      final decoded = _decode(response);
      if (_ok(response)) return {'success': true, 'data': decoded['data']};
      return _failure(decoded, 'تعذّر إرسال الصورة');
    } on WaslImageUploadException catch (e) {
      return {'success': false, 'message': e.message};
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

/// مين كاتب الرسالة. السيرفر هو اللي بيحددها — التطبيق بيرسم بيها بس.
enum WaslSupportSender {
  user,
  admin,
  system;

  static WaslSupportSender fromWire(String? value) {
    switch (value) {
      case 'admin':
        return WaslSupportSender.admin;
      case 'system':
        return WaslSupportSender.system;
      default:
        return WaslSupportSender.user;
    }
  }
}

class WaslSupportMessage {
  const WaslSupportMessage({
    required this.id,
    required this.sender,
    required this.createdAt,
    this.body,
    this.attachmentUrl,
  });

  final int id;
  final WaslSupportSender sender;
  final DateTime? createdAt;
  final String? body;
  final String? attachmentUrl;

  bool get isMine => sender == WaslSupportSender.user;

  factory WaslSupportMessage.fromJson(Map<String, dynamic> json) {
    return WaslSupportMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: WaslSupportSender.fromWire(json['senderRole']?.toString()),
      body: json['body']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString())?.toLocal(),
    );
  }
}
