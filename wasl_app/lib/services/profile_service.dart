import 'dart:async';
import 'dart:convert';
import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/config/api_config.dart';

/// The caller's own account.
///
/// Every call here resolves the user from the token — there is no "fetch user
/// by id/phone" variant, deliberately, so one account can never read another's.
class ProfileService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  /// Profile including the saved delivery area.
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await WaslAuthedHttp.instance
          .get(Uri.parse('$baseUrl/users/me'))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'تعذّر تحميل بيانات حسابك'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Move the account to a different approved area. The server rejects any
  /// area that isn't currently active.
  Future<Map<String, dynamic>> updateArea(int zoneId) =>
      _patch('/users/me/area', {'customerZoneId': zoneId}, 'تعذّر تحديث المنطقة');

  /// Edit name and/or email.
  ///
  /// Only the fields actually being changed are sent — the server treats an
  /// absent field as "leave it alone", and an empty [email] as "remove it".
  /// The phone number is not editable here: it is the login identifier and
  /// changing it needs a fresh WhatsApp verification.
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
  }) =>
      _patch(
        '/users/me',
        {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
        },
        'تعذّر حفظ البيانات',
      );

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
    String fallbackError,
  ) async {
    try {
      final response = await WaslAuthedHttp.instance
          .patch(
            Uri.parse('$baseUrl$path'),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': _messageOf(decoded) ?? fallbackError};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Nest returns `message` as a string, or a list when validation fails.
  String? _messageOf(Map<String, dynamic> body) {
    final message = body['message'];
    if (message is String) return message;
    if (message is List && message.isNotEmpty) return message.first.toString();
    return null;
  }
}
