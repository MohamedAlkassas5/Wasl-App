import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaslApiConfig {
  /// 🎯 عنوان السيرفر الرئيسي (ديناميكي)
  /// 🖥️ Android emulator → 'http://10.0.2.2:3000'
  /// 📱 Real phone (USB via ADB) / Web / iOS → 'http://localhost:3000'
  /// 📶 Phone over WiFi → 'http://192.168.1.X:3000' (يمكنك تبديله عند الحاجة)
  static String get baseUrl {
    // إذا كان التطبيق يعمل داخل محاكي Android
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    // للموبايل الحقيقي المتصل بكابل USB بعد أمر: adb reverse tcp:3000 tcp:3000
    // أو المحاكي على iOS/Web
    return 'http://localhost:3000';
  }

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