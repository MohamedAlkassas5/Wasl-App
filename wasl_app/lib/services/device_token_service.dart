import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import 'package:wasl_app/core/config/api_config.dart';
import 'package:wasl_app/core/network/authed_http.dart';

/// تسجيل الجهاز عند السيرفر عشان يستقبل الإشعارات.
///
/// مفصولة عن `WaslPushService` عن قصد: دي الجزء اللي فيه منطق ويتختبر —
/// المسارات، الجسم، ومنع التكرار — من غير ما يحتاج Firebase شغّالة.
///
/// 🔐 مفيش `userId` في الجسم. صاحب التوكن هو صاحب الجلسة اللي بعتت الطلب،
/// والسيرفر بياخده من الـ JWT — يعني مستحيل حد يسجّل جهازه على حساب غيره.
class WaslDeviceTokenService {
  WaslDeviceTokenService({String? platform}) : _platform = platform;

  static const _timeout = Duration(seconds: 15);

  final String? _platform;

  /// آخر توكن اتسجّل بنجاح.
  ///
  /// ده حارس التكرار: `onTokenRefresh` بيضرب مع كل تشغيل أحياناً بنفس القيمة،
  /// والتسجيل بنفس التوكن تاني وتالت مجرد ضرب على السيرفر من غير فايدة.
  String? _registered;

  String? get registeredToken => _registered;

  String get _platformName {
    if (_platform != null) return _platform;
    // الـ enum على السيرفر فيه android و ios بس.
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// بيسجّل التوكن لو اتغيّر. بيرجّع `true` لو بعت فعلاً.
  Future<bool> register(String token) async {
    if (token.isEmpty) return false;
    if (token == _registered) return false; // اتسجّل قبل كده

    try {
      final response = await WaslAuthedHttp.instance
          .post(
            Uri.parse('${WaslApiConfig.baseUrl}/devices/token'),
            body: jsonEncode({'token': token, 'platform': _platformName}),
          )
          .timeout(_timeout);

      if (_ok(response)) {
        _registered = token;
        return true;
      }
      return false;
    } catch (_) {
      // الإشعارات مش شرط لاستخدام التطبيق. فشل التسجيل ما يوقفش حاجة —
      // أسوأ نتيجة إن الجهاز ما يستقبلش push لحد المحاولة الجاية.
      return false;
    }
  }

  /// بيشيل التوكن من السيرفر. لازم تتنادى **قبل** ما الجلسة تتمسح.
  ///
  /// السبب: المسار محمي بالتوكن، فلو مسحنا الجلسة الأول الطلب هيترفض
  /// والجهاز هيفضل مسجّل — يعني صاحب الحساب القديم يستقبل إشعارات على جهاز
  /// بقى مع حد تاني.
  Future<bool> unregister(String token) async {
    if (token.isEmpty) return false;

    try {
      final response = await WaslAuthedHttp.instance
          .delete(
            Uri.parse('${WaslApiConfig.baseUrl}/devices/token'),
            body: jsonEncode({'token': token}),
          )
          .timeout(_timeout);

      _registered = null;
      return _ok(response);
    } catch (_) {
      _registered = null;
      return false;
    }
  }

  /// بينسى آخر تسجيل من غير ما يكلّم السيرفر (للاختبار وتبديل الحساب).
  void forget() => _registered = null;

  bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;
}
