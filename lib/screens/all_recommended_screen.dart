// lib/screens/all_recommended_screen.dart
// Full-screen 2-column grid showing all recommended items

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../services/menu_service.dart';
import '../services/vendor_service.dart';
import '../services/location_service.dart';
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
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

class AllRecommendedScreen extends StatefulWidget {
  /// Optionally pass pre-loaded items to avoid a second fetch
  final List<MenuItemModel>? preloadedItems;

  const AllRecommendedScreen({super.key, this.preloadedItems});

  @override
  State<AllRecommendedScreen> createState() => _AllRecommendedScreenState();
}

class _AllRecommendedScreenState extends State<AllRecommendedScreen> {
  final _vendorService = VendorService();
  final _locationService = LocationService();

  List<MenuItemModel> _items = [];
  bool _loading = true;

  final Map<String, VendorModel> _vendorCache = {};

  @override
  void initState() {
    super.initState();
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
      final items = await MenuService().getRecommendedItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
                          childAspectRatio: 0.62,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => ExploreItemCard(
                          item: _items[i],
                          onTap: () => _onItemTap(_items[i]),
                        ),
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
          const Text('✨', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommended For You',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                ),
                if (!_loading)
                  Text(
                    '${_items.length} items',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _C.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
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
            child: const Center(
              child: Text(
                '✨',
                style: TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No recommendations right now',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for\nhand-picked items just for you!',
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
