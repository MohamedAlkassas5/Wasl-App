import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/services/wallet_service.dart';

/// عميل شحن المحفظة.
///
/// الاختبارات دي **مش** بتثبت إن الفلوس بتتحرك مرة واحدة — ده قرار السيرفر
/// وليه اختباراته هناك (`wallet-topup.spec.ts` و`verify-concurrency.js`).
/// اللي بتثبته هنا إن التطبيق:
///
///  - بيضرب على المسار الصح بالحقول الصح، والصورة معاه،
///  - وما بيبعتش رقم كابتن مع أي طلب محفظة — المحفظة بتاعة صاحب التوكن،
///  - وبيقرا رد السيرفر زي ما هو بدل ما يخترع رسالة نجاح،
///  - وبيفهم إن `pending` مش شحن.
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

  void serverReturns(dynamic payload, {int status = 200}) {
    WaslAuthedHttp.instance = WaslAuthedHttp(
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        // `request.body` بيفك الترميز UTF-8، وده بيرمي استثناء على بايتات
        // الصورة الخام جوه الـ multipart. `latin1` بتخلي كل بايت حرف.
        bodies.add(latin1.decode(request.bodyBytes));
        return http.Response(
          jsonEncode(payload),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  /// صورة تحويل وهمية على القرص.
  ///
  /// لازم تكون **صورة حقيقية** (PNG بتوقيعه الصحيح): التطبيق بقى بيقرا بايتات
  /// الملف ويرفضه قبل ما يبعته لو مش صورة — شوف `image_upload_test.dart`.
  /// الملف النصي اللي كان هنا قبل كده بقى بيترفض، وده السلوك المطلوب.
  Future<File> fakeProof() async {
    final dir = await Directory.systemTemp.createTemp('wasl-proof');
    final file = File('${dir.path}/proof.png');
    await file.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
        'hKmMIQAAAABJRU5ErkJggg=='));
    return file;
  }

  group('تقديم طلب الشحن', () {
    test('بيبعت المبلغ والطريقة والصورة على مسار طلبات الشحن', () async {
      serverReturns({
        'success': true,
        'message': 'تم إرسال طلب الشحن للمراجعة.',
        'request': {
          'id': 5,
          'amount': '100.00',
          'method': 'vodafone_cash',
          'status': 'pending',
          'createdAt': '2026-08-31T09:00:00.000Z',
        },
      }, status: 201);

      final result = await WaslWalletService().submitTopUp(
        amount: 100,
        method: WaslTopUpMethod.vodafoneCash,
        proofImage: await fakeProof(),
        senderReference: '01098765432',
      );

      expect(result['success'], isTrue);
      expect(calls.single, 'POST /wallet/topup-requests');
      expect(bodies.single, contains('name="amount"'));
      expect(bodies.single, contains('100'));
      expect(bodies.single, contains('vodafone_cash'));
      expect(bodies.single, contains('01098765432'));
      // الصورة نفسها جوه الـ multipart تحت الاسم اللي السيرفر بيستقبله.
      expect(bodies.single, contains('name="proofImage"'));
      // والنوع المعلَن بقى صح — ده اللي كان بيخلي السيرفر يرفض كل صورة.
      expect(bodies.single, contains('content-type: image/png'));
    });

    test('ما بيبعتش رقم كابتن — الملكية من التوكن', () async {
      serverReturns({'success': true, 'request': {}}, status: 201);

      await WaslWalletService().submitTopUp(
        amount: 100,
        method: WaslTopUpMethod.instapay,
        proofImage: await fakeProof(),
      );

      expect(bodies.single, isNot(contains('driverId')));
      expect(bodies.single, isNot(contains('userId')));
      expect(calls.single, isNot(contains('20')));
    });

    test('الطلب بيرجع قيد المراجعة، مش مشحون', () async {
      serverReturns({
        'success': true,
        'message': 'تم إرسال طلب الشحن للمراجعة.',
        'request': {
          'id': 9,
          'amount': '100.00',
          'method': 'instapay',
          'status': 'pending',
        },
      }, status: 201);

      final result = await WaslWalletService().submitTopUp(
        amount: 100,
        method: WaslTopUpMethod.instapay,
        proofImage: await fakeProof(),
      );

      final request = result['request'] as WaslTopUpRequest;
      expect(request.status, WaslTopUpStatus.pending);
      expect(request.isPending, isTrue);
      // الرسالة اللي بتتعرض للكابتن هي رسالة السيرفر، مش رسالة نجاح محلية.
      expect(result['message'], contains('للمراجعة'));
      expect(result['message'], isNot(contains('تم شحن')));
    });

    test('بيرجّع رسالة السيرفر لما يرفض الطلب', () async {
      serverReturns({'message': 'يجب إرفاق صورة إيصال التحويل'}, status: 400);

      final result = await WaslWalletService().submitTopUp(
        amount: 100,
        method: WaslTopUpMethod.vodafoneCash,
        proofImage: await fakeProof(),
      );

      expect(result['success'], isFalse);
      expect(result['message'], 'يجب إرفاق صورة إيصال التحويل');
    });
  });

  group('الرصيد', () {
    test('بيتقرا من مسار واحد من غير رقم كابتن', () async {
      serverReturns({
        'success': true,
        'balance': 100,
        'ledgerBalance': 100,
        'pendingTopUpCount': 0,
      });

      final result = await WaslWalletService().getSummary();

      expect(calls.single, 'GET /wallet/summary');
      expect(result['balance'], 100);
      // نفس الرقم اللي السجل بيقوله — الاتنين بيتكتبوا في نفس المعاملة.
      expect(result['ledgerBalance'], result['balance']);
    });

    test('بيفهم الرصيد لما يرجع نص من Postgres', () async {
      serverReturns({'success': true, 'balance': '142.50'});

      final result = await WaslWalletService().getSummary();

      expect(double.parse(result['balance'].toString()), 142.5);
    });

    test('بيقول إنه فشل بدل ما يخترع رصيد', () async {
      serverReturns({'message': 'حساب الكابتن غير موجود'}, status: 404);

      final result = await WaslWalletService().getSummary();

      expect(result['success'], isFalse);
      expect(result.containsKey('balance'), isFalse);
      expect(result['message'], 'حساب الكابتن غير موجود');
    });
  });

  group('سجل الطلبات', () {
    test('بيقرا الحالة وسبب الرفض', () async {
      serverReturns([
        {
          'id': 2,
          'amount': '250.00',
          'method': 'instapay',
          'status': 'rejected',
          'adminNote': 'صورة التحويل غير واضحة',
          'createdAt': '2026-08-30T10:00:00.000Z',
        },
        {
          'id': 1,
          'amount': '100.00',
          'method': 'vodafone_cash',
          'status': 'approved',
          'createdAt': '2026-08-29T10:00:00.000Z',
        },
      ]);

      final result = await WaslWalletService().getMyRequests();
      final requests = (result['requests'] as List).cast<WaslTopUpRequest>();

      expect(calls.single, 'GET /wallet/topup-requests/mine');
      expect(requests, hasLength(2));
      expect(requests[0].status, WaslTopUpStatus.rejected);
      expect(requests[0].adminNote, 'صورة التحويل غير واضحة');
      expect(requests[0].amount, 250);
      expect(requests[0].method, WaslTopUpMethod.instapay);
      expect(requests[1].status, WaslTopUpStatus.approved);
    });

    test('حركات المحفظة بترجع بالرصيد بعد كل حركة', () async {
      serverReturns([
        {
          'id': 3,
          'amount': '100.00',
          'type': 'topup',
          'balanceAfter': '100.00',
          'note': 'شحن محفظة معتمد (طلب #1)',
          'createdAt': '2026-08-29T10:00:00.000Z',
        },
      ]);

      final result = await WaslWalletService().getTransactions();
      final transactions =
          (result['transactions'] as List).cast<WaslWalletTransaction>();

      expect(calls.single, 'GET /wallet/transactions/mine');
      expect(transactions.single.isCredit, isTrue);
      expect(transactions.single.amount, 100);
      expect(transactions.single.balanceAfter, 100);
    });
  });

  group('الحالات', () {
    test('أي حالة مش معروفة بتتعامل كأنها قيد المراجعة، مش مقبولة', () {
      expect(WaslTopUpStatus.fromWire(null), WaslTopUpStatus.pending);
      expect(WaslTopUpStatus.fromWire(''), WaslTopUpStatus.pending);
      expect(WaslTopUpStatus.fromWire('whatever'), WaslTopUpStatus.pending);
      expect(WaslTopUpStatus.fromWire('approved'), WaslTopUpStatus.approved);
      expect(WaslTopUpStatus.fromWire('rejected'), WaslTopUpStatus.rejected);
    });

    test('قيم الطرق هي اللي السيرفر بيقبلها', () {
      expect(WaslTopUpMethod.vodafoneCash.wire, 'vodafone_cash');
      expect(WaslTopUpMethod.instapay.wire, 'instapay');
    });
  });
}
