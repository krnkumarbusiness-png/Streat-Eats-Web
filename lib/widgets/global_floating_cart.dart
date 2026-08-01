import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../constants/colors.dart';
import '../constants/globals.dart';

class GlobalCartWrapper extends StatelessWidget {
  final Widget child;
  const GlobalCartWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<int>(
          valueListenable: CartVisibilityControl.hideCount,
          builder: (context, hideCount, _) {
            if (hideCount > 0) return const SizedBox.shrink();
            return const GlobalFloatingCart();
          },
        ),
      ],
    );
  }
}

class GlobalFloatingCart extends StatefulWidget {
  const GlobalFloatingCart({super.key});

  @override
  State<GlobalFloatingCart> createState() => _GlobalFloatingCartState();
}

class _GlobalFloatingCartState extends State<GlobalFloatingCart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        if (cart.totalItems == 0) return const SizedBox.shrink();

        final subtotal = cart.subtotal;
        double addonSubtotal = cart.addonSubtotal;
        final total = (subtotal + addonSubtotal + cart.tipAmount) - cart.appliedDiscount;

        return Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 80,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                globalNavigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const CartScreen(isStandalone: true)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
