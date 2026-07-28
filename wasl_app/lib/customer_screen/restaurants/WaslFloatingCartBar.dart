import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/widgets/wasl_ui.dart';

import 'data/cart_controller.dart';
import 'WaslCartScreen.dart';

/// A slim "you have items waiting" bar that any screen can host.
///
/// Without it the cart is only reachable from inside the restaurant you were
/// browsing: leave that screen and the items are still there but invisible,
/// which reads as if the app silently lost them. Renders nothing when the cart
/// is empty, so hosting it is free.
class WaslFloatingCartBar extends StatefulWidget {
  const WaslFloatingCartBar({super.key});

  @override
  State<WaslFloatingCartBar> createState() => _WaslFloatingCartBarState();
}

class _WaslFloatingCartBarState extends State<WaslFloatingCartBar> {
  final _cart = CartController.instance;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_cart.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WaslCartScreen()),
        ),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: AppColors.logoGradient,
            borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لديك أصناف في السلة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    if (_cart.merchantName.isNotEmpty)
                      Text(
                        _cart.merchantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                          fontFamily: 'Cairo',
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${_cart.subtotal.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
