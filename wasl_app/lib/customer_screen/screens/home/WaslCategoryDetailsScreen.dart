import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/theme/wasl_assets.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/customer_screen/order_anywhere/WaslOrderCategoryScreen.dart';
import 'package:wasl_app/customer_screen/restaurants/WaslRestaurantDetailsScreen.dart';

/// Restaurants (and partner stores) near the customer.
///
/// This screen used to render two invented restaurants — "ذا برجر هاوس" and
/// "باستا وبيتزا" — with hardcoded ratings, delivery times and a fixed
/// "تم العثور على 24 موقعاً" count, and never called the server at all. Tapping
/// one led nowhere. It is now backed by the real `/stores/nearby` endpoint
/// (approved merchants with coordinates, nearest first), and shows an honest
/// empty state when there is genuinely nothing nearby.
///
/// Only fields the server actually returns are displayed. Ratings and prep
/// times are deliberately NOT shown: there is no source for them yet, and
/// inventing them is what made the old screen misleading.
class WaslCategoryDetailsScreen extends StatefulWidget {
  /// Restrict the list to one category, e.g. "مطاعم". Null shows every partner.
  final String? categoryFilter;

  /// Heading shown in the app bar.
  final String title;

  const WaslCategoryDetailsScreen({
    Key? key,
    this.categoryFilter,
    this.title = 'المطاعم والمتاجر',
  }) : super(key: key);

  @override
  State<WaslCategoryDetailsScreen> createState() =>
      _WaslCategoryDetailsScreenState();
}

enum _SortMode { nearest, name }

class _WaslCategoryDetailsScreenState extends State<WaslCategoryDetailsScreen> {
  bool _isLoading = true;

  /// Everything the server returned, before search/sort is applied.
  List<dynamic> _stores = [];

  /// Why the list is empty (no GPS / none nearby / request failed).
  String _message = '';

  String _search = '';
  _SortMode _sort = _SortMode.nearest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    // "Near you" is meaningless without a fix — say so instead of guessing.
    final position = await _resolvePosition();
    if (position == null) {
      if (!mounted) return;
      setState(() {
        _stores = [];
        _message = 'فعّل خدمة الموقع لعرض المطاعم القريبة منك';
        _isLoading = false;
      });
      return;
    }

    try {
      final res = await FlutterAuthService().getNearbyStores(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;

      if (res['success'] == true) {
        final all = (res['data'] as List?) ?? [];
        final filtered = widget.categoryFilter == null
            ? all
            : all.where(_matchesCategory).toList();

        setState(() {
          _stores = filtered;
          _message = filtered.isEmpty
              ? 'لا توجد مطاعم شريكة في نطاقك حالياً — تقدر تطلب أي حاجة من أي مكان'
              : '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _stores = [];
          _message = 'تعذّر تحميل المطاعم القريبة، حاول مرة أخرى';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stores = [];
        _message = 'تعذّر الاتصال بالسيرفر';
        _isLoading = false;
      });
    }
  }

  /// The merchant's own `storeType` is free text set at registration, so match
  /// loosely rather than demanding an exact string.
  bool _matchesCategory(dynamic store) {
    final type = (store['merchant_store_type'] ?? '').toString();
    final wanted = widget.categoryFilter!;
    return type.contains(wanted) || wanted.contains(type);
  }

  Future<Position?> _resolvePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  /// Search + sort applied to what the server gave us.
  List<dynamic> get _visibleStores {
    final query = _search.trim();
    final list = query.isEmpty
        ? [..._stores]
        : _stores.where((s) {
            final name = (s['merchant_store_name'] ?? '').toString();
            final type = (s['merchant_store_type'] ?? '').toString();
            return name.contains(query) || type.contains(query);
          }).toList();

    if (_sort == _SortMode.name) {
      list.sort((a, b) => (a['merchant_store_name'] ?? '')
          .toString()
          .compareTo((b['merchant_store_name'] ?? '').toString()));
    } else {
      list.sort((a, b) => _distanceOf(a).compareTo(_distanceOf(b)));
    }
    return list;
  }

  double _distanceOf(dynamic store) =>
      double.tryParse(store['distance']?.toString() ?? '') ?? double.infinity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Cairo',
          ),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _buildSearchBar(),
            if (!_isLoading && _stores.isNotEmpty) _buildToolbar(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        textDirection: TextDirection.rtl,
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        decoration: InputDecoration(
          hintText: 'ابحث عن المطاعم والأطباق',
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Real count + sort controls. The old screen printed a fixed "24 موقعاً"
  /// regardless of what existed; this reflects the actual list.
  Widget _buildToolbar() {
    final count = _visibleStores.length;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Text(
            count == 0 ? 'لا نتائج للبحث' : 'يوجد $count مطعم قريب منك',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          const Spacer(),
          _sortChip('الأقرب', _SortMode.nearest),
          const SizedBox(width: 6),
          _sortChip('الاسم', _SortMode.name),
        ],
      ),
    );
  }

