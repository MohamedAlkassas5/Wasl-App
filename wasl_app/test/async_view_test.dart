import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:wasl_app/core/ui/wasl_async.dart';
import 'package:wasl_app/core/ui/wasl_failure.dart';
import 'package:wasl_app/core/widgets/wasl_async_view.dart';

/// الحالات اللي كل شاشة كانت بتعيد كتابتها بطريقتها.
///
/// أهم واحدة فيهم هي الفشل: قبل كده الشاشات كانت بتوقف التحميل وتسيب القايمة
/// فاضية، فالمستخدم يشوف «لا توجد طلبات» وهو عنده طلب شغال — إعلان كذب عن
/// حالة الشبكة. الاختبارات دي بتثبّت الفرق بين «مفيش بيانات» و«مقدرناش نجيب
/// البيانات».
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      );

  group('WaslAsyncView', () {
    testWidgets('يعرض مؤشر تحميل وهو بيحمّل', (tester) async {
      await tester.pumpWidget(host(
        WaslAsyncView<List<String>>(
          state: const WaslAsync.loading(),
          builder: (_, value) => Text('عناصر: ${value.length}'),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('عناصر'), findsNothing);
    });

    testWidgets('يعرض البيانات لما توصل', (tester) async {
      await tester.pumpWidget(host(
        WaslAsyncView<List<String>>(
          state: const WaslAsync.data(['طلب']),
          builder: (_, value) => Text('عناصر: ${value.length}'),
        ),
      ));

      expect(find.text('عناصر: 1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('يعرض حالة الفراغ بالنص المتفق عليه', (tester) async {
      await tester.pumpWidget(host(
        WaslAsyncView<List<String>>(
          state: const WaslAsync.data([]),
          isEmpty: (value) => value.isEmpty,
          builder: (_, __) => const Text('مالوش لازمة'),
        ),
      ));

      expect(find.text('لا توجد طلبات حالياً'), findsOneWidget);
      expect(find.text('مالوش لازمة'), findsNothing);
    });

    testWidgets('يفرّق بين الفراغ والفشل', (tester) async {
      await tester.pumpWidget(host(
        WaslAsyncView<List<String>>(
          state: WaslAsync.failure(WaslFailure.from(const SocketException(''))),
          isEmpty: (value) => value.isEmpty,
          builder: (_, __) => const Text('مالوش لازمة'),
        ),
      ));

      // دي بالظبط النقطة: فشل الشبكة **مش** «مفيش طلبات».
      expect(find.text('لا توجد طلبات حالياً'), findsNothing);
      expect(find.textContaining('تعذّر الاتصال بالإنترنت'), findsOneWidget);
    });

    testWidgets('يعرض زرار إعادة المحاولة وينفّذه', (tester) async {
      var retries = 0;

      await tester.pumpWidget(host(
        WaslAsyncView<List<String>>(
          state: WaslAsync.failure(WaslFailure.from(const SocketException(''))),
          onRetry: () => retries++,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ));

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('مايعرضش إعادة المحاولة لفشل مالوش فايدة يتعاد', (tester) async {
      await tester.pumpWidget(host(
        WaslAsyncView<List<String>>(
          state: const WaslAsync.failure(WaslFailure(
            kind: WaslFailureKind.unauthorized,
            message: 'انتهت الجلسة، سجّل دخولك مرة أخرى',
          )),
          onRetry: () {},
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ));

      // زرار بيفشل كل مرة أسوأ من مفيش زرار.
      expect(find.text('إعادة المحاولة'), findsNothing);
      expect(find.text('انتهت الجلسة، سجّل دخولك مرة أخرى'), findsOneWidget);
    });

    testWidgets('مابيوصلش نص استثناء إنجليزي للمستخدم', (tester) async {
      await tester.pumpWidget(host(
        WaslAsyncView<List<String>>(
          state: WaslAsync.failure(
            WaslFailure.from(Exception('SocketException: host lookup failed')),
          ),
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ));

      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('حدث خطأ غير متوقع، حاول مرة أخرى'), findsOneWidget);
    });
  });

  group('WaslOfflineBanner', () {
    testWidgets('مايظهرش والاتصال شغال', (tester) async {
      await tester.pumpWidget(host(const WaslOfflineBanner(visible: false)));

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    });

    testWidgets('يظهر لما الطلب يفشل بسبب الشبكة', (tester) async {
      await tester.pumpWidget(host(const WaslOfflineBanner(visible: true)));

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    });
  });

  group('WaslFailure', () {
    test('بيقرا انقطاع الشبكة من فشل الطلب نفسه — من غير مكتبة خارجية', () {
      expect(WaslFailure.from(const SocketException('')).isOffline, isTrue);
      expect(
        WaslFailure.from(http.ClientException('failed')).isOffline,
        isTrue,
      );
    });

    test('بيميّز انتهاء المهلة', () {
      final failure = WaslFailure.from(TimeoutException('slow'));

      expect(failure.kind, WaslFailureKind.timeout);
      expect(failure.isRetryable, isTrue);
    });

    test('بيرفض رسالة السيرفر الإنجليزية ويحط عربي بدالها', () {
      final failure = WaslFailure.fromResponse(500,
          serverMessage: 'Internal server error');

      expect(failure.message, 'الخدمة غير متاحة مؤقتاً، حاول بعد قليل');
    });

    test('بيستخدم رسالة السيرفر العربية زي ما هي', () {
      final failure = WaslFailure.fromResponse(400,
          serverMessage: 'المنطقة المختارة غير مدعومة');

      expect(failure.message, 'المنطقة المختارة غير مدعومة');
    });

    test('مابيعرضش كود الحالة للمستخدم', () {
      final failure = WaslFailure.fromResponse(503);

      expect(failure.message.contains('503'), isFalse);
      expect(failure.technicalDetail, 'HTTP 503');
    });

    test('401 مش قابل لإعادة المحاولة', () {
      expect(WaslFailure.fromResponse(401).isRetryable, isFalse);
    });
  });
}
