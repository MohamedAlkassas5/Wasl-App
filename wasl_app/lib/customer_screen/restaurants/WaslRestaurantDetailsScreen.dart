import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/theme/wasl_assets.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';

import 'data/cart_controller.dart';
import 'data/menu_repository.dart';
import 'data/restaurant_models.dart';
import 'WaslProductDetailsSheet.dart';
import 'WaslCartScreen.dart';

/// A restaurant's menu: header with its details, a tab per menu section, and
/// the items under the selected tab.
///
/// The restaurant itself (name, type, distance) is real data passed in from the
/// list screen. The menu comes from [MenuRepository]; while that is the
/// placeholder source, a banner says so plainly.
class WaslRestaurantDetailsScreen extends StatefulWidget {
  final int merchantId;
  final String merchantName;
  final String? merchantType;
  final String? addressDetails;
  final double? distanceKm;

  /// Restaurant location — becomes the order's pickup point at checkout.
  final double? latitude;
  final double? longitude;

  /// هل المتجر بيستقبل طلبات دلوقتي؟ بييجي مع `/stores/nearby`.
  ///
  /// الافتراضي `true` عن قصد: لو الحقل ناقص من الرد (نسخة سيرفر أقدم) بنسيب
  /// العميل يطلب والسيرفر هو اللي يرفض، بدل ما نقفل متجر شغال بالغلط.
  /// السيرفر هو البوابة الحقيقية — `assertMerchantCanTakeOrders` بترفض
  /// الطلب مهما كان اللي الشاشة عرضته.
  final bool isAcceptingOrders;

  const WaslRestaurantDetailsScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
    this.merchantType,
    this.addressDetails,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.isAcceptingOrders = true,
  });

  @override
  State<WaslRestaurantDetailsScreen> createState() =>
      _WaslRestaurantDetailsScreenState();
}

