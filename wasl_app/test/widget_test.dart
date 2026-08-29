// // This is a basic Flutter widget test updated for the Wasl App.
// //
// // To perform an interaction with a widget in your test, use the WidgetTester
// // utility in the flutter_test package. For example, you can send tap and scroll
// // gestures. You can also use WidgetTester to find child widgets in the widget
// // tree, read text, and verify that the values of widget properties are correct.
//
// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
//
// import 'package:wasl_app/main.dart';
//
// void main() {
//   testWidgets('Wasl app onboarding initial route test', (WidgetTester tester) async {
//     // 🎯 قمنا بتمرير seenOnboarding كـ false لمحاكاة تشغيل التطبيق لأول مرة للمستخدم الجديد
//     await tester.pumpWidget(const MyApp(seenOnboarding: false));
//
//     // التحقق من أن التطبيق يعرض شاشة الأونبوردينج بنجاح عبر البحث عن نصوص الشاشة الأولى
//     expect(find.text('وصل'), findsOneWidget);
//     expect(find.text('تخطي'), findsOneWidget);
//     expect(find.text('مدينتك بين يديك'), findsOneWidget);
//
//     // التحقق من عدم وجود نصوص شاشة تسجيل الدخول في هذه المرحلة
//     expect(find.text('مرحباً بك في وصل'), findsNothing);
//   });
//
//   testWidgets('Wasl app login initial route test', (WidgetTester tester) async {
//     // 🎯 محاكاة تشغيل التطبيق للمستخدم القديم الذي شاهد شاشات التعريف مسبقاً (true)
//     await tester.pumpWidget(const MyApp(seenOnboarding: true));
//
//     // التحقق من أن التطبيق يتوجه مباشرة لشاشة تسجيل الدخول
//     expect(find.text('مرحباً بك في وصل'), findsOneWidget);
//     expect(find.text('أدخل بياناتك للمتابعة'), findsOneWidget);
//     expect(find.text('تسجيل الدخول'), findsOneWidget);
//
//     // التحقق من أن نصوص شاشة الأونبوردينج لم تعد تظهر هنا
//     expect(find.text('مدينتك بين يديك'), findsNothing);
//   });
// }



import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/main.dart';

/// اختبارات التوجيه عند فتح التطبيق.
///
/// كانت التلاتة بتفشل: واحد بسبب عيب حقيقي في الرسم (الأونبوردينج كان بيفيض
/// ٣٠٣ بكسل)، والاتنين التانيين بسبب توقعات قديمة اتكتبت قبل ما اسم التطبيق
/// يتغيّر من «وصل» لـ «فلاش توصيل» وقبل ما شاشة السبلش تستبدل مؤشر التحميل
/// بصورة. التوقعات دلوقتي بتطابق اللي الشاشات بترسمه فعلاً.
void main() {
  // السبلش بتقرا التوكن من التخزين المحلي لما التايمر يخلص؛ من غير ده بيرمي
  // MissingPluginException بدل ما ينقلنا لشاشة الدخول.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Wasl app onboarding initial route test', (WidgetTester tester) async {
    // 🎯 محاكاة فتح التطبيق لأول مرة في التاريخ (لم يشاهد التعريف ولم يشاهد السبلش)
    await tester.pumpWidget(const MyApp(
      seenOnboarding: false,
      seenSplash: false,
    ));

    // التحقق من أن التطبيق يعرض شاشة الأونبوردينج بنجاح
    expect(find.text('فلاش توصيل'), findsOneWidget);
    expect(find.text('تخطي'), findsOneWidget);
    // النص الكامل زي ما هو مكتوب في الشاشة — find.text بيطابق النص بالكامل.
    expect(find.text('كل مدينتك بين يديك'), findsOneWidget);

    // مفيش أي أثر لشاشة تسجيل الدخول في المرحلة دي
    expect(find.text('أهلاً بك في فلاش توصيل (Flash Tawseel)'), findsNothing);
  });

  testWidgets('Wasl app splash initial route test', (WidgetTester tester) async {
    // 🎯 محاكاة مستخدم شاهد الأونبوردينج مسبقاً (true) لكنها أول فتحة للتطبيق فيقفل على شاشة السبلش (false)
    await tester.pumpWidget(const MyApp(
      seenOnboarding: true,
      seenSplash: false,
    ));

    // شاشة السبلش بتعرض شعار التطبيق كصورة — مؤشر التحميل اتشال من زمان،
    // والاختبار كان لسه بيدوّر عليه.
    expect(find.byType(Image), findsWidgets);
    expect(
      find.text('أهلاً بك في فلاش توصيل (Flash Tawseel)'),
      findsNothing,
    ); // لسه ملمسش الـ Login

    // السبلش بيشغّل تايمرين (١.٢ث و ٣.٢ث) قبل ما ينقل المستخدم. لازم نستنّاهم
    // يخلصوا، وإلا الاختبار بينتهي والتايمر لسه شغال فـ flutter_test بيعتبرها
    // تسريب ويفشّل الاختبار. الشاشة نفسها بتتأكد من `mounted` قبل أي setState،
    // فمفيش مشكلة حقيقية هنا — دي حاجة تخص الاختبار وحده.
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('Wasl app direct login route test (Second Open)', (WidgetTester tester) async {
    // 🎯 اللقطة السحرية: مستخدم فتح الأبليكيشن قبل كدة (شاهد الأونبوردينج وشاهد السبلش مسبقاً = true)
    await tester.pumpWidget(const MyApp(
      seenOnboarding: true,
      seenSplash: true,
    ));

    // عمل pump لإتمام عملية الـ Render لشاشة الدخول مباشرة بدون سبلش
    await tester.pumpAndSettle();

    // النص زي ما هو مكتوب في شاشة الدخول بالظبط
    expect(find.text('أهلاً بك في فلاش توصيل (Flash Tawseel)'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);

    // التأكد التام من اختفاء نصوص الأونبوردينج
    expect(find.text('كل مدينتك بين يديك'), findsNothing);
  });
}