import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslMyOrdersScreen.dart';
import 'package:wasl_app/delivery_screen/WaslDriverMarketplaceScreen.dart';

/// ظهور الطلب فور إنشائه — الجهتين.
///
/// البلاغين اللي وراء الملف ده كانوا الاتنين في التطبيق، مش في السيرفر:
///
///  1. **العميل**: الطلب الجديد ما كانش بيظهر في «الطلبات الحالية» غير بعد ما
///     يقفل التطبيق ويفتحه من أول.
///  2. **الكابتن**: الطلب ما كانش بيوصله خالص، وبينتهي لوحده بعد ٦٠ ثانية.
///
/// السيرفر كان بيكتب صفوف `order_assignments` صح في الحالتين — التطبيق هو اللي
/// ما كانش بيسأل تاني.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// كل مسار اتطلب من السيرفر، بالترتيب.
  late List<String> calls;

  /// الطلبات اللي السيرفر «هيرجّعها» في النداء الجاي. متغيّرة عشان نقدر نحاكي
  /// طلب جديد بيظهر بعد ما الشاشة اتفتحت.
  late List<Map<String, dynamic>> serverOrders;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
      'user_id': 7,
    });
    calls = [];
    serverOrders = [];
    WaslAuthedHttp.onSignedOut = null;
    WaslAuthedHttp.instance = WaslAuthedHttp(
      client: MockClient((request) async {
        calls.add(request.url.path);
        return http.Response(
          jsonEncode(serverOrders),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  tearDown(() {
    WaslAuthedHttp.instance = WaslAuthedHttp();
  });

  Map<String, dynamic> order(int id, String status) => {
        'id': id,
        'customerId': 7,
        'status': status,
        'categoryType': 'سوبر ماركت',
        'customerName': 'عميل وصل',
        'deliveryAddressText': 'كوم حمادة',
        'itemsDescription': 'طلب اختبار',
        'itemsPrice': 0,
        'latitude': 30.7649,
        'longitude': 30.7003,
        'createdAt': '2026-09-01T00:00:00.000Z',
      };

  // ─── العميل ──────────────────────────────────────────────────────────────

  group('طلبات العميل', () {
    testWidgets(
      'فتح نسخة تانية من الشاشة وقفلها مابيوقّفش تحديث النسخة الأصلية',
      (tester) async {
        // 🐞 ده بالظبط اللي كان بيحصل: الـ shell بيحتفظ بنسخة حيّة طول الجلسة
        // جوّه IndexedStack، وشاشات تانية (الصيدلية، نجاح هاتلي/وصللي، دوسة
        // الإشعار) بتفتح نسخة تانية. لما كان فيه خانة واحدة بس للـ hook،
        // النسخة التانية كانت بتكتب مكانها في initState وتمسحها (null) في
        // dispose — فالنسخة الأصلية تفضل من غير تحديث لحد ما التطبيق يتقفل
        // ويتفتح تاني.
        serverOrders = [order(1, 'pending_offers')];

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(MaterialApp(
          navigatorKey: navigatorKey,
          home: const WaslMyOrdersScreen(),
        ));
        await tester.pump();

        expect(WaslMyOrdersScreen.liveRefreshHooks, 1,
            reason: 'نسخة الـ shell سجّلت نفسها');

        // نسخة تانية فوقها، زي اللي بتفتحها شاشة الصيدلية.
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const WaslMyOrdersScreen()),
        );
        await tester.pump();
        await tester.pump();

        expect(WaslMyOrdersScreen.liveRefreshHooks, 2,
            reason: 'النسختين مسجّلين مع بعض، مش واحدة بتشيل التانية');

        // اقفل النسخة التانية.
        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          WaslMyOrdersScreen.liveRefreshHooks,
          1,
          reason: 'النسخة الأصلية لسه بتستقبل التحديث بعد ما التانية اتقفلت',
        );
      },
    );

    testWidgets('refreshNow بيعيد قراءة الطلبات من السيرفر', (tester) async {
      // اللي بيتنادى بعد ما الطلب يتعمل بنجاح. من غيره الشاشة بتفضل عارضة
      // نتيجة أول تحميل من ساعة ما التطبيق اشتغل.
      await tester.pumpWidget(const MaterialApp(home: WaslMyOrdersScreen()));
      await tester.pump();

      final before = calls.where((p) => p.contains('/orders/customer/')).length;
      expect(before, 1);

      // الطلب اتعمل على السيرفر دلوقتي.
      serverOrders = [order(99, 'pending_offers')];
      await WaslMyOrdersScreen.refreshNow();
      await tester.pump();

      expect(
        calls.where((p) => p.contains('/orders/customer/')).length,
        before + 1,
        reason: 'التحديث بيسأل السيرفر تاني بدل ما يعرض كاش قديم',
      );
      // شاشة العميل بتكتب رقم الطلب بصيغة WS-، وشاشة الكابتن بصيغة FL-.
      expect(find.textContaining('WS-99'), findsWidgets);
    });

    testWidgets('refreshNow مابيرميش لما مفيش ولا نسخة شغالة', (tester) async {
      // بتتنادى من شاشات إنشاء الطلب من غير ما تعرف مين فاتح؛ لازم تعدّي بهدوء.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(WaslMyOrdersScreen.liveRefreshHooks, 0);
      await expectLater(WaslMyOrdersScreen.refreshNow(), completes);
    });
  });

  // ─── الكابتن ─────────────────────────────────────────────────────────────

  group('سوق الكابتن', () {
    testWidgets('الطلب الجديد بيظهر لوحده من غير ما الكابتن يعمل أي حاجة',
        (tester) async {
      // 🐞 الشاشة دي كانت بتقرا مرة واحدة في initState وخلاص. مهلة العرض ٦٠
      // ثانية، فالكابتن كان لازم يكون صادف إنه فاتحها في اللحظة دي — وإلا
      // الطلب يتولد وينتهي من غير ما يشوفه. ده اللي حصل فعلاً في قاعدة بيانات
      // التجربة: تلات طلبات راحت `expired` وصفوف الإسناد متكتوبة صح.
      serverOrders = [];

      await tester.pumpWidget(
        const MaterialApp(home: WaslDriverMarketplaceScreen()),
      );
      await tester.pump();

      expect(find.text('لا توجد طلبات متاحة حالياً'), findsOneWidget);
      final initialCalls =
          calls.where((p) => p.contains('/orders/available')).length;
      expect(initialCalls, 1);

      // العميل عمل طلب، والسيرفر عرضه على الكابتن ده.
      serverOrders = [order(42, 'pending_offers')];

      // من غير أي لمسة من الكابتن — نبضة واحدة بس.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(
        calls.where((p) => p.contains('/orders/available')).length,
        greaterThan(initialCalls),
        reason: 'الشاشة بتسأل السيرفر تاني لوحدها',
      );
      expect(find.textContaining('FL-42'), findsOneWidget);

      // تفكيك الشاشة عشان الـ Timer يتقفل ومايسربش لباقي الاختبارات.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
    });

    testWidgets('بيوقف السؤال بعد ما الشاشة تتقفل', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WaslDriverMarketplaceScreen()),
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      final afterDispose =
          calls.where((p) => p.contains('/orders/available')).length;
      await tester.pump(const Duration(seconds: 15));

      expect(
        calls.where((p) => p.contains('/orders/available')).length,
        afterDispose,
        reason: 'مفيش Timer فاضل شغال بعد الخروج من الشاشة',
      );
    });
  });
}