  Widget _sortChip(String label, _SortMode mode) {
    final selected = _sort == mode;
    return GestureDetector(
      onTap: () => setState(() => _sort = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.logoGradient : null,
          color: selected ? null : AppColors.background,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const WaslLoader(message: 'جاري تحميل المطاعم القريبة...');
    }

    if (_stores.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            WaslEmptyState(
              icon: Icons.storefront_outlined,
              title: 'لا توجد مطاعم متاحة',
              subtitle: _message,
              action: WaslButton(
                label: 'اطلب أي حاجة من أي مكان',
                icon: Icons.bolt_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WaslOrderCategoryScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final visible = _visibleStores;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: visible.length,
        itemBuilder: (context, i) => _buildStoreCard(visible[i]),
      ),
    );
  }

  Widget _buildStoreCard(dynamic store) {
    final name = (store['merchant_store_name'] ?? 'متجر شريك').toString();
    final type = (store['merchant_store_type'] ?? '').toString();
    final address = (store['addressDetails'] ?? '').toString();
    final distance = _distanceOf(store);
    final logo = store['logo']?.toString();

    // المتجر المقفول بيفضل في القائمة، باهت ومكتوب عليه إنه مقفول. الاختفاء
    // بيتقري «المتجر مابقاش موجود» ويخلي الناس تدوّر عليه.
    // `!= false` مش `== true`: لو الحقل ناقص من الرد بنعتبره مفتوح ونسيب
    // السيرفر يرفض، بدل ما نقفل متجر شغال بالغلط.
    final accepting = store['isAcceptingOrders'] != false;

    return Opacity(
      opacity: accepting ? 1 : 0.55,
      child: GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaslRestaurantDetailsScreen(
            merchantId: (store['id'] as num?)?.toInt() ?? 0,
            merchantName: name,
            merchantType: type.isEmpty ? null : type,
            addressDetails: address.isEmpty ? null : address,
            distanceKm: distance.isFinite ? distance : null,
            latitude: double.tryParse(store['latitude']?.toString() ?? ''),
            longitude: double.tryParse(store['longitude']?.toString() ?? ''),
            isAcceptingOrders: accepting,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
        children: [
          _buildLogo((store['id'] as num?)?.toInt() ?? 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (type.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Cairo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'Cairo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      distance.isFinite
                          ? '${distance.toStringAsFixed(1)} كم'
                          : 'المسافة غير معروفة',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    if (!accepting) ...[
                      const SizedBox(width: 8),
                      const WaslStatusBadge('مقفول دلوقتي', AppColors.danger),
                    ],
                  ],
                ),
              ],
            ),
          ),
            const Icon(Icons.chevron_left,
                color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
      ),
    );
  }

  /// Uploaded logos sit behind an authenticated route, so a plain
  /// `Image.network` would 401. Until that's wired we show a stable demo cover
  /// keyed on the merchant id, so no card is left with an empty image slot.
  Widget _buildLogo(int merchantId) {
    const size = 68.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
      child: Image.asset(
        WaslAssets.coverFor(merchantId),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: AppColors.background,
          child: const Icon(Icons.storefront_rounded,
              color: AppColors.primary, size: 28),
        ),
      ),
    );
  }
}
