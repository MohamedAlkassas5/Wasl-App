import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/services/device_token_service.dart';
import 'package:wasl_app/services/push_service.dart';

/// CP-C — طرف التطبيق في الإشعارات.
///
/// Firebase نفسها مش بتتختبر هنا: `FirebaseMessaging` بتحتاج قناة native
/// وما ينفعش تتزيّف بشكل معقول في unit test. اللي بيتختبر هو الجزء اللي
/// فيه قرارات فعلاً — تسجيل الجهاز عند السيرفر، منع التكرار، وقراءة الـ
/// `data` اللي السيرفر بيبعتها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late List<String> bodies;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
      'user_id': 20,
    });
    calls = [];
    bodies = [];
    WaslAuthedHttp.onSignedOut = null;
  });

  void serverReturns({int status = 201}) {
    WaslAuthedHttp.instance = WaslAuthedHttp(
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        bodies.add(request.body);
        return http.Response(
          jsonEncode({'success': true}),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  group('تسجيل الجهاز', () {
    test('بيبعت التوكن والمنصة للمسار الصح', () async {
      serverReturns();
      final devices = WaslDeviceTokenService(platform: 'android');

      final sent = await devices.register('a-very-long-fcm-token-value');

      expect(sent, true);
      expect(calls.single, 'POST /devices/token');
      expect(jsonDecode(bodies.single), {
        'token': 'a-very-long-fcm-token-value',
        'platform': 'android',
      });
    });

    test('مفيش userId في الجسم — السيرفر بياخده من التوكن', () async {
      serverReturns();

      await WaslDeviceTokenService(platform: 'android')
          .register('a-very-long-fcm-token-value');

      // لو التطبيق بعت userId كان أي حد يقدر يسجّل جهازه على حساب غيره
      // ويستقبل إشعارات طلباته.
      expect(jsonDecode(bodies.single).containsKey('userId'), false);
    });

    test('نفس التوكن ما بيتسجّلش مرتين', () async {
      serverReturns();
      final devices = WaslDeviceTokenService(platform: 'android');

      final first = await devices.register('a-very-long-fcm-token-value');
      final second = await devices.register('a-very-long-fcm-token-value');

      expect(first, true);
      expect(second, false, reason: 'التكرار المفروض يتمنع');
      expect(calls.length, 1);
    });

    test('توكن جديد بيتسجّل حتى لو قبله كان فيه واحد', () async {
      serverReturns();
      final devices = WaslDeviceTokenService(platform: 'android');

      await devices.register('a-very-long-fcm-token-value');
      await devices.register('a-different-long-fcm-token');

      expect(calls.length, 2);
      expect(devices.registeredToken, 'a-different-long-fcm-token');
    });

    test('فشل السيرفر ما بيسجّلش التوكن كأنه اتبعت', () async {
      serverReturns(status: 500);
      final devices = WaslDeviceTokenService(platform: 'android');

      expect(await devices.register('a-very-long-fcm-token-value'), false);
      expect(devices.registeredToken, isNull);

      // ولأنه ما اتسجّلش، المحاولة الجاية بتضرب فعلاً بدل ما تتمنع.
      serverReturns();
      expect(await devices.register('a-very-long-fcm-token-value'), true);
    });

    test('توكن فاضي ما بيتبعتش أصلاً', () async {
      serverReturns();

      expect(await WaslDeviceTokenService(platform: 'android').register(''),
          false);
      expect(calls, isEmpty);
    });

    test('عطل شبكة بيرجّع false مش استثناء', () async {
      WaslAuthedHttp.instance = WaslAuthedHttp(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );

      expect(
        await WaslDeviceTokenService(platform: 'android')
            .register('a-very-long-fcm-token-value'),
        false,
      );
    });
  });

  group('إلغاء التسجيل عند الخروج', () {
    test('بيضرب DELETE بالتوكن', () async {
      serverReturns(status: 200);
      final devices = WaslDeviceTokenService(platform: 'android');

      final removed = await devices.unregister('a-very-long-fcm-token-value');

      expect(removed, true);
      expect(calls.single, 'DELETE /devices/token');
      expect(jsonDecode(bodies.single), {
        'token': 'a-very-long-fcm-token-value',
      });
    });

    test('بينسى التسجيل حتى لو السيرفر رفض', () async {
      serverReturns(status: 500);
      final devices = WaslDeviceTokenService(platform: 'android');
      await devices.register('a-very-long-fcm-token-value');
      devices.forget();

      await devices.unregister('a-very-long-fcm-token-value');

      // لازم ينسى محلياً: اللي هيسجّل دخول بعد كده على نفس الموبايل المفروض
      // يسجّل جهازه من الأول، مش يتمنع بحارس التكرار.
      expect(devices.registeredToken, isNull);
    });
  });

  group('قراءة الـ data اللي السيرفر بيبعتها', () {
    test('بتقرا النوع ورقم الطلب', () {
      final tap = WaslPushTap.fromData({'kind': 'order_offer', 'orderId': '7'});

      expect(tap, isNotNull);
      expect(tap!.kind, 'order_offer');
      expect(tap.orderId, 7);
      expect(tap.isDriverOffer, true);
    });

    test('تحديث طلب مش عرض شغل', () {
      final tap =
          WaslPushTap.fromData({'kind': 'order_update', 'orderId': '12'});

      expect(tap!.isDriverOffer, false);
      expect(tap.orderId, 12);
    });

    test('من غير kind مفيش توجيه', () {
      expect(WaslPushTap.fromData({'orderId': '7'}), isNull);
      expect(WaslPushTap.fromData({}), isNull);
    });

    test('kind من غير orderId لسه مفهوم', () {
      // `offer_expired` بتيجي من غير رقم طلب أحياناً.
      final tap = WaslPushTap.fromData({'kind': 'offer_expired'});

      expect(tap, isNotNull);
      expect(tap!.orderId, isNull);
    });
  });
}

/// استثناء شبكة مبسّط — `MockClient` بيرمي اللي نديهوله.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: failed';
}
