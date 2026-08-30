import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🎯 1. استيراد حزمة الـ Provider
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart'; // 🎯 2. استيراد المكتبة الأساسية لتهيئة Firebase
import 'package:firebase_messaging/firebase_messaging.dart';

// استيراد الـ Provider الخاص بإدارة جلسة المستخدم
import 'package:wasl_app/core/providers/user_provider.dart';
import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/theme/wasl_theme.dart';
import 'package:wasl_app/services/push_service.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslMyOrdersScreen.dart';
import 'package:wasl_app/delivery_screen/WaslDriverOrdersScreen.dart';

// استيراد الشاشات الخاصة بالتطبيق
import 'screens/WaslOnboardingScreen.dart';
import 'screens/WaslLoginScreen.dart';
import 'package:wasl_app/screens/WaslSplashScreen.dart';

/// Lets code outside the widget tree — a failed token refresh, for one — send
/// the user back to the login screen.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 🔔 وجهة الدوسة على الإشعار.
///
/// بيروح لقايمة الطلبات المناسبة، مش لشاشة طلب واحد. السبب عملي: شاشات الطلب
/// الواحد بتاخد كائن الطلب كامل، والإشعار فيه رقم الطلب بس (عن قصد — الـ
/// `data` مالهاش تحمل أي بيانات شخصية). القايمة بتجيب البيانات من السيرفر
/// وبتوصّل المستخدم لطلبه من غير ما نخترع بيانات ناقصة.
void _wirePushRouting() {
  WaslPushService.instance.onTap = (tap) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => tap.isDriverOffer
            ? const WaslDriverOrdersScreen()
            : const WaslMyOrdersScreen(),
      ),
    );
  };

  // إشعار والتطبيق مفتوح: نظام التشغيل ما بيرسمش حاجة، فبنعرضه بنفسنا.
  WaslPushService.instance.onForeground = (title, body, _) {
    final messengerContext = appNavigatorKey.currentContext;
    if (messengerContext == null || title.isEmpty) return;

    ScaffoldMessenger.of(messengerContext).showSnackBar(
      SnackBar(
        content: Text(
          body.isEmpty ? title : '$title\n$body',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  };
}

void main() async {
  // 🎯 3. تأمين اتصال الـ Widgets بنظام الـ Native لضمان عمل الخدمات قبل سطر الـ runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 🎯 4. التفعيل الإجباري لخدمات Firebase لقراءة الـ google-services.json
  await Firebase.initializeApp();

  // 🔔 CP-C: إشعارات الطلبات. المعالج ده لازم يتسجّل قبل أي حاجة تانية عشان
  // الرسائل اللي بتوصل والتطبيق مقفول تلاقي حد مستنيها.
  FirebaseMessaging.onBackgroundMessage(waslPushBackgroundHandler);
  _wirePushRouting();

  // الحصول على نسخة من SharedPreferences لفحص حالة المستخدم الحالي
  final prefs = await SharedPreferences.getInstance();

  // قراءة الحالات المخزنة في الكاش المحلي
  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  // 🎯 [جديد]: قراءة حالة شاشة السبلش (لو مش موجودة سيعتبرها false يعني أول مرة يفتح)
  final bool seenSplash = prefs.getBool('seen_splash') ?? false;

  // 🔐 لو التوكن خلص وفشل التجديد، الجلسة بتبقى خلصت فعلاً — التطبيق لازم
  // يرجّع المستخدم لتسجيل الدخول بدل ما يفضل شغال بجلسة ميتة. الـ navigator key
  // بيخلي ده ممكن حتى لو الفشل حصل في طلب خلفي مالوش شاشة.
  WaslAuthedHttp.onSignedOut = () {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WaslLoginScreen()),
      (route) => false,
    );
  };

  // 🎯 5. تشغيل التطبيق وحقن الـ UserProvider ليكون متاحاً في جميع الشاشات ديناميكياً
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      // تمرير الشرطين للـ MyApp ديناميكياً
      child: MyApp(seenOnboarding: seenOnboarding, seenSplash: seenSplash),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  final bool seenSplash; // 🎯 [جديد] استقبال بارامتر السبلش

  const MyApp({
    super.key,
    required this.seenOnboarding,
    required this.seenSplash,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wasl',
      navigatorKey: appNavigatorKey,
      theme: WaslTheme.light,
      debugShowCheckedModeBanner: false,

      // 🎯 [الفحص الذكي الخارق للـ UX]:
      // 1. لو مشافش الـ Onboarding ➔ يروح للتعريف فوراً.
      // 2. لو شاف الـ Onboarding بس لسه مشافش السبلش لأول مرة ➔ يروح للسبلش.
      // 3. لو شاف الاتنين مسبقاً (فتحة التطبيق التانية) ➔ يطير فوراً على شاشة تسجيل الدخول WaslLoginScreen بدون أي تأخير!
      home: !seenOnboarding
          ? const WaslOnboardingScreen()
          : (!seenSplash ? const WaslSplashScreen() : const WaslLoginScreen()),
    );
  }
}





// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // 🎯 1. استيراد حزمة الـ Provider
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_core/firebase_core.dart'; // 🎯 2. استيراد المكتبة الأساسية لتهيئة Firebase
//
// // استيراد الـ Provider الخاص بإدارة جلسة المستخدم
// import 'package:wasl_app/core/providers/user_provider.dart';
//
// // استيراد الشاشات الخاصة بالتطبيق
// import 'screens/WaslOnboardingScreen.dart';
// import 'screens/WaslLoginScreen.dart';
// import 'package:wasl_app/screens/WaslDeliveryIdentityScreen.dart';
// import 'package:wasl_app/screens/WaslMerchantRegisterScreen.dart';
// import 'package:wasl_app/screens/WaslSplashScreen.dart';
//
// void main() async {
//   // 🎯 3. تأمين اتصال الـ Widgets بنظام الـ Native لضمان عمل الخدمات قبل سطر الـ runApp
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // 🎯 4. التفعيل الإجباري لخدمات Firebase لقراءة الـ google-services.json
//   await Firebase.initializeApp();
//
//   // الحصول على نسخة من SharedPreferences لفحص حالة المستخدم الحالي
//   final prefs = await SharedPreferences.getInstance();
//
//   // قراءة القيمة: إذا لم تكن موجودة (null)، سيعتبرها false مما يعني أن المستخدم يفتح التطبيق لأول مرة
//   final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
//
//   // 🎯 5. تشغيل التطبيق وحقن الـ UserProvider ليكون متاحاً في جميع الشاشات ديناميكياً
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => UserProvider()),
//       ],
//       child: MyApp(seenOnboarding: seenOnboarding),
//     ),
//   );
// }
//
// class MyApp extends StatelessWidget {
//   final bool seenOnboarding;
//
//   // تمرير حالة المستخدم المتغيرة كمعامل إجباري إلى الـ Widget الأساسية
//   const MyApp({super.key, required this.seenOnboarding});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'wasl',
//       theme: ThemeData(
//         // تم تحديث الألوان لتناسب الهوية البرتقالية لتطبيق وصل
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: const Color(0xFFF14D18),
//           primary: const Color(0xFFF14D18),
//         ),
//         useMaterial3: true,
//       ),
//       debugShowCheckedModeBanner: false,
//       // 🎯 الفحص الذكي: إذا شاهد شاشات التعريف مسبقاً (true) يفتح شاشة السبلش أو تسجيل الدخول، وإلا يفتح شاشة التعريف
//       home: seenOnboarding ? const WaslSplashScreen() : const WaslOnboardingScreen(),
//     );
//   }
// }