import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/location_service.dart';
import 'package:wasl_app/services/location_api_service.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderAnyplaceDetailsScreen.dart';

/// Real interactive map for picking the exact delivery point.
///
/// Uses OpenStreetMap tiles via flutter_map. The map opens on the customer's
/// live GPS position; the centre pin marks the chosen point. On confirm we
/// reverse-geocode the coordinates to a readable address and pass BOTH the
/// address and the real lat/lng forward — nothing is hardcoded.
class WaslMapPickerScreen extends StatefulWidget {
  const WaslMapPickerScreen({Key? key}) : super(key: key);

  @override
  State<WaslMapPickerScreen> createState() => _WaslMapPickerScreenState();
}

class _WaslMapPickerScreenState extends State<WaslMapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final LocationApiService _locationApi = LocationApiService();

  // Kom Hamada is used ONLY as the initial map viewport while GPS resolves —
  // the confirmed order coordinate is always the pin the user actually places.
  static const LatLng _defaultView = LatLng(30.463284, 30.702954);

  LatLng _center = _defaultView;
  bool _isLocating = true;
  bool _isConfirming = false;
  String _addressPreview = 'حرّك الخريطة لتحديد موقع التوصيل';

  // 🛵 Live nearby available drivers, shown as pins around the chosen point.
  List<Marker> _driverMarkers = [];
  int _nearbyDriversCount = 0;

  @override
  void initState() {
    super.initState();
    _goToCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      final target = LatLng(pos.latitude, pos.longitude);
      _center = target;
      _mapController.move(target, 16);
    }
    setState(() => _isLocating = false);
    _updateAddressPreview();
    _loadNearbyDrivers();
  }

  // Fetch available drivers around the current map centre and render them.
  Future<void> _loadNearbyDrivers() async {
    final result = await _locationApi.getNearbyDrivers(
      lat: _center.latitude,
      lng: _center.longitude,
    );
    if (!mounted || result['success'] != true) return;
    final drivers = (result['data']?['drivers'] as List?) ?? [];
    setState(() {
      _nearbyDriversCount = drivers.length;
      _driverMarkers = drivers
          .map<Marker?>((d) {
            final lat = (d['latitude'] as num?)?.toDouble();
            final lng = (d['longitude'] as num?)?.toDouble();
            if (lat == null || lng == null) return null;
            return Marker(
              point: LatLng(lat, lng),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.15),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: const Icon(Icons.two_wheeler,
                    color: AppColors.primary, size: 22),
              ),
            );
          })
          .whereType<Marker>()
          .toList();
    });
  }

  Future<void> _updateAddressPreview() async {
    try {
      final placemarks =
          await placemarkFromCoordinates(_center.latitude, _center.longitude);
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .where((e) => e != null && e.trim().isNotEmpty)
            .toList();
        setState(() => _addressPreview = parts.isEmpty
            ? 'الموقع المحدد على الخريطة'
            : parts.join('، '));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _addressPreview =
            'الموقع المحدد (${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)})');
      }
    }
  }

  Future<void> _confirmLocation() async {
    setState(() => _isConfirming = true);
    await _updateAddressPreview();
    if (!mounted) return;
    setState(() => _isConfirming = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaslOrderAnyplaceDetailsScreen(
          selectedAddress: _addressPreview,
          selectedLatitude: _center.latitude,
          selectedLongitude: _center.longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ Real map. The centre of the viewport is the chosen point.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onPositionChanged: (camera, hasGesture) {
                _center = camera.center ?? _center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wasl.app',
              ),
              if (_driverMarkers.isNotEmpty)
                MarkerLayer(markers: _driverMarkers),
            ],
          ),

          // شريط البحث العلوي وزر العودة المطور
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textPrimary.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textPrimary.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                textAlign: TextAlign.right,
                                onSubmitted: _searchPlace,
                                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                                decoration: const InputDecoration(
                                  hintText: 'ابحث عن مكان، حي، أو معلم...',
                                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo'),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // دبوس تحديد الموقع الأنيق بمنتصف الشاشة تماشياً مع لون البراند الأساسي
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'توصيل الطلب هنا',
                    style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.location_pin, color: AppColors.primary, size: 46),
                const SizedBox(height: 40), // يعوّض ارتفاع اللوحة السفلية ليبقى الدبوس بالمنتصف الفعلي
              ],
            ),
          ),

          // زر تحديد موقعي الحالي
          Positioned(
            bottom: 210,
            left: 16,
            child: GestureDetector(
              onTap: _isLocating ? null : _goToCurrentLocation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: _isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: AppColors.primary),
                      )
                    : const Icon(Icons.my_location, color: AppColors.primary),
              ),
            ),
          ),

          // اللوحة السفلية العصرية
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.location_on, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'موقع التوصيل المحدد',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _addressPreview,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5, fontFamily: 'Cairo'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 🛵 عدد المناديب المتاحين بالقرب من موقع التوصيل
                    Row(
                      children: [
                        const Icon(Icons.two_wheeler,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _nearbyDriversCount > 0
                              ? 'يوجد $_nearbyDriversCount كابتن متاح بالقرب منك'
                              : 'جاري البحث عن كباتن متاحين بالقرب منك...',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 🎯 زر تأكيد الموقع الاحترافي المدعوم بالتدرج اللوني السريع لـ وصل
                    GestureDetector(
                      onTap: _isConfirming ? null : _confirmLocation,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _isConfirming ? null : AppColors.logoGradient,
                          color: _isConfirming ? Colors.grey.shade300 : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isConfirming ? null : [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Center(
                          child: _isConfirming
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                          )
                              : const Text(
                            'تأكيد الموقع',
                            style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بحث نصي عن مكان وتحريك الخريطة إليه (تحويل العنوان لإحداثيات).
  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final locations = await locationFromAddress(query.trim());
      if (!mounted || locations.isEmpty) return;
      final target = LatLng(locations.first.latitude, locations.first.longitude);
      _center = target;
      _mapController.move(target, 16);
      _updateAddressPreview();
      _loadNearbyDrivers();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على المكان المطلوب',
              style: TextStyle(fontFamily: 'Cairo')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
