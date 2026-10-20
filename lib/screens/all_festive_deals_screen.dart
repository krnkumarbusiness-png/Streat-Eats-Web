// lib/screens/all_festive_deals_screen.dart
// Full-screen grid showing all Festive Best-Sellers & Sweet Gift Hampers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/festive_deal_model.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../providers/cart_provider.dart';
import '../utils/cart_utils.dart';
import '../constants/app_snackbar.dart';
import 'menu_item_detail_screen.dart';

// ─── Colors ───────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFFFF8F0);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFFFF6B35);
  static const primaryLight = Color(0xFFFFF1EB);
  static const primaryBorder = Color(0xFFFFD4BC);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

class AllFestiveDealsScreen extends StatefulWidget {
  final List<FestiveDealModel> deals;
  final List<dynamic> allVendors;

  const AllFestiveDealsScreen({
    super.key,
    required this.deals,
    required this.allVendors,
  });

  @override
  State<AllFestiveDealsScreen> createState() => _AllFestiveDealsScreenState();
}

class _AllFestiveDealsScreenState extends State<AllFestiveDealsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final VendorModel _centralSweetsVendor = VendorModel(
    id: 'streateats_sweets_central',
    name: 'StreatEats Festive Sweets',
    area: 'Central Festive Sweets Hub',
    phone: '',
    city: 'Haldwani',
    latitude: 29.2183,
    longitude: 79.5130,
    category: 'Sweets',
    timing: '08:00 AM - 10:00 PM',
    isActive: true,
    rating: 4.9,
  );

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  VendorModel _resolveVendor(String? vendorId) {
    if (vendorId != null) {
      final match = widget.allVendors
          .where((v) => v['id'] == vendorId)
          .firstOrNull;
      if (match != null) {
        return VendorModel.fromMap(Map<String, dynamic>.from(match));
      }
    }
    return _centralSweetsVendor;
  }

  MenuItemModel _toMenuItem(FestiveDealModel deal, VendorModel vendor) {
    return MenuItemModel(
      id: 'festive_deal_${deal.id}',
      vendorId: vendor.id,
      vendorName: 'StreatEats Festive Sweets',
      name: deal.title,
      description: deal.subtitle ?? 'Festive Special Sweet Box',
      vendorPrice: deal.price,
      appPrice: deal.price,
      originalPrice: deal.originalPrice,
      isDiscounted:
          deal.originalPrice != null && deal.originalPrice! > deal.price,
      category: 'Festive Deals',
      isAvailable: true,
      imageUrl: deal.imageUrl,
      isVeg: true,
    );
  }

  void _openDetail(FestiveDealModel deal) {
    HapticFeedback.lightImpact();
    final vendor = _resolveVendor(deal.vendorId);
    final item = _toMenuItem(deal, vendor);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemDetailScreen(
          item: item,
          vendor: vendor,
        ),
      ),
    );
  }

  void _addToCart(FestiveDealModel deal) {
    HapticFeedback.mediumImpact();
    final vendor = _resolveVendor(deal.vendorId);
    final item = _toMenuItem(deal, vendor);

    CartUtils.handleCartAddItem(
      context,
      item,
      vendor,
      onSuccess: () {
        AppSnackBar.showSuccess(context, '${deal.title} added to cart! 🍬');
      },
      onLimitReached: () {
        AppSnackBar.showError(context, 'Cart limit reached!');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.deals.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.title.toLowerCase().contains(q) ||
          (d.subtitle?.toLowerCase().contains(q) ?? false) ||
          d.badgeText.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: _C.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✨ Festive Best-Sellers',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            Text(
              '${filtered.length} Festive specials available',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: _C.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _C.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search Kaju Katli, Motichoor, Gift Box...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: _C.textMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _C.textMuted,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // ── Grid of deals ───────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🍬', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        const Text(
                          'No sweet deals found',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching with a different name',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _C.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final deal = filtered[i];
                      return _FestiveGridCard(
                        deal: deal,
                        onTap: () => _openDetail(deal),
                        onAddToCart: () => _addToCart(deal),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FestiveGridCard extends StatelessWidget {
  final FestiveDealModel deal;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _FestiveGridCard({
    required this.deal,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCartQty = cart.getQuantity('festive_deal_${deal.id}');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Image with Badge ─────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (deal.imageUrl != null && deal.imageUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: deal.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _fallbackPlaceholder(),
                      )
                    else
                      _fallbackPlaceholder(),

                    // Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          deal.badgeText,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFEF08A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Info & Add to Cart ────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _C.textPrimary,
                          ),
                        ),
                        if (deal.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            deal.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              color: _C.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Price + Add Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${deal.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _C.textPrimary,
                              ),
                            ),
                            if (deal.originalPrice != null &&
                                deal.originalPrice! > deal.price)
                              Text(
                                '₹${deal.originalPrice!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: _C.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),

                        // Add Button
                        InkWell(
                          onTap: onAddToCart,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: inCartQty > 0
                                  ? _C.primary
                                  : _C.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: inCartQty > 0
                                    ? _C.primary
                                    : _C.primaryBorder,
                              ),
                            ),
                            child: Text(
                              inCartQty > 0 ? '$inCartQty IN CART' : '+ ADD',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color:
                                    inCartQty > 0 ? Colors.white : _C.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackPlaceholder() {
    return Container(
      color: _C.primaryLight,
      child: const Center(
        child: Text('🍬', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}
