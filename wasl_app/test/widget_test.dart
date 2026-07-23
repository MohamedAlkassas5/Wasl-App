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
import 'package:wasl_app/main.dart';

void main() {
  testWidgets('Wasl app onboarding initial route test', (WidgetTester tester) async {
    // 🎯 محاكاة فتح التطبيق لأول مرة في التاريخ (لم يشاهد التعريف ولم يشاهد السبلش)
    await tester.pumpWidget(const MyApp(
      seenOnboarding: false,
      seenSplash: false,
    ));

    // التحقق من أن التطبيق يعرض شاشة الأونبوردينج بنجاح
    expect(find.text('وصل'), findsOneWidget);
    expect(find.text('تخطي'), findsOneWidget);
    expect(find.text('مدينتك بين يديك'), findsOneWidget);

    // التحقق من عدم وجود نصوص شاشات السبلش أو تسجيل الدخول
    expect(find.text('فلاش توصيل • FLASH'), findsNothing);
  });

  testWidgets('Wasl app splash initial route test', (WidgetTester tester) async {
    // 🎯 محاكاة مستخدم شاهد الأونبوردينج مسبقاً (true) لكنها أول فتحة للتطبيق فيقفل على شاشة السبلش (false)
    await tester.pumpWidget(const MyApp(
      seenOnboarding: true,
      seenSplash: false,
    ));

    // 🎯 [تم الإصلاح]: تغيير الماتشر لـ findsOneWidget للتأكد من وجود مؤشر التحميل في شاشة الـ Splash
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('فلاش توصيل • FLASH'), findsNothing); // لسه ملمسش الـ Login
  });

  testWidgets('Wasl app direct login route test (Second Open)', (WidgetTester tester) async {
    // 🎯 اللقطة السحرية: مستخدم فتح الأبليكيشن قبل كدة (شاهد الأونبوردينج وشاهد السبلش مسبقاً = true)
    await tester.pumpWidget(const MyApp(
      seenOnboarding: true,
      seenSplash: true,
    ));

    // عمل pump لإتمام عملية الـ Render لشاشة الدخول مباشرة بدون سبلش
    await tester.pumpAndSettle();

    // التحقق من أن التطبيق يتوجه فوراً ودون أي تأخير لشاشة تسجيل الدخول بالتسمية الجديدة لـ FLASH
    expect(find.text('فلاش توصيل • FLASH'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    // التأكد التام من اختفاء نصوص الأونبوردينج القديمة
    expect(find.text('مدينتك بين يديك'), findsNothing);
  });
}