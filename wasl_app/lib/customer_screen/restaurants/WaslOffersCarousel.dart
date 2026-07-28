import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/theme/wasl_assets.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';

import 'data/menu_repository.dart';
import 'data/restaurant_models.dart';

/// Horizontal "عروض المطاعم" strip on the home screen.
///
/// Card layout follows the agreed reference: image panel on top with a discount
/// badge in its corner, then name, then price. Content is this project's own.
///
/// While [MenuRepository] is the placeholder source the strip renders with a
/// demo banner above it, so sample dishes and prices are never mistaken for a
/// real catalogue. It hides itself entirely if there is nothing to show.
class WaslOffersCarousel extends StatefulWidget {
  /// Restaurant the sample items are attached to, when one is known.
  final int? merchantId;
  final String? merchantName;

  const WaslOffersCarousel({super.key, this.merchantId, this.merchantName});

  @override
  State<WaslOffersCarousel> createState() => _WaslOffersCarouselState();
}

class _WaslOffersCarouselState extends State<WaslOffersCarousel> {
  final _repository = MenuRepository.instance;

  bool _isLoading = true;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await _repository.getProducts(widget.merchantId ?? 0);
      if (!mounted) return;
      setState(() {
        _products =
            products.where((p) => p.isPopular && p.isAvailable).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (_products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'عروض المطاعم',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        if (_repository.isPlaceholderData)
          const Padding(
            padding: EdgeInsets.only(right: 0),
            child: WaslDemoDataBanner(
              message:
                  'عروض تجريبية للتصميم فقط — لسه مفيش منتجات حقيقية في النظام',
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _products.length,
            itemBuilder: (_, i) => _buildOfferCard(_products[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(Product product) {
    final price = product.startingPrice;

    return Container(
      width: 168,
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dish photo, stable per product id.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.asset(
              WaslAssets.dishFor(product.id),
              height: 108,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 108,
                width: double.infinity,
                color: AppColors.primary.withOpacity(0.07),
                child: const Icon(Icons.fastfood_rounded,
                    color: AppColors.primary, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
                height: 1.35,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Text(
              '${price.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
