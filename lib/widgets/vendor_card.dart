// lib/widgets/vendor_card.dart
// v3.0 — Universal Card: Sketch Design (Top Row + Bottom Menu Scroll)
//
// ✅ NEW DESIGN:
//   TOP SECTION (Row):
//     Left  40% — vendor image / emoji gradient placeholder
//     Right 60% — vendor name, cuisine tags, rating, distance, open/closed badge, min order
//   BOTTOM SECTION (horizontal scroll):
//     3-4 menu item mini cards — image, name, price, Add+ button
//     Last card — "View all X items →"
//   Direct Add+ button → adds to cart WITHOUT opening vendor screen
//   Tap image/name on item → opens vendor screen scrolled to that item
//
// ✅ PERFORMANCE:
//   MenuItemCache — static shared cache, fetches once per vendor per session
//   All cards share same cache, no duplicate DB calls
//
// ✅ SHIMMER:
//   Top section shimmer block
//   Bottom section 3 shimmer mini cards
//
// ✅ UNIVERSAL:
//   Use this card in Home, StreetFood, Sweets screens
//   Pass layout: 'list' (full width) or 'grid' (half width) via constructor
//
// ✅ THEME:
//   Light theme — primary #FF6B35, background #FFF8F0, surface #FFFFFF
//   Colors from _VC local constants (safe to use anywhere)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../providers/cart_provider.dart';
import '../constants/eta_helper.dart';

// ─── Local theme constants ────────────────────────────────────
class _VC {
  static const background = Color(0xFFFFF8F0);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF3D3D3D);
  static const textMuted = Color(0xFF6B7280);
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFFF1EB);
  static const accentBorder = Color(0xFFFFD4BC);
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const error = Color(0xFFDC2626);
  static const errorLight = Color(0xFFFEE2E2);
  static const gold = Color(0xFFD97706);
  static const shadow = Color(0x14000000);
}

// ─── Static Menu Item Cache (shared across all cards) ─────────
// Ek vendor ke items ek baar fetch hote hain, phir cache se serve hote hain
class MenuItemCache {
  MenuItemCache._();
  static final MenuItemCache instance = MenuItemCache._();

  final Map<String, List<MenuItemModel>> _cache = {};
  final Set<String> _fetching = {};

  // Callback-based fetch: widget rebuild hoga jab data aayega
  Future<List<MenuItemModel>> getItems(String vendorId) async {
    if (_cache.containsKey(vendorId)) return _cache[vendorId]!;
    if (_fetching.contains(vendorId)) {
      // Wait karo jab tak fetch complete na ho
      while (_fetching.contains(vendorId)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cache[vendorId] ?? [];
    }
    _fetching.add(vendorId);
    try {
      final data = await Supabase.instance.client
          .from('menu_items')
          .select()
          .eq('vendor_id', vendorId)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(8); // 8 fetch karo, 4 dikhao — baaki "View all" pe
      final items = (data as List)
          .map((e) => MenuItemModel.fromMap(e))
          .toList();
      _cache[vendorId] = items;
      return items;
    } catch (_) {
      _cache[vendorId] = [];
      return [];
    } finally {
      _fetching.remove(vendorId);
    }
  }

  void invalidate(String vendorId) => _cache.remove(vendorId);
  void invalidateAll() => _cache.clear();
}

// ─── VendorCard ───────────────────────────────────────────────
// layout: 'list' = full width (home, restaurants)
//         'grid' = half width (street food, sweets grid)
class VendorCard extends StatefulWidget {
  final VendorModel vendor;
  final VoidCallback onTap;
  final String layout; // 'list' | 'grid'

  const VendorCard({
    super.key,
    required this.vendor,
    required this.onTap,
    this.layout = 'list',
  });

  @override
  State<VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<VendorCard> {
  List<MenuItemModel>? _menuItems;
  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    if (widget.layout == 'grid') {
      _fetchItems();
    } else {
      _loadingItems = false;
    }
  }

  Future<void> _fetchItems() async {
    final items = await MenuItemCache.instance.getItems(widget.vendor.id);
    if (mounted) {
      setState(() {
        _menuItems = items;
        _loadingItems = false;
      });
    }
  }

  // ── Emoji + gradient per category ──────────────────────────
  String _emoji(String cat) {
    const map = {
      'Momos': '🥟',
      'Burger': '🍔',
      'Chowmein': '🍜',
      'Pizza': '🍕',
      'Chaat': '🍛',
      'Maggi': '🍝',
      'Sandwich': '🥪',
      'Shake': '🥤',
      'Samosa': '🥘',
      'Rolls': '🌯',
      'Noodles': '🍜',
      'North Indian': '🍱',
      'Biryani': '🍚',
      'South Indian': '🥘',
      'Sweets': '🍬',
      'Cakes': '🎂',
      'Ice Cream': '🍦',
    };
    final first = cat.split(',').first.trim();
    return map[first] ?? '🍽️';
  }

