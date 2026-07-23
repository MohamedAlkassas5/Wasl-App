import 'package:shared_preferences/shared_preferences.dart';

class WaslApiConfig {
  static const String baseUrl = 'http://10.0.2.2:3000';
  // static const String baseUrl = 'https://wasl-backend-production-97ef.up.railway.app';

  static const Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final headers = Map<String, String>.from(jsonHeaders);

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}
