import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:wasl_app/services/device_token_service.dart';

/// اللي التطبيق بيعمله لما المستخدم يدوس على إشعار.
///
/// المفاتيح دي بيبعتها السيرفر في `data` (شوف `NotificationKind` في
/// `notifications.service.ts`)، وهي **مقصود إنها تكون تلميحات توجيه بس** —
/// مفيش أي بيانات شخصية فيها.
class WaslPushTap {
  const WaslPushTap({required this.kind, this.orderId});

  /// `order_offer` / `offer_expired` / `order_expired` / `order_update`.
  final String kind;
  final int? orderId;

  /// إشعار موجّه للكابتن (عرض طلب) ولا للعميل (تحديث على طلبه)؟
  bool get isDriverOffer => kind == 'order_offer';

  static WaslPushTap? fromData(Map<String, dynamic> data) {
    final kind = data['kind']?.toString();
    if (kind == null || kind.isEmpty) return null;
    return WaslPushTap(
      kind: kind,
      orderId: int.tryParse(data['orderId']?.toString() ?? ''),
    );
  }
}

/// معالج الإشعارات والتطبيق مقفول أو في الخلفية.
///
/// لازم يكون دالة عليا ومعلّمة بـ `vm:entry-point`، لأن الـ Flutter engine
/// بيشغّلها في isolate تاني خالص. ما بنعملش فيها حاجة عن قصد: الإشعار نفسه
/// بيرسمه نظام التشغيل، والتوجيه بيحصل لما المستخدم يدوس — مش وإحنا في
/// الخلفية من غير شاشة أصلاً.
@pragma('vm:entry-point')
Future<void> waslPushBackgroundHandler(RemoteMessage message) async {}

/// إشعارات الطلبات — الطرف بتاع التطبيق.
///
/// السيرفر خلاص بيبعت (`device_tokens` + `fcm-push.provider.ts`); الناقص كان
/// إن التطبيق يقول للسيرفر «أنا هنا» ويرد على الدوسة.
///
/// كل حاجة هنا بتفشل بهدوء. لو المستخدم رفض الإذن، أو Firebase ما اشتغلتش،
/// التطبيق بيفضل شغال عادي — الإشعارات إضافة مش شرط لتسجيل الدخول أو الطلب.
class WaslPushService {
  WaslPushService({
    FirebaseMessaging? messaging,
    WaslDeviceTokenService? devices,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _devices = devices ?? WaslDeviceTokenService();

  static WaslPushService instance = WaslPushService();

  final FirebaseMessaging _messaging;
  final WaslDeviceTokenService _devices;

  /// بيتنادى لما المستخدم يدوس على إشعار. الشاشة بتتحدد في `main.dart`.
  void Function(WaslPushTap tap)? onTap;

  /// بيتنادى لإشعار جه والتطبيق مفتوح — نظام التشغيل ما بيرسمهوش ساعتها.
  void Function(String title, String body, WaslPushTap? tap)? onForeground;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _started = false;

  /// بيتنادى بعد تسجيل الدخول: إذن، توكن، تسجيل، وسماع.
  ///
  /// آمن إنها تتنادى أكتر من مرة — بتشتغل مرة واحدة بس.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // المستخدم رفض. مفيش داعي نجيب توكن ولا نسجّله — ومفيش رسالة خطأ،
        // ده اختياره.
        _started = false;
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) await _devices.register(token);

      // التوكن بيتغيّر من نفسه (إعادة تثبيت، مسح بيانات، دوران دوري).
      _subscriptions.add(
        _messaging.onTokenRefresh.listen(_devices.register),
      );

      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          final notification = message.notification;
          onForeground?.call(
            notification?.title ?? '',
            notification?.body ?? '',
            WaslPushTap.fromData(message.data),
          );
        }),
      );

      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(_handleTap),
      );

      // التطبيق كان مقفول خالص والمستخدم فتحه من الإشعار.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (error) {
      // Firebase مش متهيّأة، أو الجهاز من غير Google Play services.
      _started = false;
      debugPrint('[WaslPush] تعذّر تشغيل الإشعارات: $error');
    }
  }

  void _handleTap(RemoteMessage message) {
    final tap = WaslPushTap.fromData(message.data);
    if (tap != null) onTap?.call(tap);
  }

  /// بيتنادى **قبل** مسح الجلسة عند تسجيل الخروج.
  ///
  /// بيشيل التسجيل من السيرفر وبيمسح التوكن من الجهاز، عشان اللي هيسجّل دخول
  /// بعد كده على نفس الموبايل ما يستقبلش إشعارات الحساب اللي قبله.
  Future<void> stop() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _devices.unregister(token);
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('[WaslPush] تعذّر إلغاء تسجيل الجهاز: $error');
    } finally {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      _devices.forget();
      _started = false;
    }
  }
}
