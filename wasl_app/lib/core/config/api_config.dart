import 'package:shared_preferences/shared_preferences.dart';

class WaslApiConfig {
  // 📱 Real phone via USB cable → localhost, tunnelled to the laptop with
  //    `adb reverse tcp:3000 tcp:3000` (no WiFi/firewall needed).
  static const String baseUrl = 'http://localhost:3000';
  // 🖥️ Android emulator only → 'http://10.0.2.2:3000'
  // 📶 Phone over WiFi → the laptop's LAN IP, e.g. 'http://192.168.1.7:3000'
  // ☁️ Production → 'https://wasl-backend-production-97ef.up.railway.app'

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
