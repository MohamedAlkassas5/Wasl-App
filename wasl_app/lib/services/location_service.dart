import 'package:geolocator/geolocator.dart';

/// Centralised GPS/location handling for the whole app.
///
/// Replaces the ad-hoc `Geolocator.getCurrentPosition(...)` calls that were
/// scattered across screens (each with its own permission handling). Nothing
/// here hardcodes a city — every position is a real device fix.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Ensures location services are on and permission is granted.
  /// Returns true when the app is allowed to read the device position.
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  /// Current device position, or null if unavailable / permission denied.
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await ensurePermission()) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  /// Live position stream for continuous driver tracking. Emits when the
  /// device moves at least [distanceFilter] metres.
  Stream<Position> positionStream({int distanceFilter = 30}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Straight-line distance in kilometres between two points.
  double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000.0;
  }
}
