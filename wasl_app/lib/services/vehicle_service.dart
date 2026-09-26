import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:http/http.dart' as http;

import 'package:wasl_app/core/config/api_config.dart';
import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/ui/wasl_failure.dart';

/// بيانات مركبة الكابتن.
///
/// نفس أسلوب باقي الـ services: بترجّع `{'success': bool, ...}` وما بترميش
/// استثناءات على الشاشة.
///
/// **مفيش رقم كابتن في أي مسار هنا.** المركبة بتاعة صاحب التوكن، فما فيش حاجة
/// يتلاعب بيها العميل — نفس مبدأ `/wallet/summary`.
class WaslVehicleService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> getMyVehicle() async {
    try {
      final response = await WaslAuthedHttp.instance
          .get(Uri.parse('$baseUrl/drivers/me/vehicle'))
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) return {'success': true, ...decoded};
      return _failure(decoded, 'تعذّر تحميل بيانات المركبة');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  /// تعديل نوع المركبة ورقم اللوحة. حالة التوثيق والوثائق مش من هنا — السيرفر
  /// بيرفض أي حقل تاني بدل ما يتجاهله بصمت.
  Future<Map<String, dynamic>> updateMyVehicle({
    required WaslVehicleType vehicleType,
    String? licenseNumber,
  }) async {
    try {
      final response = await WaslAuthedHttp.instance
          .patch(
            Uri.parse('$baseUrl/drivers/me/vehicle'),
            body: jsonEncode({
              'vehicleType': vehicleType.wire,
              if (licenseNumber != null) 'licenseNumber': licenseNumber.trim(),
            }),
          )
          .timeout(_timeout);

      final decoded = _decode(response);
      if (_ok(response)) return {'success': true, ...decoded};
      return _failure(decoded, 'تعذّر حفظ بيانات المركبة');
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return WaslFailure.from(e).toResult();
    }
  }

  bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _failure(Map<String, dynamic> decoded, String fallback) {
    final message = decoded['message'];
    return {
      'success': false,
      'message': message is List
          ? message.join('، ')
          : (message?.toString().isNotEmpty == true
              ? message.toString()
              : fallback),
    };
  }
}

/// أنواع المركبات اللي السيرفر بيقبلها (`VehicleType`).
enum WaslVehicleType {
  motorcycle('motorcycle', 'موتوسيكل', Icons.two_wheeler_rounded),
  scooter('scooter', 'سكوتر', Icons.electric_scooter_rounded),
  car('car', 'سيارة', Icons.directions_car_rounded),
  bicycle('bicycle', 'دراجة', Icons.pedal_bike_rounded);

  const WaslVehicleType(this.wire, this.label, this.icon);

  final String wire;
  final String label;
  final IconData icon;

  static WaslVehicleType fromWire(String? value) => WaslVehicleType.values
      .firstWhere((t) => t.wire == value,
          orElse: () => WaslVehicleType.motorcycle);
}
