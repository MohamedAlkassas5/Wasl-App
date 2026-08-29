import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_app/core/ui/wasl_submit_guard.dart';

/// منع الضغط المزدوج على العمليات اللي بتحرّك فلوس أو حالة طلب.
///
/// السيرفر محمي أصلاً بقيد UNIQUE على `wallet_transactions.reference`، فمستحيل
/// يتحصّل مرتين. لكن الاعتماد على ده وحده معناه إن المستخدم بيشوف رسالة خطأ
/// على ضغطة تانية شرعية — الحارس بيمنع الطلب التاني من أصله.
void main() {
  testWidgets('بينفّذ العملية مرة واحدة مهما اتضغط', (tester) async {
    var calls = 0;
    final completer = Completer<void>();

    await tester.pumpWidget(_GuardHost(
      onPressed: (state) => state.guardedSubmit(() async {
        calls++;
        await completer.future;
      }),
    ));

    // تلات ضغطات ورا بعض والعملية الأولى لسه شغالة.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(calls, 1);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('يسمح بعملية جديدة بعد ما الأولى تخلص', (tester) async {
    var calls = 0;

    await tester.pumpWidget(_GuardHost(
      onPressed: (state) => state.guardedSubmit(() async => calls++),
    ));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // المنع مؤقت بس — مش قفل دايم.
    expect(calls, 2);
  });

  testWidgets('isSubmitting بيسمح بتعطيل الزرار', (tester) async {
    final completer = Completer<void>();

    await tester.pumpWidget(_GuardHost(
      onPressed: (state) => state.guardedSubmit(() => completer.future),
    ));

    expect(_GuardHostState.latest!.isSubmitting, isFalse);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(_GuardHostState.latest!.isSubmitting, isTrue);

    completer.complete();
    await tester.pumpAndSettle();

    expect(_GuardHostState.latest!.isSubmitting, isFalse);
  });

  testWidgets('بيفك الحارس حتى لو العملية رمت استثناء', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(_GuardHost(
      onPressed: (state) => state.guardedSubmit(() async {
        attempts++;
        throw Exception('فشل');
      }),
    ));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // لو الحارس فضل مقفول بعد فشل، الزرار كان هيبقى ميت لطول عمر الشاشة.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(attempts, 2);
  });

  group('WaslSubmitLatch', _latchTests);
}

/// نفس الحارس من غير `State` — للشاشات اللي لسه `StatelessWidget`.
void _latchTests() {
  test('بينفّذ مرة واحدة مهما اتنادى', () async {
    final latch = WaslSubmitLatch();
    final completer = Completer<void>();
    var calls = 0;

    final first = latch.run(() async {
      calls++;
      await completer.future;
    });
    final second = await latch.run(() async => calls++);

    expect(second, isFalse); // اتمنعت
    expect(calls, 1);

    completer.complete();
    await first;
  });

  test('بيفتح تاني بعد ما العملية تخلص', () async {
    final latch = WaslSubmitLatch();
    var calls = 0;

    await latch.run(() async => calls++);
    await latch.run(() async => calls++);

    expect(calls, 2);
  });

  test('بيفك القفل حتى لو رمت استثناء', () async {
    final latch = WaslSubmitLatch();

    await expectLater(
      latch.run(() async => throw Exception('فشل')),
      throwsException,
    );

    // لو فضل مقفول، الزرار كان هيموت لطول عمر الشاشة.
    expect(latch.isBusy, isFalse);
    expect(await latch.run(() async {}), isTrue);
  });
}

/// شاشة صغيرة بتستخدم الحارس، عشان نختبره من غير ما نشغّل شاشة حقيقية.
class _GuardHost extends StatefulWidget {
  const _GuardHost({required this.onPressed});

  final Future<void> Function(_GuardHostState state) onPressed;

  @override
  State<_GuardHost> createState() => _GuardHostState();
}

class _GuardHostState extends State<_GuardHost>
    with WaslSubmitGuard<_GuardHost> {
  static _GuardHostState? latest;

  @override
  Widget build(BuildContext context) {
    latest = this;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              // الاستثناءات بتتبلع هنا عشان الاختبار يقيس الحارس نفسه، مش
              // معالجة الأخطاء في الشاشة.
              try {
                await widget.onPressed(this);
              } catch (_) {
                // مقصود.
              }
            },
            child: const Text('تنفيذ'),
          ),
        ),
      ),
    );
  }
}