class _WaslRestaurantDetailsScreenState
    extends State<WaslRestaurantDetailsScreen> {
  final _repository = MenuRepository.instance;
  final _cart = CartController.instance;

  bool _isLoading = true;
  String? _error;

  List<MenuSection> _sections = [];
  List<Product> _products = [];

  /// null = the derived "الأكثر طلباً" tab, otherwise a section id.
  int? _selectedSectionId;

  /// Free-text filter over the whole menu. While non-empty it overrides the
  /// selected tab, so searching never hides a matching item in another section.
  String _search = '';

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _load();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sections = await _repository.getSections(widget.merchantId);
      final products = await _repository.getProducts(widget.merchantId);
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _products = products;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل قائمة الطعام، حاول مرة أخرى';
        _isLoading = false;
      });
    }
  }

  /// Items under the selected tab. The first tab is "الأكثر طلباً", derived
  /// from the popular flag rather than being a real section.
  List<Product> get _visibleProducts {
    // A search spans the whole menu — restricting it to the open tab would hide
    // matches the customer can plainly see should be there.
    final query = _search.trim();
    if (query.isNotEmpty) {
      return _products
          .where((p) =>
              p.name.contains(query) ||
              (p.description ?? '').contains(query))
          .toList();
    }

    if (_selectedSectionId == null) {
      final popular = _products.where((p) => p.isPopular).toList();
      return popular.isEmpty ? _products : popular;
    }
    return _products.where((p) => p.sectionId == _selectedSectionId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              if (!widget.isAcceptingOrders) _buildClosedBanner(),
              if (_repository.isPlaceholderData) const WaslDemoDataBanner(),
              if (!_isLoading && _error == null) _buildMenuSearch(),
              // Tabs are meaningless while a search is active — results span
              // every section, so showing a "selected" tab would be a lie.
              if (!_isLoading && _error == null && _search.trim().isEmpty)
                _buildTabs(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildCartBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(WaslSpacing.radiusLg),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              WaslCircleBack(onTap: () => Navigator.pop(context)),
              const Spacer(),
              _cartIconButton(),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
            child: Image.asset(
              WaslAssets.coverFor(widget.merchantId),
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: AppColors.logoGradient,
                  borderRadius: BorderRadius.circular(WaslSpacing.radiusLg),
                ),
                child: const Icon(Icons.restaurant_rounded,
                    color: Colors.white, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.merchantName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
          if ((widget.merchantType ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.merchantType!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildFactsRow(),
        ],
      ),
    );
  }

  /// شريط بيقول إن المتجر مقفول، فوق القائمة مباشرة.
  ///
  /// المتجر المقفول بيفضل ظاهر وبيتصفّح — القائمة والأسعار كلها باينة. اللي
  /// بيتمنع هو الطلب بس. متجر بيختفي وقت ما يقفل بيتقري «قفل خالص» ويخلي
  /// الناس تدوّر عليه؛ متجر باهت ومكتوب عليه إنه مقفول بيتقري «تعالى بعدين»،
  /// وده الصح.
  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // `withValues` مش `withOpacity`: الأخيرة اتشالت من الـ API الجديد،
        // وباقي الملف لسه بيستخدمها من زمان. مابنزوّدش استخدام جديد لحاجة
        // مهجورة حتى لو الموجود كتير.
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_outlined, size: 18, color: AppColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'المتجر مقفول دلوقتي ومش بيستقبل طلبات. تقدر تتصفّح القائمة '
              'والأسعار، وترجع تطلب لما يفتح.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Only facts we actually have. No invented rating or prep time.
  Widget _buildFactsRow() {
    final facts = <Widget>[];

    if (widget.distanceKm != null && widget.distanceKm!.isFinite) {
      facts.add(_fact(
        Icons.location_on_outlined,
        '${widget.distanceKm!.toStringAsFixed(1)} كم',
        'المسافة',
      ));
    }
    if (!_isLoading && _error == null) {
      facts.add(_fact(
        Icons.restaurant_menu_rounded,
        '${_products.length}',
        'الأصناف',
      ));
    }
    if ((widget.addressDetails ?? '').isNotEmpty) {
      facts.add(_fact(Icons.store_mall_directory_outlined,
          widget.addressDetails!, 'العنوان'));
    }

    if (facts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: facts,
      ),
    );
  }

  Widget _fact(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartIconButton() {
    return GestureDetector(
      onTap: _openCart,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: AppColors.textPrimary, size: 20),
          ),
          if (_cart.itemCount > 0)
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(WaslSpacing.radiusPill),
                ),
                child: Text(
                  '${_cart.itemCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        textDirection: TextDirection.rtl,
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'ابحث في قائمة المطعم',
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: () => setState(() => _search = ''),
                ),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = <Widget>[_tab('الأكثر طلباً', null)];
    for (final s in _sections) {
      // Skip a section with nothing in it — an empty tab is a dead end.
      if (_products.any((p) => p.sectionId == s.id)) {
        tabs.add(_tab(s.name, s.id));
      }
    }

    return Container(
      color: AppColors.white,
      height: 52,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: tabs,
      ),
    );
  }

  Widget _tab(String label, int? sectionId) {
    final selected = _selectedSectionId == sectionId;
    return GestureDetector(
      onTap: () => setState(() => _selectedSectionId = sectionId),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.logoGradient : null,
          color: selected ? null : AppColors.background,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const WaslLoader(message: 'جاري تحميل قائمة الطعام...');
    }
    if (_error != null) {
      return WaslEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'تعذّر التحميل',
        subtitle: _error,
        action: WaslButton(label: 'إعادة المحاولة', onPressed: _load),
      );
    }

    final items = _visibleProducts;
    if (items.isEmpty) {
      final searching = _search.trim().isNotEmpty;
      return WaslEmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.restaurant_menu_rounded,
        title: searching
            ? 'لا توجد نتائج لبحثك'
            : 'لا توجد أصناف في هذا القسم',
        subtitle: searching ? 'جرّب كلمة أخرى أو تصفّح الأقسام' : null,
        action: searching
            ? WaslButton(
                label: 'مسح البحث',
                onPressed: () => setState(() => _search = ''),
              )
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildProductCard(items[i]),
    );
  }

  Widget _buildProductCard(Product product) {
    final unavailable = !product.isAvailable;

    return Opacity(
      opacity: unavailable ? 0.55 : 1,
      child: GestureDetector(
        onTap: unavailable ? null : () => _openProduct(product),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
                child: Image.asset(
                  WaslAssets.dishFor(product.id),
                  width: 74,
                  height: 74,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 74,
                    height: 74,
                    color: AppColors.background,
                    child: const Icon(Icons.fastfood_rounded,
                        color: AppColors.primary, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((product.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.description!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          unavailable
                              ? 'غير متاح حالياً'
                              : '${product.hasSizes ? 'يبدأ من ' : ''}'
                                  '${product.startingPrice.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: unavailable
                                ? AppColors.textSecondary
                                : AppColors.primary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const Spacer(),
                        if (!unavailable)
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: AppColors.logoGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 18),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sticky bar that appears once the cart has something in it.
  Widget? _buildCartBar() {
    if (_cart.isEmpty) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GestureDetector(
          onTap: _openCart,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: AppColors.logoGradient,
              borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_cart.itemCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'عرض السلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Cairo',
                  ),
                ),
                const Spacer(),
                Text(
                  '${_cart.subtotal.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProduct(Product product) async {
    // 🔒 المتجر المقفول: القائمة بتتقري بس الطلب متمنوع. بنرد برسالة بدل ما
    // اللمسة تروح في الفراغ — لمسة مابتعملش حاجة بتتقري كأن التطبيق باظ.
    // السيرفر بيرفض الطلب برضه (`assertMerchantCanTakeOrders`)، فده تحسين
    // للتجربة مش اعتماد أمني.
    if (!widget.isAcceptingOrders) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'المتجر مقفول دلوقتي ومش بيستقبل طلبات',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    await showWaslProductSheet(
      context: context,
      product: product,
      merchantId: widget.merchantId,
      merchantName: widget.merchantName,
      merchantLat: widget.latitude,
      merchantLng: widget.longitude,
    );
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaslCartScreen()),
    );
  }
}
