// lib/screens/all_recommended_screen.dart
// Full-screen 2-column grid showing items (Deals, Trending, Recommended) matching Explore Menu layout

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../services/menu_service.dart';
import '../services/vendor_service.dart';
import '../widgets/explore_item_card.dart';
import 'menu_item_detail_screen.dart';

// ─── Colors ───────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFFFF8F0);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFFFF6B35);
  static const primaryLight = Color(0xFFFFF1EB);
  static const primaryBorder = Color(0xFFFFD4BC);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF3D3D3D);
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const shadow = Color(0x14000000);
}

class AllRecommendedScreen extends StatefulWidget {
  final String title;
  final String emoji;
  final String? subtitle;
  final String fetchType; // 'deals' | 'trending' | 'recommended'
  final List<MenuItemModel>? preloadedItems;

  const AllRecommendedScreen({
    super.key,
    this.title = 'Recommended For You',
    this.emoji = '✨',
    this.subtitle,
    this.fetchType = 'recommended',
    this.preloadedItems,
  });

  @override
  State<AllRecommendedScreen> createState() => _AllRecommendedScreenState();
}

class _AllRecommendedScreenState extends State<AllRecommendedScreen> {
  final _vendorService = VendorService();
  final _menuService = MenuService();

  List<MenuItemModel> _items = [];
  bool _loading = true;
  String _sortBy = 'popular'; // 'popular' | 'price_low' | 'price_high' | 'discount_high'

  final Map<String, VendorModel> _vendorCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.fetchType == 'trending') {
      _sortBy = 'rank';
    }
    if (widget.preloadedItems != null && widget.preloadedItems!.isNotEmpty) {
      _items = List.from(widget.preloadedItems!);
      _loading = false;
    } else {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      List<MenuItemModel> items;
      if (widget.fetchType == 'deals') {
        items = await _menuService.getTodaysDeals();
      } else if (widget.fetchType == 'trending') {
        items = await _menuService.getTrendingItems();
      } else {
        items = await _menuService.getRecommendedItems();
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      _sortItems();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sortItems() {
    setState(() {
      switch (_sortBy) {
        case 'price_low':
          _items.sort((a, b) => a.appPrice.compareTo(b.appPrice));
          break;
        case 'price_high':
          _items.sort((a, b) => b.appPrice.compareTo(a.appPrice));
          break;
        case 'discount_high':
          _items.sort((a, b) {
            final discA = a.originalPrice != null ? (a.originalPrice! - a.appPrice) : 0;
            final discB = b.originalPrice != null ? (b.originalPrice! - b.appPrice) : 0;
            return discB.compareTo(discA);
          });
          break;
        case 'rank':
          _items.sort((a, b) => (a.trendingRank ?? 999).compareTo(b.trendingRank ?? 999));
          break;
        default:
          // 'popular' — default order
          break;
      }
    });
  }

  Future<VendorModel?> _getVendor(String vendorId) async {
    if (_vendorCache.containsKey(vendorId)) return _vendorCache[vendorId];
    try {
      final vendor = await _vendorService.getVendorById(vendorId);
      if (vendor != null) _vendorCache[vendorId] = vendor;
      return vendor;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onItemTap(MenuItemModel item) async {
    HapticFeedback.lightImpact();
    final vendor = await _getVendor(item.vendorId);
    if (!mounted || vendor == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemDetailScreen(item: item, vendor: vendor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSortBar(),
            Expanded(
              child: _loading
                  ? _buildShimmer()
                  : _items.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: _C.primary,
                          onRefresh: _loadItems,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.76,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final item = _items[i];
                              final isTrending = widget.fetchType == 'trending';
                              final isDeals = widget.fetchType == 'deals';

                              return ExploreItemCard(
                                item: item,
                                rank: isTrending ? (i + 1) : null,
                                badgeText: isTrending
                                    ? (item.orderCountBadge ??
                                        (i < 3 ? '${150 - (i + 1) * 20}+ orders' : '🔥 Trending'))
                                    : isDeals
                                        ? (item.dealTag ??
                                            (item.dealStockLeft != null
                                                ? '🔥 ${item.dealStockLeft} left'
                                                : null))
                                        : null,
                                onTap: () => _onItemTap(item),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _C.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(widget.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    '${widget.subtitle!} • ${_items.length} items',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _C.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (!_loading) ...[
                  Text(
                    '${_items.length} items found',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _C.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sort Bar ──────────────────────────────────────────────
  Widget _buildSortBar() {
    final List<Map<String, String>> sorts = widget.fetchType == 'trending'
        ? [
            {'key': 'rank', 'label': 'Rank'},
            {'key': 'price_low', 'label': 'Price: Low'},
            {'key': 'price_high', 'label': 'Price: High'},
          ]
        : widget.fetchType == 'deals'
            ? [
                {'key': 'popular', 'label': 'Popular'},
                {'key': 'discount_high', 'label': 'Discount: High'},
                {'key': 'price_low', 'label': 'Price: Low'},
                {'key': 'price_high', 'label': 'Price: High'},
              ]
            : [
                {'key': 'popular', 'label': 'Popular'},
                {'key': 'price_low', 'label': 'Price: Low'},
                {'key': 'price_high', 'label': 'Price: High'},
                {'key': 'discount_high', 'label': 'Discount: High'},
              ];

    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const Text(
              'Sort:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: _C.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            ...sorts.map((s) {
              final isSelected = _sortBy == s['key'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _sortBy = s['key']!);
                  _sortItems();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? _C.primary : _C.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _C.primary : _C.border,
                    ),
                  ),
                  child: Text(
                    s['label']!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _C.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Shimmer ───────────────────────────────────────────────
  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: const [
            BoxShadow(color: _C.shadow, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 16,
                      width: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
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

  // ── Empty State ───────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: _C.primaryBorder, width: 2),
            ),
            child: Center(
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${widget.title} not available right now',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'No items found at the moment.\nPlease check back later!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: _C.textMuted,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
