import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wasl_app/core/config/api_config.dart';

/// Client for the server-side WhatsApp OTP flow.
///
/// This is the production-ready path that replaces client-only Firebase phone
/// auth: the backend generates, delivers (via WhatsApp Cloud API), and verifies
/// the code, then issues the JWT. The app never trusts a client-asserted
/// identity. Kept as a standalone service so authentication is not coupled to
/// any single OTP provider.
class WhatsappOtpService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  /// Request a code to be sent to [phone] over WhatsApp.
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final url = Uri.parse('$baseUrl/auth/otp/send');
    try {
      final response = await http
          .post(
            url,
            headers: WaslApiConfig.jsonHeaders,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'تعذّر إرسال رمز التحقق',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Verify [code] for [phone]. On success the server returns whether an
  /// account already exists (`registered`) and, if so, a JWT `token` + `user`.
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final url = Uri.parse('$baseUrl/auth/otp/verify');
    try {
      final response = await http
          .post(
            url,
            headers: WaslApiConfig.jsonHeaders,
            body: jsonEncode({'phone': phone, 'code': code}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'رمز التحقق غير صحيح',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }
}
