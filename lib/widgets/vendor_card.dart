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
import '../utils/cart_utils.dart';

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

  void _addToCart(MenuItemModel item) {
    HapticFeedback.lightImpact();
    CartUtils.handleCartAddItem(
      context,
      item,
      widget.vendor,
      onSuccess: () {
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGrid = widget.layout == 'grid';
    return isGrid ? _buildGridCard() : _buildListCard();
  }

  // ════════════════════════════════════════════════════════════
  // LIST CARD — Full width (Street Food, Sweets screens)
  // ════════════════════════════════════════════════════════════
  Widget _buildListCard() {
    final v = widget.vendor;
    final isOpen = v.isOpenNow;
    final hasImage = v.imageUrl != null && v.imageUrl!.isNotEmpty;
    final cats = v.categories;
    final showCats = cats.take(3).toList();
    final extraCats = cats.length > 3 ? cats.length - 3 : 0;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT: Vendor image ────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: v.imageUrl!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 90,
                        height: 90,
                        color: const Color(0xFFE8EFF1),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: const Color(0xFFE8EFF1),
                      ),
                    )
                  : Container(
                      width: 90,
                      height: 90,
                      color: const Color(0xFFE8EFF1),
                    ),
            ),
            const SizedBox(width: 12),

            // ── RIGHT: Info column ────────────────────
            Expanded(
              child: SizedBox(
                height: 90,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1 — Name + Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            v.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF161D1F),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isOpen ? 'Open' : 'Closed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // SECTION 2 — Category Chips
                    if (showCats.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: [
                          ...showCats.map(
                            (cat) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFFF6B35),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (extraCats > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFFF6B35),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '+$extraCats more',
                                style: const TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),

                    // SECTION 3 — Metrics Row + optional Opens In
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            // Rating
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFD700),
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              v.rating != null ? v.rating!.toStringAsFixed(1) : 'Not rated yet',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Delivery Time
                            const Icon(
                              Icons.schedule_rounded,
                              color: Color(0xFF6B7280),
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              v.deliveryTime,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Distance
                            if (v.distanceKm != null) ...[
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFF6B7280),
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${v.distanceKm!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // SECTION 4 — Opens In (conditional)
                        if (!isOpen &&
                            v.opensInMinutes != null &&
                            v.opensInMinutes! > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_rounded,
                                color: Color(0xFFFF6B35),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Opens in ${v.opensInMinutes} min',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFF6B35),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                            const Icon(
                              Icons.star_rounded,
                              color: _VC.gold,
                              size: 11,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              v.rating != null ? v.rating!.toStringAsFixed(1) : '-',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _VC.textSecondary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(width: 4),
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