  List<Color> _gradientColors(String cat) {
    const map = {
      'Momos': [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
      'Burger': [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
      'Chowmein': [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
      'Pizza': [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
      'Chaat': [Color(0xFFFFF1F2), Color(0xFFFECDD3)],
      'Shake': [Color(0xFFECFEFF), Color(0xFFA5F3FC)],
      'Sandwich': [Color(0xFFF5F3FF), Color(0xFFDDD6FE)],
      'Maggi': [Color(0xFFFEFCE8), Color(0xFFFEF08A)],
      'Sweets': [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
      'North Indian': [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
      'Biryani': [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
    };
    final first = cat.split(',').first.trim();
    return map[first] ?? [const Color(0xFFFFF1EB), const Color(0xFFFFD4BC)];
  }

  // ── Delivery charge text ────────────────────────────────────
  String _deliveryText() {
    final km = widget.vendor.distanceKm;
    if (km == null) return 'Free Delivery';
    final charge = context.read<CartProvider>().calculateDeliveryCharge(km);
    if (charge <= 0) return 'Free Delivery';
    return '+₹${charge.toStringAsFixed(0)} delivery';
  }

  // ── Add to cart ─────────────────────────────────────────────
  Future<void> _addToCart(MenuItemModel item) async {
    HapticFeedback.lightImpact();
    final cart = context.read<CartProvider>();
    final currentVendor = cart.currentVendor;

    if (currentVendor != null && currentVendor.id != widget.vendor.id) {
      // Different vendor — show confirm dialog
      final confirm = await _showClearCartDialog(currentVendor.name);
      if (!confirm) return;
      cart.forceAddItem(item, widget.vendor);
    } else {
      final added = cart.addItem(item, widget.vendor);
      if (!added && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cart limit reached or max order value exceeded'),
            backgroundColor: _VC.error,
          ),
        );
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} added to cart ✓'),
          backgroundColor: _VC.success,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<bool> _showClearCartDialog(String currentVendorName) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _VC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _VC.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🛒', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Start New Cart?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _VC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your cart has items from $currentVendorName. Adding from a new vendor will clear your cart.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: _VC.textSecondary,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _VC.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _VC.textMuted,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _VC.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'Clear & Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isGrid = widget.layout == 'grid';
    return isGrid ? _buildGridCard() : _buildListCard();
  }

  // ════════════════════════════════════════════════════════════
  // LIST CARD — Full width (Home, Restaurants sections)
  // ════════════════════════════════════════════════════════════
  Widget _buildListCard() {
    final v = widget.vendor;
    final isOpen = v.isOpenNow;
    final gradColors = _gradientColors(v.category);
    final hasImage = v.imageUrl != null && v.imageUrl!.isNotEmpty;
    final tagsText = v.category
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .join(', ');

    return GestureDetector(
      onTap: isOpen ? widget.onTap : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _VC.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _VC.border),
          boxShadow: const [
            BoxShadow(color: _VC.shadow, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ─────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: v.imageUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      color: !isOpen ? Colors.black38 : null,
                      colorBlendMode: BlendMode.darken,
                      placeholder: (_, __) =>
                          _imagePlaceholder(gradColors, v.category, 72),
                      errorWidget: (_, __, ___) =>
                          _imagePlaceholder(gradColors, v.category, 72),
                    )
                  : _imagePlaceholder(gradColors, v.category, 72),
            ),
            const SizedBox(width: 12),
            // ── Info ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          v.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _VC.textPrimary,
                            fontFamily: 'Poppins',
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (v.vendorBadge != null &&
                          v.vendorBadge!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _VC.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            v.vendorBadge!.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (tagsText.isNotEmpty)
                    Text(
                      tagsText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _VC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (v.rating != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: _VC.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          v.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _VC.textSecondary,
                            fontFamily: 'SpaceMono',
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: _VC.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        EtaHelper.getEta(distanceKm: v.distanceKm),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _VC.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (v.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: _VC.accent,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${v.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _VC.textMuted,
                            fontFamily: 'SpaceMono',
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isOpen) ...[
                    const SizedBox(height: 5),
                    Text(
                      v.opensInLabel ?? 'Closed Now',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _VC.error,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // GRID CARD — Half width (Street Food, Sweets grid)
  // ════════════════════════════════════════════════════════════
  Widget _buildGridCard() {
    final v = widget.vendor;
    final isOpen = v.isOpenNow;
    final gradColors = _gradientColors(v.category);
    final hasImage = v.imageUrl != null && v.imageUrl!.isNotEmpty;
    final tags = v.category
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .take(2)
        .toList();

    return GestureDetector(
      onTap: isOpen ? widget.onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: _VC.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _VC.border),
          boxShadow: const [
            BoxShadow(color: _VC.shadow, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP ROW (image + info) ─────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image (square)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: v.imageUrl!,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                _imagePlaceholder(gradColors, v.category, 68),
                            errorWidget: (_, __, ___) =>
                                _imagePlaceholder(gradColors, v.category, 68),
                          )
                        : _imagePlaceholder(gradColors, v.category, 68),
                  ),
                  const SizedBox(width: 8),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                v.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _VC.textPrimary,
                                  fontFamily: 'Poppins',
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        _openBadge(isOpen, small: true),
                        const SizedBox(height: 4),
                        // Tags
                        Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _VC.accentLight,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      color: _VC.accent,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        // Rating + distance
                        Row(
                          children: [
                            if (v.rating != null) ...[
                              const Icon(
                                Icons.star_rounded,
                                color: _VC.gold,
                                size: 11,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                v.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _VC.textSecondary,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (v.distanceKm != null) ...[
                              const Icon(
                                Icons.location_on_rounded,
                                size: 10,
                                color: _VC.accent,
                              ),
                              const SizedBox(width: 1),
                              Text(
                                '${v.distanceKm!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _VC.textMuted,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── DIVIDER ───────────────────────────────────────
            Container(height: 1, color: _VC.border),

            // ── BOTTOM — Menu items ───────────────────────────
            _buildMenuItemsRow(isOpen),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BOTTOM SECTION — Menu items horizontal scroll (shared)
  // ════════════════════════════════════════════════════════════
  Widget _buildMenuItemsRow(bool isOpen) {
    // Loading state
    if (_loadingItems) {
      return SizedBox(
        height: 168,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: const Color(0xFFEEEBE6),
            highlightColor: const Color(0xFFF7F5F2),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      );
    }

    // Empty state
    if (_menuItems == null || _menuItems!.isEmpty) {
      return Container(
        height: 44,
        alignment: Alignment.center,
        child: const Text(
          'Menu loading...',
          style: TextStyle(
            fontSize: 11,
            color: _VC.textMuted,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }

    final items = _menuItems!;
    final showItems = items.take(4).toList();
    final totalCount = items.length;

    return SizedBox(
      height: 168,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        itemCount: showItems.length + 1, // +1 for "View all"
        itemBuilder: (_, i) {
          // Last item = "View all X items →"
          if (i == showItems.length) {
            return GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _VC.accentLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _VC.accentBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: _VC.accent,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View all\n$totalCount items',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: _VC.accent,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final item = showItems[i];
          final hasImg = item.imageUrl != null && item.imageUrl!.isNotEmpty;
          final qty = context.watch<CartProvider>().getQuantity(item.id);

          return GestureDetector(
            // Tap image/name → open vendor screen
            onTap: widget.onTap,
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _VC.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: qty > 0 ? _VC.accentBorder : _VC.border,
                  width: qty > 0 ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NEW:
                  // Food image
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(9),
                        ),
                        child: hasImg
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                width: 100,
                                height: 96,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _miniItemPlaceholder(item.category),
                              )
                            : _miniItemPlaceholder(item.category),
                      ),
                      if (item.isDiscounted &&
                          item.originalPrice != null &&
                          item.originalPrice! > item.appPrice)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _VC.success,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '₹${(item.originalPrice! - item.appPrice).toStringAsFixed(0)} OFF',
                              style: const TextStyle(
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
                  // Name + Price + Add button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _VC.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 3),
                        // NEW:
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.isDiscounted &&
                                      item.originalPrice != null &&
                                      item.originalPrice! > item.appPrice)
                                    Text(
                                      '₹${item.originalPrice!.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: _VC.textMuted,
                                        fontFamily: 'SpaceMono',
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  Text(
                                    '₹${item.appPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _VC.accent,
                                      fontFamily: 'SpaceMono',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Add+ button — direct cart add
                            GestureDetector(
                              onTap: isOpen ? () => _addToCart(item) : null,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isOpen ? _VC.accent : _VC.border,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: qty > 0
                                      ? Text(
                                          '$qty',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Poppins',
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
  Widget _openBadge(bool isOpen, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 7,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: isOpen ? _VC.successLight : _VC.errorLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOpen
              ? _VC.success.withOpacity(0.3)
              : _VC.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 4 : 5,
            height: small ? 4 : 5,
            decoration: BoxDecoration(
              color: isOpen ? _VC.success : _VC.error,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: small ? 3 : 4),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: TextStyle(
              fontSize: small ? 8 : 9,
              fontWeight: FontWeight.w700,
              color: isOpen ? _VC.success : _VC.error,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(
    List<Color> colors,
    String category,
    double size, {
    bool full = false,
  }) {
    return Container(
      width: full ? double.infinity : size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(_emoji(category), style: TextStyle(fontSize: size * 0.38)),
      ),
    );
  }

  Widget _timingBadge(VendorModel v) {
    if (!v.hasOwnTiming) return const SizedBox.shrink();
    final closed = !v.isWithinOwnHours;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFFFFBEB) : const Color(0xFFFFF1EB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: closed
              ? const Color(0xFFF59E0B).withOpacity(0.5)
              : _VC.accentBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(closed ? '⏰' : '🕐', style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            closed ? (v.opensInLabel ?? 'Closed') : v.timingRangeLabel ?? '',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              color: closed ? const Color(0xFFB45309) : _VC.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniItemPlaceholder(String category) {
    return Container(
      width: 100,
      height: 96,
      color: const Color(0xFFF0EDE8),
      child: Center(
        child: Text(_emoji(category), style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
