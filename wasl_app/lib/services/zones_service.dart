import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wasl_app/core/config/api_config.dart';

/// One of the approved delivery areas (كوم حمادة / بيبان / بريم).
///
/// The list is never hardcoded in the app: areas and their prices are rows in
/// the backend, so opening a new area is a data change, not a release.
class WaslZone {
  final int id;
  final String? code;
  final String name;
  final String city;

  const WaslZone({
    required this.id,
    required this.name,
    required this.city,
    this.code,
  });

  factory WaslZone.fromJson(Map<String, dynamic> json) => WaslZone(
        id: (json['id'] as num).toInt(),
        code: json['code']?.toString(),
        name: json['name']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
      );

  @override
  bool operator ==(Object other) => other is WaslZone && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Areas and the prices attached to them.
///
/// Every fee shown to a customer comes from here — the app never computes or
/// guesses one. If a quote fails, the screen says so rather than showing a
/// number the server did not agree to.
class ZonesService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  Future<Map<String, String>> _headers() => WaslApiConfig.authHeaders();

  /// Cached because the three areas do not change during a session and this is
  /// read on registration, on checkout, and on every Waslly screen.
  static List<WaslZone>? _cache;

  /// The approved areas. `/zones` is public, so this works on the
  /// registration screen before the customer has a token.
  Future<List<WaslZone>> getZones({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    final response = await http
        .get(Uri.parse('$baseUrl/zones'), headers: WaslApiConfig.jsonHeaders)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذّر تحميل المناطق المتاحة');
    }

    final zones = (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(WaslZone.fromJson)
        .toList();
    _cache = zones;
    return zones;
  }

  /// Delivery fee for a normal order (restaurants / pharmacy / stores).
  ///
  /// Omitting [dropoffZoneId] asks the server to use the area saved on the
  /// customer's own profile, which is the usual case.
  Future<Map<String, dynamic>> getNormalQuote({int? dropoffZoneId}) =>
      _quote('normal-quote', {
        if (dropoffZoneId != null) 'dropoffZoneId': dropoffZoneId,
      });

  /// Fixed fee for a Waslly run from one area to another.
  Future<Map<String, dynamic>> getWasllyQuote({
    required int pickupZoneId,
    required int dropoffZoneId,
  }) =>
      _quote('waslly-quote', {
        'pickupZoneId': pickupZoneId,
        'dropoffZoneId': dropoffZoneId,
      });

  Future<Map<String, dynamic>> _quote(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/pricing/$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      // The server's message names the actual problem ("no approved price
      // between these two areas"), which is more use than a generic failure.
      return {
        'success': false,
        'message': _messageOf(decoded) ?? 'تعذّر حساب سعر التوصيل',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Nest returns `message` as either a string or a list of validation errors.
  String? _messageOf(Map<String, dynamic> body) {
    final message = body['message'];
    if (message is String) return message;
    if (message is List && message.isNotEmpty) return message.first.toString();
    return null;
  }
}
