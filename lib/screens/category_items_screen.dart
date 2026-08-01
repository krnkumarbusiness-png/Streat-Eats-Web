import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../services/vendor_service.dart';
import '../services/location_service.dart';
import 'menu_item_detail_screen.dart';
import '../widgets/explore_item_card.dart';

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
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);
  static const gold = Color(0xFFD97706);
  static const shadow = Color(0x14000000);
}

class CategoryItemsScreen extends StatefulWidget {
  final String category;
  final String catEmoji;

  const CategoryItemsScreen({
    super.key,
    required this.category,
    required this.catEmoji,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  final _supabase = Supabase.instance.client;
  final _vendorService = VendorService();
  final _locationService = LocationService();

  List<MenuItemModel> _items = [];
  bool _loading = true;
  String _sortBy = 'popular'; // 'popular' | 'price_low' | 'price_high'

  // Vendor cache — ek baar fetch, baar baar nahi
  final Map<String, VendorModel> _vendorCache = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('menu_items')
          .select(
            '*, vendors!inner(city, is_active, name, area, latitude, longitude)',
          )
          .eq('category', widget.category)
          .eq('is_available', true)
          .eq('vendors.city', 'Haldwani')
          .eq('vendors.is_active', true)
          .order('created_at', ascending: false);

      final items = (data as List)
          .map((e) => MenuItemModel.fromMap(e))
          .toList();

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
        default:
          // popular — default order (created_at desc)
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
          Text(widget.catEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                ),
                if (!_loading)
                  Text(
                    '${_items.length} items found',
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

  // ── Sort Bar ──────────────────────────────────────────────
  Widget _buildSortBar() {
    final sorts = [
      {'key': 'popular', 'label': 'Popular'},
      {'key': 'price_low', 'label': 'Price: Low'},
      {'key': 'price_high', 'label': 'Price: High'},
    ];

    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
                widget.catEmoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${widget.category} not available right now',
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
            'No vendors found for this category.\nPlease check back later!',
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
