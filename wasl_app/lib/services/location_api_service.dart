import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wasl_app/core/config/api_config.dart';

/// Backend calls for the Phase-1 location + pricing engine:
/// - price quotes (distance-tier pricing)
/// - nearest available drivers
/// - driver live-location push
class LocationApiService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  Future<Map<String, String>> _headers() => WaslApiConfig.authHeaders();

  /// Estimated delivery fee for a pickup → destination trip.
  /// Returns the full quote (fee, tier, commission, driver earnings).
  Future<Map<String, dynamic>> getPriceQuote({
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final url = Uri.parse('$baseUrl/pricing/quote');
    try {
      final response = await http
          .post(
            url,
            headers: await _headers(),
            body: jsonEncode({
              'pickupLatitude': pickupLat,
              'pickupLongitude': pickupLng,
              'destinationLatitude': destinationLat,
              'destinationLongitude': destinationLng,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'تعذّر حساب سعر التوصيل'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Quote by an explicit trip distance (km). Used when only the destination
  /// is known and the pickup is "nearest place" — pass 0 for the city base fee.
  Future<Map<String, dynamic>> getQuoteByDistance(double distanceKm) async {
    final url = Uri.parse('$baseUrl/pricing/quote');
    try {
      final response = await http
          .post(
            url,
            headers: await _headers(),
            body: jsonEncode({'distanceKm': distanceKm}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'تعذّر حساب سعر التوصيل'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Available drivers near a point, nearest-first (expanding radius).
  Future<Map<String, dynamic>> getNearbyDrivers({
    required double lat,
    required double lng,
    double? radiusKm,
  }) async {
    final query = radiusKm != null
        ? '?lat=$lat&lng=$lng&radius=$radiusKm'
        : '?lat=$lat&lng=$lng';
    final url = Uri.parse('$baseUrl/drivers/nearby$query');
    try {
      final response = await http
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'تعذّر جلب الكباتن القريبين'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Driver app pushes its live GPS location while online.
  Future<bool> updateDriverLocation({
    required int driverId,
    required double latitude,
    required double longitude,
    double? availabilityRadiusKm,
  }) async {
    final url = Uri.parse('$baseUrl/drivers/$driverId/location');
    try {
      final response = await http
          .patch(
            url,
            headers: await _headers(),
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              if (availabilityRadiusKm != null)
                'availabilityRadiusKm': availabilityRadiusKm,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
