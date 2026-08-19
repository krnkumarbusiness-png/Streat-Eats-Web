import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../services/offer_service.dart';
import '../utils/cart_utils.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';
import 'all_offers_screen.dart';
import '../constants/app_snackbar.dart';
import '../constants/globals.dart';
import '../models/vendor_model.dart';

class CartScreen extends StatefulWidget {
  final bool isStandalone;
  const CartScreen({super.key, this.isStandalone = false});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  final OfferService _offerService = OfferService();
  List<Map<String, dynamic>> _cartOffers = [];
  List<Map<String, dynamic>> _addonItems = [];
  bool _isLoadingOffers = true;
  Map<String, dynamic>? _manuallyAppliedOffer;
  late CartProvider _cartProvider;

  @override
  void initState() {
    super.initState();
    CartVisibilityControl.hide();
    _cartProvider = context.read<CartProvider>();
    _cartProvider.addListener(_onCartUpdated);
    
    _fetchOffersAndAddons();
  }

  @override
  void dispose() {
    CartVisibilityControl.show();
    _cartProvider.removeListener(_onCartUpdated);
    super.dispose();
  }

  Future<void> _fetchOffersAndAddons() async {
    try {
      final results = await Future.wait([
        _offerService.getCartOffers(),
        _offerService.getAddonItems(),
      ]);
      if (mounted) {
        setState(() {
          _cartOffers = List<Map<String, dynamic>>.from(results[0]);
          _addonItems = List<Map<String, dynamic>>.from(results[1]);
          _isLoadingOffers = false;
          
          if (_cartProvider.appliedDiscount > 0 && _cartOffers.isNotEmpty) {
             for (final offer in _cartOffers) {
                if (offer['discount_amount'] == _cartProvider.appliedDiscount) {
                   _manuallyAppliedOffer = offer;
                   break;
                }
             }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOffers = false);
      }
    }
  }

  void _onCartUpdated() {
    if (!mounted) return;
    if (_manuallyAppliedOffer != null) {
      final minVal = (_manuallyAppliedOffer!['min_cart_value'] as num?)?.toDouble() ?? 0;
      final effectiveCartValue = _cartProvider.subtotal + _cartProvider.addonSubtotal;
      if (effectiveCartValue < minVal) {
        setState(() {
          _manuallyAppliedOffer = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _cartProvider.clearDiscount();
        });
      }
    }
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Login Required 🔐',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Please login or create an account to place your order.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text(
              'Later',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Login',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, cart),

            if (cart.isEmpty)
              Expanded(child: _buildEmptyCart(context))
            else ...[
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildVendorStrip(cart),
                      () {
                        final widgets = <Widget>[];
                        final seenVendorIds = <String>{};
                        final vendors = <VendorModel>[];
                        for (final ci in cart.items.values) {
                          if (!seenVendorIds.contains(ci.vendor.id)) {
                            seenVendorIds.add(ci.vendor.id);
                            vendors.add(ci.vendor);
                          }
                        }
                        for (final vendor in vendors) {
                          final vendorItems = cart.items.values
                              .where((ci) => ci.vendor.id == vendor.id)
                              .toList();
                          if (cart.uniqueVendorCount > 1) {
                            widgets.add(
                              Container(
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.warning.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.store_rounded,
                                      color: AppColors.warning,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        vendor.name,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          for (final cartItem in vendorItems) {
                            widgets.add(
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  0,
                                ),
                                child: _CartItemTile(cartItem: cartItem),
                              ),
                            );
                          }
                        }
                        return Column(children: widgets);
                      }(),
                      if (_addonItems.isNotEmpty) _buildAddonSection(cart),
                      if (_cartOffers.isNotEmpty) _buildOffersSection(cart),
                      _buildWhyZingooCard(),
                      _buildTipSelector(context, cart),
                      _buildBillSummary(cart),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _buildCheckoutButton(context, cart),
            ],
          ],
        ),
      ),
    );
  }

  // ── Vendor Strip ──────────────────────────────────────────────
  Widget _buildVendorStrip(CartProvider cart) {
    if (cart.currentVendor == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cart.currentVendor!.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  cart.uniqueVendorCount > 1
                      ? '${cart.uniqueVendorCount} vendors — separate orders will be placed'
                      : 'Items from this vendor only',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your Cart',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (!cart.isEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'Clear Cart? 🗑️',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    content: const Text(
                      'All items will be removed. Are you sure?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          context.read<CartProvider>().clearCart();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Yes, Clear',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.error.withOpacity(0.20)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty Cart ────────────────────────────────────────────────
  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🛒', style: TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add items from a vendor to get started',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              elevation: 0,
            ),
            child: const Text(
              'Browse Vendors',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Why Zingoo Card ──────────────────────────────────────────
  Widget _buildWhyZingooCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why Streat Eats? 🤔',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _whyRow('🥟', 'Real street food — not available on Other Platforms'),
          const SizedBox(height: 6),
          _whyRow('⚡', 'Faster delivery — hyper local, only your city'),
          const SizedBox(height: 6),
          _whyRow('🤝', 'Known local vendors — not cloud kitchens'),
        ],
      ),
    );
  }

  Widget _whyRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  // ── Bill Summary ────────────────────────────────────────────
  Widget _buildBillSummary(CartProvider cart) {
    final subtotal = cart.subtotal;
    double addonSubtotal = 0;
    if (_addonItems.isNotEmpty) {
      for (final addon in _addonItems) {
        final addonId = addon['id']?.toString() ?? '';
        final addonPrice = addon['price'] as int? ?? 0;
        final qty = cart.getAddonQuantity(addonId);
        addonSubtotal += (qty * addonPrice);
      }
    }
    
    final discount = _manuallyAppliedOffer != null ? (_manuallyAppliedOffer!['discount_amount'] as num?)?.toDouble() ?? 0 : 0.0;
    final total = (subtotal + addonSubtotal) - discount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('Items Total', '₹${subtotal.toStringAsFixed(2)}'),
          if (addonSubtotal > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Add-ons Total', '₹${addonSubtotal.toStringAsFixed(2)}'),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Item Discount', '-₹${discount.toStringAsFixed(2)}', valueColor: AppColors.success),
          ],
          const Divider(height: 24, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Delivery, platform & packaging fees are calculated at checkout',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  // ── v5.0: Addon Items Section ────────
  Widget _buildAddonSection(CartProvider cart) {
    if (_isLoadingOffers) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Add something extra? 🍟',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Rider will bring these along',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190, // Increased height for the cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _addonItems.length,
            itemBuilder: (context, index) {
              final addon = _addonItems[index];
              final addonId = addon['id']?.toString() ?? '';
              final addonName = addon['name'] as String? ?? '';
              final addonPrice = addon['price'] as int? ?? 0;
              final imageUrl = addon['image_url'] as String?;
              final qty = cart.getAddonQuantity(addonId);

              return Container(
                width: 120, // Increased width
                margin: EdgeInsets.only(
                  right: index < _addonItems.length - 1 ? 12 : 0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: SizedBox(
                        height: 90, // Increased image height
                        width: double.infinity,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover, // Fixed height and box fit
                                placeholder: (_, __) => Container(
                                  color: AppColors.primary.withOpacity(0.06),
                                  child: const Center(
                                    child: Text('🍟', style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.primary.withOpacity(0.06),
                                  child: const Center(
                                    child: Text('🍟', style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.primary.withOpacity(0.06),
                                child: const Center(
                                  child: Text('🍟', style: TextStyle(fontSize: 24)),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Text(
                        addonName,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '₹$addonPrice',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                      child: qty == 0
                          ? GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                cart.addAddon(addon);
                              },
                              child: Container(
                                width: double.infinity,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text(
                                    '+ Add',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      cart.removeAddon(addonId);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.remove, size: 14, color: AppColors.success),
                                    ),
                                  ),
                                  Text(
                                    '$qty',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      cart.addAddon(addon);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.add, size: 14, color: AppColors.success),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFFD1FAE5);
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFFD1FAE5);
    }
  }

  // ── v5.0: Offers Section ────────
  Widget _buildOffersSection(CartProvider cart) {
    if (_isLoadingOffers) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Offers',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final selectedOffer = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllOffersScreen()),
                  );
                  if (selectedOffer != null && mounted) {
                    final discAmt = (selectedOffer['discount_amount'] as num?)?.toInt() ?? 0;
                    setState(() {
                      _manuallyAppliedOffer = selectedOffer as Map<String, dynamic>;
                    });
                    cart.applyDiscount(discAmt, offerDetails: selectedOffer as Map<String, dynamic>);
                    _showOfferAppliedPopup(context, selectedOffer['coupon_code'] as String? ?? 'APPLIED', discAmt);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cartOffers.length,
            itemBuilder: (context, index) {
              final offer = _cartOffers[index];
              final minVal = (offer['min_cart_value'] as num?)?.toDouble() ?? 0;
              final discAmt = (offer['discount_amount'] as num?)?.toInt() ?? 0;
              final title = offer['card_title'] as String? ?? offer['title'] as String? ?? 'Special Offer';
              final emoji = offer['emoji'] as String? ?? '🎉';
              
              final effectiveCartValue = cart.subtotal + cart.addonSubtotal;
              final isEligible = effectiveCartValue >= minVal;
              final isApplied = _manuallyAppliedOffer != null && _manuallyAppliedOffer!['id'] == offer['id'];
              
              final bgColor = _parseColor(offer['card_color'] as String?);
              
              return GestureDetector(
                 onTap: () {
                    HapticFeedback.lightImpact();
                    if (isApplied) {
                       setState(() => _manuallyAppliedOffer = null);
                       cart.clearDiscount();
                    } else if (isEligible) {
                       setState(() => _manuallyAppliedOffer = offer);
                       cart.applyDiscount(discAmt, offerDetails: offer);
                       _showOfferAppliedPopup(context, offer['coupon_code'] as String? ?? 'APPLIED', discAmt);
                    } else {
                       // Not eligible — show bottom sheet
                       final amountNeeded = (minVal - effectiveCartValue).ceil();
                       _showNotEligibleBottomSheet(context, amountNeeded);
                    }
                 },
                 child: Container(
                   width: 140,
                   margin: const EdgeInsets.only(right: 12),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       Expanded(
                         child: Container(
                           decoration: BoxDecoration(
                             color: bgColor,
                             borderRadius: BorderRadius.circular(16),
                             border: isApplied ? Border.all(color: AppColors.success, width: 2) : null,
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.05),
                                 blurRadius: 4,
                                 offset: const Offset(0, 2),
                               ),
                             ],
                           ),
                           child: Stack(
                             children: [
                               Padding(
                                 padding: const EdgeInsets.all(12),
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       title,
                                       style: const TextStyle(
                                         fontFamily: 'Poppins',
                                         fontSize: 14,
                                         fontWeight: FontWeight.w800,
                                         color: AppColors.textPrimary,
                                         height: 1.2,
                                       ),
                                       maxLines: 2,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                     const SizedBox(height: 8),
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                       decoration: BoxDecoration(
                                         color: Colors.white,
                                         borderRadius: BorderRadius.circular(20),
                                       ),
                                       child: Text(
                                         'Min ₹${minVal.toInt()}',
                                         style: const TextStyle(
                                           fontFamily: 'Poppins',
                                           fontSize: 9,
                                           fontWeight: FontWeight.w700,
                                           color: AppColors.textPrimary,
                                         ),
                                       ),
                                     ),
                                     const Spacer(),
                                     Align(
                                       alignment: Alignment.bottomRight,
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.end,
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Text(
                                             emoji,
                                             style: const TextStyle(fontSize: 32),
                                           ),
                                           if (isApplied)
                                             const Text(
                                               'Click to remove',
                                               style: TextStyle(
                                                 fontFamily: 'Poppins',
                                                 fontSize: 8,
                                                 fontWeight: FontWeight.w700,
                                                 color: Color(0xFFDC2626),
                                               ),
                                             )
                                           else if (isEligible)
                                             const Text(
                                               'Click to apply',
                                               style: TextStyle(
                                                 fontFamily: 'Poppins',
                                                 fontSize: 8,
                                                 fontWeight: FontWeight.w700,
                                                 color: Color(0xFF15803D),
                                               ),
                                             ),
                                         ],
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                               if (isApplied)
                                 Positioned(
                                   top: 8,
                                   right: 8,
                                   child: Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                     decoration: BoxDecoration(
                                       color: AppColors.success,
                                       borderRadius: BorderRadius.circular(6),
                                     ),
                                     child: const Text(
                                       'Applied',
                                       style: TextStyle(
                                         color: Colors.white,
                                         fontSize: 8,
                                         fontWeight: FontWeight.w800,
                                         fontFamily: 'Poppins',
                                       ),
                                     ),
                                   ),
                                 ),
                             ],
                           ),
                         ),
                       ),
                       const SizedBox(height: 6),
                       if (!isEligible)
                         Center(
                           child: Text(
                             'Add ₹${(minVal - effectiveCartValue).ceil()} more',
                             style: const TextStyle(
                               color: AppColors.warning,
                               fontSize: 10,
                               fontWeight: FontWeight.w600,
                               fontFamily: 'Poppins',
                             ),
                           ),
                         )
                       else
                         const SizedBox(height: 14), // placeholder for height matching
                     ],
                   ),
                 ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Not Eligible Bottom Sheet ────────
  void _showNotEligibleBottomSheet(BuildContext context, int amountNeeded) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.warning,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              // Message
              Text(
                'Add ₹$amountNeeded more to apply this offer',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your cart total is just short of the minimum required for this offer.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Explore Menu button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close bottom sheet
                    // Navigate back to home screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Explore Menu',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── v5.0: Offer Applied Popup ────────
  void _showOfferAppliedPopup(BuildContext context, String code, int discount) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
        return _OfferAppliedDialog(code: code, discount: discount);
      },
    );
  }

  // ── Checkout Button ───────────────────────────────────────────
  Widget _buildCheckoutButton(BuildContext context, CartProvider cart) {
    final subtotal = cart.subtotal;
    double addonSubtotal = 0;
    if (_addonItems.isNotEmpty) {
      for (final addon in _addonItems) {
        final addonId = addon['id']?.toString() ?? '';
        final addonPrice = addon['price'] as int? ?? 0;
        final qty = cart.getAddonQuantity(addonId);
        addonSubtotal += (qty * addonPrice);
      }
    }
    final discount = _manuallyAppliedOffer != null ? (_manuallyAppliedOffer!['discount_amount'] as num?)?.toDouble() ?? 0 : 0.0;
    final total = (subtotal + addonSubtotal + cart.tipAmount) - discount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) {
                _showLoginPrompt(context);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipSelector(BuildContext context, CartProvider cart) {
    final tips = [0, 5, 10, 20];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🛵', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'Tip your Rider',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'They work hard to deliver your food 🙏',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: tips.map((amount) {
              final isSelected = cart.tipAmount == amount;
              final isLast = amount == tips.last;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    cart.setTip(amount);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: isLast ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        amount == 0 ? 'None' : '₹$amount',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (cart.tipAmount > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.success,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '₹${cart.tipAmount} tip added — Rider will love this!',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Cart Item Tile
// ─────────────────────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final CartItem cartItem;

  const _CartItemTile({required this.cartItem});

  String? _resolveImageUrl() {
    if (cartItem.item.imageUrl != null &&
        cartItem.item.imageUrl!.trim().isNotEmpty) {
      return cartItem.item.imageUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final imageUrl = _resolveImageUrl();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Food Image ──────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildShimmer(),
                      errorWidget: (context, url, error) =>
                          _buildFoodFallback(),
                    )
                  : _buildFoodFallback(),
            ),
          ),
          const SizedBox(width: 12),

          // ── Item Info + Qty Controls ────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),

                if (cartItem.portionLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cartItem.portionLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                ],

                Builder(
                  builder: (context) {
                    // Check if vendor price exists and is less than effective price
                    final vendorPrice = cartItem.item.vendorPrice;
                    final appPrice = cartItem.effectivePrice;
                    final hasDiscount =
                        vendorPrice > 0 && vendorPrice < appPrice;

                    if (hasDiscount && cartItem.isFirstOrderDiscounted) {
                      return Row(
                        children: [
                          Text(
                            '₹${vendorPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '₹${appPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontFamily: 'Poppins',
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      );
                    }
                    return Text(
                      '₹${appPrice.toStringAsFixed(2)} each',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      color: AppColors.error,
                      bgColor: AppColors.error.withOpacity(0.07),
                      borderColor: AppColors.error.withOpacity(0.2),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        cart.removeItem(
                          cartItem.item.id,
                          portionType: cartItem.portionType,
                        );
                      },
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${cartItem.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      color: AppColors.primary,
                      bgColor: AppColors.primary.withOpacity(0.08),
                      borderColor: AppColors.primary.withOpacity(0.2),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        CartUtils.handleCartAddItem(
                          context,
                          cartItem.item,
                          cart.currentVendor!,
                          portionType: cartItem.portionType,
                          effectivePrice: cartItem.effectivePrice,
                          onLimitReached: () {
                            final msg =
                                cart.totalItems >= CartProvider.maxTotalItems
                                ? 'Cart limit reached! Max ${CartProvider.maxTotalItems} items allowed.'
                                : 'Order value cannot exceed Rs.${CartProvider.maxOrderValue.toStringAsFixed(0)}.';
                            AppSnackBar.showError(context, msg);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Total Price ────────────────────────────────────
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${cartItem.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '× ${cartItem.quantity}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      color: AppColors.border,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodFallback() {
    final nameToCheck =
        (cartItem.item.category.toLowerCase()) +
        cartItem.item.name.toLowerCase();

    String emoji = '🍽️';

    if (nameToCheck.contains('momo')) {
      emoji = '🥟';
    } else if (nameToCheck.contains('burger')) {
      emoji = '🍔';
    } else if (nameToCheck.contains('pizza')) {
      emoji = '🍕';
    } else if (nameToCheck.contains('chowmein') ||
        nameToCheck.contains('noodle')) {
      emoji = '🍜';
    } else if (nameToCheck.contains('sandwich')) {
      emoji = '🥪';
    } else if (nameToCheck.contains('shake') || nameToCheck.contains('juice')) {
      emoji = '🥤';
    } else if (nameToCheck.contains('chai') || nameToCheck.contains('tea')) {
      emoji = '☕';
    } else if (nameToCheck.contains('maggi')) {
      emoji = '🍝';
    } else if (nameToCheck.contains('samosa')) {
      emoji = '🥐';
    } else if (nameToCheck.contains('chaat') ||
        nameToCheck.contains('pani puri')) {
      emoji = '🫙';
    } else if (nameToCheck.contains('gulab') || nameToCheck.contains('sweet')) {
      emoji = '🍮';
    } else if (nameToCheck.contains('roll') || nameToCheck.contains('wrap')) {
      emoji = '🌯';
    } else if (nameToCheck.contains('rice') ||
        nameToCheck.contains('biryani')) {
      emoji = '🍚';
    } else if (nameToCheck.contains('dosa') || nameToCheck.contains('south')) {
      emoji = '🫓';
    }

    return Container(
      color: AppColors.primary.withOpacity(0.06),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
    );
  }
}

// ── Reusable Qty Button ──────────────────────────────────────────
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}

class _OfferAppliedDialog extends StatefulWidget {
  final String code;
  final int discount;

  const _OfferAppliedDialog({required this.code, required this.discount});

  @override
  State<_OfferAppliedDialog> createState() => _OfferAppliedDialogState();
}

class _OfferAppliedDialogState extends State<_OfferAppliedDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.code} Applied!',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "'${widget.code}' applied successfully",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'You saved ₹${widget.discount}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
