// lib/screens/restaurant_detail_screen.dart
// v7.0 — Price Range Filter Removed
// ✅ REMOVED: Price range filter (min/max slider, presets, _menuMaxPrice)
// ✅ KEPT: Diet filter (Veg/Non-Veg)
// ✅ KEPT: Tags filter (Bestseller, New, Spicy, Must Try)
// ✅ All v6.0 features preserved

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import 'menu_item_detail_screen.dart';

class _LC {
  static const background = Color(0xFFF7F5F2);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFEAE8E4);
  static const textPrimary = Color(0xFF1A1814);
  static const textSecondary = Color(0xFF6B6560);
  static const textMuted = Color(0xFF9E9893);
  static const accent = Color(0xFFFF6B2B);
  static const accentLight = Color(0xFFFFF1EB);
  static const accentBorder = Color(0xFFFFD4BC);
  static const green = Color(0xFF16A34A);
  static const greenLight = Color(0xFFDCFCE7);
  static const red = Color(0xFFDC2626);
  static const redLight = Color(0xFFFEE2E2);
  static const blue = Color(0xFF2563EB);
  static const blueLight = Color(0xFFEFF6FF);
  static const blueBorder = Color(0xFFBFDBFE);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF5F3FF);
}

// ── Filter State ─────────────────────────────────────────────
class _FilterState {
  bool vegOnly;
  bool nonVegOnly;
  Set<String> selectedTags;

  _FilterState({
    this.vegOnly = false,
    this.nonVegOnly = false,
    Set<String>? selectedTags,
  }) : selectedTags = selectedTags ?? {};

  bool get isActive => vegOnly || nonVegOnly || selectedTags.isNotEmpty;

  int get activeCount {
    int count = 0;
    if (vegOnly || nonVegOnly) count++;
    if (selectedTags.isNotEmpty) count += selectedTags.length;
    return count;
  }

  _FilterState copyWith({
    bool? vegOnly,
    bool? nonVegOnly,
    Set<String>? selectedTags,
  }) {
    return _FilterState(
      vegOnly: vegOnly ?? this.vegOnly,
      nonVegOnly: nonVegOnly ?? this.nonVegOnly,
      selectedTags: selectedTags ?? Set.from(this.selectedTags),
    );
  }

  _FilterState get reset => _FilterState();
}

class RestaurantDetailScreen extends StatefulWidget {
  final VendorModel vendor;
  final String? highlightItemId; // ✅ Yeh add karo

