import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';

class CartUtils {
  static void handleCartAddItem(
    BuildContext context,
    MenuItemModel item,
    VendorModel vendor, {
    PortionType portionType,
    double? effectivePrice,
    VoidCallback? onSuccess,
    VoidCallback? onLimitReached,
  }) {
    final cart = context.read<CartProvider>();
    final result = cart.addItem(
      item,
      vendor,
      portionType: portionType,
      effectivePrice: effectivePrice,
    );

    if (result == CartAddResult.success) {
      onSuccess?.call();
    } else if (result == CartAddResult.limitReached) {
      if (onLimitReached != null) {
        onLimitReached.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot add more items. Cart limit reached.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } else if (result == CartAddResult.vendorConflict) {
      _showConflictDialog(
        context,
        cart,
        item,
        vendor,
        portionType: portionType,
        effectivePrice: effectivePrice,
        onSuccess: onSuccess,
      );
    }
  }

  static void _showConflictDialog(
    BuildContext context,
    CartProvider cart,
    MenuItemModel item,
    VendorModel vendor, {
    PortionType portionType,
    double? effectivePrice,
    VoidCallback? onSuccess,
  }) {
    final currentVendorName = cart.currentVendor?.name ?? 'another vendor';
    final newVendorName = vendor.name;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0), // Warm background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFFF6B35), // Orange accent
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Replace cart items?',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your cart has items from $currentVendorName. Do you want to clear the cart and add items from $newVendorName?',
                  style: const TextStyle(
                    color: Color(0xFF6B6560),
                    fontSize: 15,
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          cart.clearCartAndAdd(
                            item,
                            vendor,
                            portionType: portionType,
                            effectivePrice: effectivePrice,
                          );
                          onSuccess?.call();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6B35),
                          side: const BorderSide(
                            color: Color(0xFFFF6B35),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'START FRESH',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
