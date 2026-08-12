import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class WaslApiConfig {
  /// 🎯 عنوان السيرفر.
  ///
  /// ⚠️ `Platform.isAndroid` بيبقى true على **الموبايل الحقيقي** زي المحاكي
  /// بالظبط، فما ينفعش نفرّق بيهم بالطريقة دي — النسخة اللي كانت بترجّع
  /// `10.0.2.2` لكل أندرويد كانت بتكسر الاتصال على الموبايل الحقيقي، لأن
  /// `10.0.2.2` ده عنوان المحاكي وحده.
  ///
  /// `localhost` بيشتغل على **الاتنين** طالما عامل:
  ///     adb reverse tcp:3000 tcp:3000
  /// وده أبسط وأضمن من التخمين.
  ///
  /// للنشر أو للواي فاي، مرّر العنوان وقت البناء من غير ما تعدّل الملف:
  ///     flutter run --dart-define=API_BASE_URL=https://api.example.com
  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl =>
      _override.isNotEmpty
          ? _override
          : (kReleaseMode ? 'https://api.wasl.invalid' : 'http://localhost:3000');

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
