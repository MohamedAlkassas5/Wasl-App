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

  /// هل نسخة الإصدار دي متبنية صح؟
  ///
  /// قبل كده كان فيه عنوان افتراضي للإصدار (`https://api.wasl.invalid`) —
  /// دومين مش موجود. نسخة تتبني من غير الـ define كانت تتثبّت وتفتح عادي وكل
  /// طلب فيها يفشل برسالة «تعذّر الاتصال»، من غير أي دليل إن السبب خطأ في
  /// البناء مش خطأ في الشبكة.
  ///
  /// رمي الاستثناء من `baseUrl` وحده ما كانش هيحل ده: كل الـ services بتلفّ
  /// نداءاتها في try/catch وبتحوّل أي استثناء لرسالة عربية، يعني الخطأ كان
  /// هيتبلع بنفس الطريقة بالظبط. عشان كده الفحص بيتنادى من `main()` قبل
  /// `runApp` — نسخة غلط بتقف عند التشغيل الأول وما تقدرش تعدّي على أي
  /// تجربة، مهما كانت سريعة.
  static bool get isReleaseMisconfigured => kReleaseMode && _override.isEmpty;

  /// الرسالة اللي بتتعرض لو النسخة اتبنت من غير عنوان سيرفر.
  static const String misconfiguredMessage =
      'API_BASE_URL is required for release builds.\n\n'
      'flutter build appbundle --dart-define=API_BASE_URL=https://<your-api-host>';

  static String get baseUrl =>
      _override.isNotEmpty ? _override : 'http://localhost:3000';

  static const Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // 🔐 `authHeaders()` اتشالت. كانت بتقرا التوكن وتحطه في الهيدر، وكل شاشة
  // بتناديها لوحدها — وده كان ماشي وقت ما التوكن كان بيعيش ٣٠ يوم وما بيتغيرش.
  // دلوقتي التوكن ١٥ دقيقة وبيتجدد لوحده، فالمكان الوحيد اللي بيركّب الهيدر
  // بقى `WaslAuthedHttp`، عشان أي طلب يقابل 401 يعرف يجدّد ويعيد المحاولة.
  // لو رجّعناها هنا تاني، هتبقى طريق تاني للمصادقة من غير تجديد.
}
