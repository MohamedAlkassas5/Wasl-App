import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/widgets/wasl_cancel_dialogs.dart';
import 'package:wasl_app/services/cancellation_models.dart';
import 'package:wasl_app/services/cancellation_service.dart';

/// CP-B2 — عميل الإلغاء.
///
/// الاختبارات دي **مش** بتثبت قاعدة الغرامة: دي على السيرفر وليها اختباراتها
/// هناك (`cancellation-penalty.spec.ts`). اللي بتثبته هنا إن التطبيق:
///
///  - بيضرب على المسار الصح بالجسم الصح،
///  - وما بيبعتش مبلغ أبداً — الفلوس قرار السيرفر،
///  - وبيقرا نتيجة السيرفر زي ما هي بدل ما يحسب حاجة من عنده،
///  - وبيقول للكابتن الحقيقة بتاعة Q-B3 قبل ما يوافق.
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

  /// سيرفر مزيّف بيسجّل كل طلب وبيرد بالـ payload المطلوب.
  void serverReturns(Map<String, dynamic> payload, {int status = 201}) {
    WaslAuthedHttp.instance = WaslAuthedHttp(
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        bodies.add(request.body);
        return http.Response(
          jsonEncode(payload),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  group('الكابتن بيوافق على طلب العميل (Q-B3)', () {
    test('بيضرب على مسار الموافقة وبيقرا إن مفيش غرامة', () async {
      serverReturns({
        'success': true,
        'cancelled': true,
        'repeated': false,
        'penalty': 0,
      });

      final result =
          await WaslCancellationService().approveCustomerRequest(7);

      expect(calls.single, 'POST /orders/7/cancellation-request/approve');
      expect(result['success'], true);
      expect(result['cancelled'], true);
      expect(result['penalty'], 0);
    });

    test('ما بيبعتش أي مبلغ ولا سبب في جسم الطلب', () async {
      serverReturns({'success': true, 'cancelled': true, 'penalty': 0});

      await WaslCancellationService().approveCustomerRequest(7);

      // جسم فاضي تماماً: التطبيق مالوش رأي في الفلوس، والسيرفر بيحسبها من
      // الرسوم المجمّدة على الطلب.
      expect(bodies.single, isEmpty);
    });
  });

  group('الكابتن بيلغي من نفسه', () {
    test('بيبعت السبب وبيرجّع الغرامة زي ما السيرفر قالها', () async {
      serverReturns({
        'success': true,
        'cancelled': true,
        'repeated': false,
        'penalty': 8,
      });

      final result = await WaslCancellationService()
          .driverCancel(7, reason: 'العربية اتعطلت');

      expect(calls.single, 'POST /orders/7/driver-cancel');
      expect(jsonDecode(bodies.single), {'reason': 'العربية اتعطلت'});
      expect(result['penalty'], 8);
    });

    test('الغرامة بتتقرا حتى لو رجعت كنص من Postgres', () async {
      serverReturns({'success': true, 'cancelled': true, 'penalty': '8.00'});

      final result =
          await WaslCancellationService().driverCancel(7, reason: 'سبب');

      expect(result['penalty'], 8.0);
    });
  });

  group('الرفض', () {
    test('من غير سبب بيبعت جسم فاضي بدل مفتاح فاضي', () async {
      serverReturns({'success': true, 'cancelled': false, 'penalty': 0});

      await WaslCancellationService().rejectCustomerRequest(7);

      expect(calls.single, 'POST /orders/7/cancellation-request/reject');
      // مفتاح `decisionReason` فاضي كان هيترفض من الـ validator (١ حرف على
      // الأقل)، فالأفضل ما يتبعتش أصلاً.
      expect(bodies.single, isEmpty);
    });

    test('بالسبب بيبعته', () async {
      serverReturns({'success': true, 'cancelled': false, 'penalty': 0});

      await WaslCancellationService()
          .rejectCustomerRequest(7, decisionReason: 'أنا قريب أوصل');

      expect(jsonDecode(bodies.single), {'decisionReason': 'أنا قريب أوصل'});
    });
  });

  group('العميل بيطلب الإلغاء', () {
    test('بيبعت السبب على المسار الصح', () async {
      serverReturns({'success': true, 'repeated': false});

      await WaslCancellationService()
          .requestCancellation(7, reason: 'اتأخر أوي');

      expect(calls.single, 'POST /orders/7/cancellation-request');
      expect(jsonDecode(bodies.single), {'reason': 'اتأخر أوي'});
    });

    test('فشل السيرفر بيرجع رسالته مش استثناء', () async {
      serverReturns({'message': 'لا يمكن إلغاء الطلب في هذه المرحلة'},
          status: 400);

      final result =
          await WaslCancellationService().requestCancellation(7, reason: 'سبب');

      expect(result['success'], false);
      expect(result['message'], 'لا يمكن إلغاء الطلب في هذه المرحلة');
    });
  });

  group('قراءة السجل', () {
    test('بيرجّع المعلّق بس من كل السجلات', () async {
      serverReturns({
        'success': true,
        'requests': [
          {
            'id': 1,
            'orderId': 7,
            'requestedByRole': 'customer',
            'reason': 'قديم',
            'status': 'rejected',
          },
          {
            'id': 2,
            'orderId': 7,
            'requestedByRole': 'customer',
            'reason': 'جديد',
            'status': 'pending',
          },
        ],
      }, status: 200);

      final pending = await WaslCancellationService().pendingRequestFor(7);

      expect(pending, isNotNull);
      expect(pending!.id, 2);
      expect(pending.reason, 'جديد');
    });

    test('مفيش معلّق بيرجّع null', () async {
      serverReturns({
        'success': true,
        'requests': [
          {
            'id': 1,
            'orderId': 7,
            'requestedByRole': 'customer',
            'reason': 'قديم',
            'status': 'rejected',
          },
        ],
      }, status: 200);

      expect(await WaslCancellationService().pendingRequestFor(7), isNull);
    });
  });

  group('موديل السجل', () {
    WaslCancellation build(Map<String, dynamic> overrides) =>
        WaslCancellation.fromJson({
          'id': 1,
          'orderId': 7,
          'requestedBy': 9,
          'requestedByRole': 'customer',
          'reason': 'سبب',
          'status': 'approved',
          ...overrides,
        });

    test('الموافقة على طلب العميل: مفيش خصم ومفيش اعتراض', () {
      // ده شكل Q-B3 في البيانات: مبلغ صفر **ومن غير مرجع**.
      final record = build({'penaltyAmount': 0, 'penaltyReference': null});

      expect(record.wasCharged, false);
      expect(record.canAppeal, false);
    });

    test('إلغاء الكابتن: فيه خصم فيبقى فيه حق اعتراض', () {
      final record = build({
        'penaltyAmount': '8.00',
        'penaltyReference': 'order-7-cancel-penalty',
      });

      expect(record.wasCharged, true);
      expect(record.penaltyAmount, 8.0);
      expect(record.canAppeal, true);
    });

    test('اعتراض اتقدّم خلاص ما يتقدّمش تاني', () {
      final record = build({
        'penaltyAmount': 8,
        'penaltyReference': 'order-7-cancel-penalty',
        'appealStatus': 'pending',
      });

      expect(record.canAppeal, false);
      expect(record.appealIsOpen, true);
    });
  });

  group('حوار الموافقة بيقول القاعدة للكابتن', () {
    testWidgets('بيقول صراحة إن مفيش غرامة', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showWaslConfirmDialog(
                context,
                title: 'الموافقة على إلغاء الطلب',
                message: 'العميل طلب إلغاء الطلب.',
                highlight:
                    'مفيش أي غرامة عليك — الموافقة على طلب العميل مجانية.',
                confirmLabel: 'موافقة وإلغاء الطلب',
              ),
              child: const Text('افتح'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      expect(find.textContaining('مفيش أي غرامة عليك'), findsOneWidget);
    });

    testWidgets('حوار السبب بيرفض سبب قصير قبل ما يبعت', (tester) async {
      String? captured = 'not-called';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                captured = await showWaslReasonDialog(
                  context,
                  title: 'إلغاء الطلب',
                  message: 'اكتب السبب',
                  confirmLabel: 'تأكيد',
                );
              },
              child: const Text('افتح'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // سبب من حرفين: السيرفر بيطلب ٣ على الأقل، والحوار بيمسكها قبله.
      await tester.enterText(find.byType(TextFormField), 'اب');
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      expect(find.textContaining('٣ حروف على الأقل'), findsOneWidget);
      expect(captured, 'not-called', reason: 'ما المفروضش يقفل الحوار');
    });
  });
}
