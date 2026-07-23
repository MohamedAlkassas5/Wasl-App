import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  int? _userId;
  String? _userName;
  String? _userPhone;
  String? _userRole;
  String? _token;

  // 🛰️ حقول الإحداثيات الجغرافية الحية لتتبع العميل ومزامنة السيرفر
  double? _currentLatitude;
  double? _currentLongitude;

  int? get userId => _userId;
  String? get userName => _userName;

  // 🎯 [تم الإصلاح]: إضافة الـ Getter المفقود للهاتف
  String? get userPhone => _userPhone;

  String? get userRole => _userRole;
  String? get token => _token;

  // 🎯 [تم الإصلاح]: إضافة الـ Getters المفقودة للإحداثيات الجغرافية
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;

  // دالة حفظ البيانات بعد الـ Login أو الـ Register بنجاح
  void saveUserSession({
    required int id,
    required String name,
    required String phone,
    required String role,
    required String token,
  }) {
    _userId = id;
    _userName = name;
    _userPhone = phone;
    _userRole = role;
    _token = token;

    notifyListeners(); // 🔔 لتحديث جميع شاشات التطبيق فوراً
  }

  // 🎯 دالة تحديث الإحداثيات الحية القادمة من الـ GPS (تستدعى عند اختيار موقع على الخريطة)
  void updateLocation({required double latitude, required double longitude}) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    notifyListeners();
  }

  // دالة تسجيل الخروج وتنظيف الكاش
  void logout() {
    _userId = null;
    _userName = null;
    _userPhone = null;
    _userRole = null;
    _token = null;
    _currentLatitude = null;
    _currentLongitude = null;
    notifyListeners();
  }
}