  const RestaurantDetailScreen({
    super.key,
    required this.vendor,
    this.highlightItemId, // ✅ Yeh add karo
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<MenuItemModel> _allItems = [];
  List<MenuItemModel> _filteredItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  late TabController _tabController;

  _FilterState _filter = _FilterState();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadMenu();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('menu_items')
          .select()
          .eq('vendor_id', widget.vendor.id)
          .eq('is_available', true)
          .order('category');

      final rawList = response as List;
      debugPrint('COUNT: ${rawList.length}');
      debugPrint('FIRST: ${rawList.isNotEmpty ? rawList[0] : "EMPTY"}');

      final items = rawList
          .map((e) => MenuItemModel.fromMap(e as Map<String, dynamic>))
          .toList();

      final Set<String> cats = {};
      for (final item in items) {
        if (item.category.isNotEmpty) cats.add(item.category);
      }
      final categories = ['All', ...cats.toList()..sort()];

      _tabController.removeListener(() {});
      _tabController = TabController(length: categories.length, vsync: this);
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          _onCategorySelected(categories[_tabController.index]);
        }
      });

      if (!mounted) return;
      setState(() {
        _allItems = items;
        _categories = categories;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e, stack) {
      debugPrint('MENU ERROR: $e');
      debugPrint('STACK: $stack');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      var items = _selectedCategory == 'All'
          ? _allItems
          : _allItems.where((i) => i.category == _selectedCategory).toList();

      if (_filter.vegOnly) {
        items = items.where((i) => i.isVeg).toList();
      } else if (_filter.nonVegOnly) {
        items = items.where((i) => !i.isVeg).toList();
      }

      if (_filter.selectedTags.isNotEmpty) {
        items = items.where((i) {
          if (i.tag == null) return false;
          return _filter.selectedTags.any(
            (t) => t.toLowerCase() == i.tag!.toLowerCase(),
          );
        }).toList();
      }

      _filteredItems = items;
    });
  }

  void _showFilterSheet() {
    _FilterState pending = _filter.copyWith();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Container(
              decoration: const BoxDecoration(
                color: _LC.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _LC.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        const Text(
                          'Filter Menu',
                          style: TextStyle(
                            color: _LC.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setSheet(() => pending = _FilterState()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _LC.redLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _LC.red.withOpacity(0.25),
                              ),
                            ),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                color: _LC.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ── SECTION 1: Diet ─────────────────────
                    _sectionLabel('DIET'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _filterChip(
                          label: 'All Items',
                          icon: '🍽️',
                          selected: !pending.vegOnly && !pending.nonVegOnly,
                          onTap: () => setSheet(() {
                            pending.vegOnly = false;
                            pending.nonVegOnly = false;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'Veg Only',
                          icon: '🥗',
                          selected: pending.vegOnly,
                          selectedColor: _LC.green,
                          onTap: () => setSheet(() {
                            pending.vegOnly = true;
                            pending.nonVegOnly = false;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'Non-Veg',
                          icon: '🍗',
                          selected: pending.nonVegOnly,
                          selectedColor: _LC.red,
                          onTap: () => setSheet(() {
                            pending.nonVegOnly = true;
                            pending.vegOnly = false;
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: _LC.border),
                    const SizedBox(height: 20),

                    // ── SECTION 2: Tags ──────────────────────
                    _sectionLabel('TYPE'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tagChip(
                          label: '🔥 Bestseller',
                          tag: 'bestseller',
                          pending: pending,
                          setSheet: setSheet,
                        ),
                        _tagChip(
                          label: '✨ New',
                          tag: 'new',
                          pending: pending,
                          setSheet: setSheet,
                        ),
                        _tagChip(
                          label: '🌶️ Spicy',
                          tag: 'spicy',
                          pending: pending,
                          setSheet: setSheet,
                        ),
                        _tagChip(
                          label: '⭐ Must Try',
                          tag: 'must try',
                          pending: pending,
                          setSheet: setSheet,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: () {
                        setState(() => _filter = pending.copyWith());
                        _applyFilters();
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _LC.accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            pending.isActive
                                ? 'Apply Filters (${pending.activeCount})'
                                : 'Apply Filters',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip({
    required String label,
    required String icon,
    required bool selected,
    required VoidCallback onTap,
    Color selectedColor = _LC.accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withOpacity(0.1) : _LC.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : _LC.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedColor : _LC.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_circle_rounded, color: selectedColor, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tagChip({
    required String label,
    required String tag,
    required _FilterState pending,
    required StateSetter setSheet,
  }) {
    final selected = pending.selectedTags.contains(tag);
    const color = _LC.purple;
    return GestureDetector(
      onTap: () => setSheet(() {
        if (selected) {
          pending.selectedTags.remove(tag);
        } else {
          pending.selectedTags.add(tag);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : _LC.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : _LC.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : _LC.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _LC.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        fontFamily: 'Poppins',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final vendor = widget.vendor;

    return Scaffold(
      backgroundColor: _LC.background,
      body: Column(
        children: [
          _buildHeader(context, vendor),
          Expanded(
            child: Column(
              children: [
                _buildInfoRow(vendor),
                if (vendor.priceForTwo != null &&
                    vendor.otherPlatformAvg != null)
                  _buildPriceComparisonBar(vendor),
                _buildMenuControls(),
                Container(height: 1, color: _LC.border),
                if (_filter.isActive) _buildActiveFilterStrip(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _LC.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : _filteredItems.isEmpty
                      ? _buildEmptyMenuState()
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            cart.isEmpty ? 32 : 100,
                          ),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _RestaurantMenuItemCard(
                            item: _filteredItems[i],
                            vendor: vendor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuItemDetailScreen(
                                  item: _filteredItems[i],
                                  vendor: vendor,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty ? null : _buildCartBar(cart, context),
    );
  }

  Widget _buildActiveFilterStrip() {
    final chips = <Widget>[];

    if (_filter.vegOnly) {
      chips.add(
        _activeChip('🥗 Veg Only', _LC.green, () {
          setState(() => _filter = _filter.copyWith(vegOnly: false));
          _applyFilters();
        }),
      );
    }
    if (_filter.nonVegOnly) {
      chips.add(
        _activeChip('🍗 Non-Veg', _LC.red, () {
          setState(() => _filter = _filter.copyWith(nonVegOnly: false));
          _applyFilters();
        }),
      );
    }
    for (final tag in _filter.selectedTags) {
      chips.add(
        _activeChip(tag, _LC.purple, () {
          setState(() => _filter.selectedTags.remove(tag));
          _applyFilters();
        }),
      );
    }

    return Container(
      color: _LC.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _filter = _FilterState());
              _applyFilters();
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: _LC.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeChip(String label, Color color, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VendorModel vendor) {
    final topPadding = MediaQuery.of(context).padding.top;
    final hasImage = vendor.imageUrl != null && vendor.imageUrl!.isNotEmpty;

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: topPadding + 190,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: vendor.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFFF0EDE8)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFFF0EDE8)),
                )
              : Container(
                  color: const Color(0xFFF0EDE8),
                  child: const Center(
                    child: Text('🍽️', style: TextStyle(fontSize: 70)),
                  ),
                ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 130,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xEE000000)],
              ),
            ),
          ),
        ),
        Positioned(
          top: topPadding + 10,
          left: 14,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vendor.vendorBadge != null &&
                  vendor.vendorBadge!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vendor.vendorBadge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                vendor.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  if (vendor.cuisineType != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        vendor.cuisineType!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: vendor.isActive
                          ? _LC.green.withOpacity(0.85)
                          : _LC.red.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vendor.isActive ? 'Open' : 'Closed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(VendorModel vendor) {
    return Container(
      color: _LC.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _infoChip(
            icon: Icons.location_on_outlined,
            label: vendor.area,
            color: _LC.accent,
          ),
          const SizedBox(width: 8),
          if (vendor.distanceKm != null) ...[
            _infoChip(
              icon: Icons.directions_bike_outlined,
              label: '${vendor.distanceKm!.toStringAsFixed(1)} km',
              color: _LC.blue,
            ),
            const SizedBox(width: 8),
          ],
          if (vendor.deliveryMinutes != null) ...[
            _infoChip(
              icon: Icons.access_time_rounded,
              label: '${vendor.deliveryMinutes} min',
              color: _LC.green,
            ),
            const SizedBox(width: 8),
          ],
          if (vendor.rating != null)
            _infoChip(
              icon: Icons.star_rounded,
              label: '${vendor.rating}',
              color: const Color(0xFFD97706),
            ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceComparisonBar(VendorModel vendor) {
    final savings = vendor.savingsPercent;
    final savingsAmt =
        (vendor.otherPlatformAvg ?? 0) - (vendor.priceForTwo ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _LC.blueLight,
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _LC.blue,
                    ),
                    children: [
                      const TextSpan(text: 'On our platform: '),
                      TextSpan(
                        text: '₹${vendor.priceForTwo}/person',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _LC.textMuted,
                    ),
                    children: [
                      const TextSpan(text: 'On other platforms: '),
                      TextSpan(
                        text: '₹${vendor.otherPlatformAvg}/person',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (savings > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _LC.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '$savings% Cheaper',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    'Save ₹$savingsAmt',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuControls() {
    final filterActive = _filter.isActive;
    final filterCount = _filter.activeCount;

    return Container(
      color: _LC.surface,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                margin: const EdgeInsets.only(left: 12, right: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: filterActive ? _LC.accent : _LC.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: filterActive ? _LC.accent : _LC.border,
                    width: filterActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: filterActive ? Colors.white : _LC.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color: filterActive ? Colors.white : _LC.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (filterActive) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$filterCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() => _filter = _FilterState());
                          _applyFilters();
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: _LC.border,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            Expanded(
              child: _categories.length > 1
                  ? TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: _LC.accent,
                      unselectedLabelColor: _LC.textMuted,
                      labelStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                      ),
                      indicatorColor: _LC.accent,
                      indicatorWeight: 2,
                      tabAlignment: TabAlignment.start,
                      tabs: _categories.map((c) => Tab(text: c)).toList(),
                    )
                  : const SizedBox(),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${_filteredItems.length} items',
                style: const TextStyle(
                  color: _LC.textMuted,
                  fontSize: 11,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMenuState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _filter.vegOnly
                  ? '🥗'
                  : _filter.nonVegOnly
                  ? '🍗'
                  : '🍽️',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              _filter.isActive
                  ? 'No items match your filters'
                  : 'No items in this category yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _LC.textMuted,
                fontSize: 13,
                fontFamily: 'Poppins',
                height: 1.5,
              ),
            ),
            if (_filter.isActive) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() => _filter = _FilterState());
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _LC.accentLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _LC.accentBorder),
                  ),
                  child: const Text(
                    'Clear all filters',
                    style: TextStyle(
                      color: _LC.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartBar(CartProvider cart, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      color: _LC.surface,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _LC.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'View Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
              const Spacer(),
              Text(
                '₹${cart.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Restaurant Menu Item Card — v7.1 IMAGE FIX
// ✅ FIX: Image AspectRatio(1:1) + BoxFit.contain — poori image dikhti hai
// Sirf yeh class restaurant_detail_screen.dart mein replace karo
// Baaki sab same rakhna
// ══════════════════════════════════════════════════════════════════
class _RestaurantMenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VendorModel vendor;
  final VoidCallback onTap;

  const _RestaurantMenuItemCard({
    required this.item,
    required this.vendor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getQuantity(item.id);
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _LC.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ IMAGE — 1:1 aspect ratio, BoxFit.contain
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 82,
                height: 82,
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _imagePlaceholder(),
                        errorWidget: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: item.isVeg ? _LC.green : _LC.red,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Center(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: item.isVeg ? _LC.green : _LC.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _LC.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: _LC.textMuted,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.isDiscounted && item.originalPrice != null)
                        Row(
                          children: [
                            Text(
                              '₹${item.appPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: _LC.red,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '₹${item.originalPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: _LC.textMuted,
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '₹${item.appPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: _LC.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      const Spacer(),
                      if (item.stockStatus == 'sold_out')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _LC.redLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _LC.red.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Sold Out',
                            style: TextStyle(
                              color: _LC.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        )
                      else if (qty == 0)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.read<CartProvider>().addItem(item, vendor);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _LC.accent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text(
                              'ADD',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.read<CartProvider>().removeItem(
                                  item.id,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _LC.accentLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _LC.accentBorder),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: _LC.accent,
                                  size: 15,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _LC.accent,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.read<CartProvider>().addItem(
                                  item,
                                  vendor,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _LC.accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ),
                          ],
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
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: Color(0xFFD0C9C0),
          size: 30,
        ),
      ),
    );
  }
}
