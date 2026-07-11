// lib/screens/vendor_detail_screen.dart
// v3.1 — Price filter removed
// ✅ _FilterState: only vegOnly, nonVegOnly, selectedTags
// ✅ No price range slider, no price presets
// ✅ All other v3.0 features preserved

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import '../providers/cart_provider.dart';
import '../services/menu_service.dart';
import '../widgets/menu_item_card.dart';
import 'cart_screen.dart';

// ─── Filter State ─────────────────────────────────────────────
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

class VendorDetailScreen extends StatefulWidget {
  final VendorModel vendor;
  final String? highlightItemId;

  const VendorDetailScreen({
    super.key,
    required this.vendor,
    this.highlightItemId,
  });

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  final _menuService = MenuService();
  final _supabase = Supabase.instance.client;

  List<MenuItemModel> _allItems = [];
  List<MenuItemModel> _filteredItems = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  bool _isLoading = true;

  // ── Filter state ──────────────────────────────────────────
  _FilterState _filter = _FilterState();

  // ── Search highlight ──────────────────────────────────────
  final Map<String, GlobalKey> _itemKeys = {};
  bool _hasScrolledToItem = false;
  bool _isFlashing = false;

  List<String> _offers = [];

  static const double _stickyH = 52.0;

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _loadOffers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.vendor.distanceKm != null && widget.vendor.distanceKm! > 0) {
        context.read<CartProvider>().setDeliveryChargeForDistance(
          widget.vendor.distanceKm!,
        );
      }
      if (widget.highlightItemId != null) {
        _scrollToHighlightedItem();
      }
    });
  }

  GlobalKey _getItemKey(String itemId) {
    return _itemKeys.putIfAbsent(itemId, () => GlobalKey());
  }

  Future<void> _scrollToHighlightedItem() async {
    if (_hasScrolledToItem) return;
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final key = _itemKeys[widget.highlightItemId];
      if (key?.currentContext != null) {
        _hasScrolledToItem = true;
        await Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
        for (int j = 0; j < 3; j++) {
          if (!mounted) return;
          setState(() => _isFlashing = true);
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          setState(() => _isFlashing = false);
          await Future.delayed(const Duration(milliseconds: 250));
        }
        break;
      }
    }
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    // Shift check — agar vendor current shift mein available nahi hai to menu mat dikhao
    if (!widget.vendor.isOpenNow) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final items = await _menuService.getMenuItems(widget.vendor.id);
      final cats = _menuService.getCategories(items);
      setState(() {
        _allItems = items;
        _categories = cats;
        _filter = _FilterState();
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to load menu, please retry.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadOffers() async {
    try {
      final data = await _supabase
          .from('vendor_offers')
          .select('offer_text')
          .eq('vendor_id', widget.vendor.id)
          .eq('is_active', true)
          .order('sort_order');

      final offers = (data as List)
          .map((e) => e['offer_text'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      if (mounted) setState(() => _offers = offers);
    } catch (_) {
      if (mounted) setState(() => _offers = []);
    }
  }

  // ── Apply all filters ─────────────────────────────────────
  void _applyFilters() {
    setState(() {
      var items = _selectedCategory == 'All'
          ? _allItems
          : _allItems
                .where((item) => item.category == _selectedCategory)
                .toList();

      // Diet filter
      if (_filter.vegOnly) {
        items = items.where((i) => i.isVeg).toList();
      } else if (_filter.nonVegOnly) {
        items = items.where((i) => !i.isVeg).toList();
      }

      // Tag filter
      if (_filter.selectedTags.isNotEmpty) {
        items = items.where((i) {
          if (i.tag == null) return false;
          return _filter.selectedTags.any(
            (t) => t.toLowerCase() == i.tag!.toLowerCase(),
          );
        }).toList();
      }

      // NEW:
      _filteredItems = items;
    });
  }

  // ── Grouped display list (category headers, All tab only) ──
  List<dynamic> _buildDisplayItems() {
    final showCategoryHeaders = _selectedCategory == 'All' && !_filter.isActive;
    if (!showCategoryHeaders) return _filteredItems;

    final List<dynamic> result = [];
    for (final cat in _categories) {
      if (cat == 'All') continue;
      final itemsInCat = _filteredItems
          .where((i) => i.category == cat)
          .toList();
      if (itemsInCat.isEmpty) continue;
      result.add(cat);
      result.addAll(itemsInCat);
    }
    return result;
  }

  Widget _buildCategoryHeader(String category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  void _onCategorySelected(String cat) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = cat);
    _applyFilters();
  }

  void _toggleVeg() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_filter.vegOnly) {
        _filter = _filter.copyWith(vegOnly: false);
      } else {
        _filter = _filter.copyWith(vegOnly: true, nonVegOnly: false);
      }
    });
    _applyFilters();
  }

  // ── Filter Bottom Sheet ───────────────────────────────────
  void _showFilterSheet() {
    HapticFeedback.lightImpact();
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
                color: AppColors.surface,
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
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header
                    Row(
                      children: [
                        const Text(
                          'Filter Menu',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const Spacer(),
                        if (pending.isActive)
                          GestureDetector(
                            onTap: () =>
                                setSheet(() => pending = _FilterState()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withOpacity(0.25),
                                ),
                              ),
                              child: const Text(
                                'Clear All',
                                style: TextStyle(
                                  color: AppColors.error,
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

                    // ── SECTION 1: Diet ───────────────────────
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
                          selectedColor: AppColors.success,
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
                          selectedColor: AppColors.error,
                          onTap: () => setSheet(() {
                            pending.nonVegOnly = true;
                            pending.vegOnly = false;
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 20),

                    // ── SECTION 2: Tags ───────────────────────
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

                    // Apply button
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
                          color: AppColors.primary,
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

  // ── Filter chip helpers ───────────────────────────────────
  Widget _filterChip({
    required String label,
    required String icon,
    required bool selected,
    required VoidCallback onTap,
    Color selectedColor = AppColors.primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : AppColors.border,
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
                color: selected ? selectedColor : AppColors.textSecondary,
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
    const color = Color(0xFF7C3AED);
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
          color: selected ? color.withOpacity(0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
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
        color: AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        fontFamily: 'Poppins',
      ),
    );
  }

  // ── Active filter strip ───────────────────────────────────
  Widget _buildActiveFilterStrip() {
    final chips = <Widget>[];

    if (_filter.vegOnly) {
      chips.add(
        _activeChip('🥗 Veg Only', AppColors.success, () {
          setState(() => _filter = _filter.copyWith(vegOnly: false));
          _applyFilters();
        }),
      );
    }
    if (_filter.nonVegOnly) {
      chips.add(
        _activeChip('🍗 Non-Veg', AppColors.error, () {
          setState(() => _filter = _filter.copyWith(nonVegOnly: false));
          _applyFilters();
        }),
      );
    }
    for (final tag in _filter.selectedTags) {
      chips.add(
        _activeChip(tag, const Color(0xFF7C3AED), () {
          setState(() => _filter.selectedTags.remove(tag));
          _applyFilters();
        }),
      );
    }

    return Container(
      color: AppColors.surface,
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
                  color: AppColors.error,
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final vendor = widget.vendor;
    final displayItems = _buildDisplayItems();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 52,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 15,
            ),
          ),
        ),
        title: Text(
          vendor.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () => _showMoreOptions(context),
          ),
          const SizedBox(width: 4),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildShopImage(vendor)),
                SliverToBoxAdapter(child: _buildVendorInfo(vendor)),

                if (_offers.isNotEmpty)
                  SliverToBoxAdapter(child: _buildOffersStrip()),

                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterDelegate(
                    minH: _stickyH,
                    maxH: _stickyH,
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    isVegOnly: _filter.vegOnly,
                    filterActive: _filter.isActive,
                    filterCount: _filter.activeCount,
                    onCategoryTap: _onCategorySelected,
                    onVegToggle: _toggleVeg,
                    onFilterTap: _showFilterSheet,
                    onFilterClear: () {
                      setState(() => _filter = _FilterState());
                      _applyFilters();
                    },
                  ),
                ),

                if (_filter.isActive)
                  SliverToBoxAdapter(child: _buildActiveFilterStrip()),

                if (_filter.vegOnly)
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.success.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco_rounded,
                            color: AppColors.success,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Veg only mode — showing vegetarian items only',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleVeg,
                            child: const Text(
                              'Show All',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!_isLoading && _filteredItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(
                        children: [
                          Text(
                            '${_filteredItems.length} item${_filteredItems.length > 1 ? 's' : ''} available',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const Spacer(),
                          _buildStockSummary(),
                        ],
                      ),
                    ),
                  ),

                // NEW:
                _isLoading
                    ? SliverToBoxAdapter(child: _buildShimmer())
                    : _filteredItems.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((_, i) {
                          final displayItem = displayItems[i];

                          if (displayItem is String) {
                            return _buildCategoryHeader(displayItem);
                          }

                          final item = displayItem as MenuItemModel;
                          final isHighlighted =
                              item.id == widget.highlightItemId;
                          final key = _getItemKey(item.id);

                          return AnimatedContainer(
                            key: key,
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isHighlighted && _isFlashing
                                  ? AppColors.primary.withOpacity(0.08)
                                  : Colors.transparent,
                              border: isHighlighted
                                  ? Border(
                                      left: BorderSide(
                                        color: _isFlashing
                                            ? AppColors.primary
                                            : AppColors.primary.withOpacity(
                                                0.4,
                                              ),
                                        width: 3,
                                      ),
                                    )
                                  : const Border(),
                            ),
                            child: MenuItemCard(item: item, vendor: vendor),
                          );
                        }, childCount: displayItems.length),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),

            if (!cart.isEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildCartBar(cart, context),
              ),
          ],
        ),
      ),
    );
  }

  // ── Shop Image ────────────────────────────────────────────
  Widget _buildShopImage(VendorModel vendor) {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        children: [
          Positioned.fill(
            child: vendor.imageUrl != null && vendor.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: vendor.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.background,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _buildImagePlaceholder(),
                  )
                : _buildImagePlaceholder(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 70,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: vendor.isOpenNow
                    ? AppColors.success.withOpacity(0.92)
                    : AppColors.error.withOpacity(0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    vendor.isOpenNow ? 'Open' : 'Closed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
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

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_rounded,
            color: AppColors.primary.withOpacity(0.35),
            size: 52,
          ),
          const SizedBox(height: 8),
          Text(
            widget.vendor.name,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  // ── Vendor Info ───────────────────────────────────────────
  Widget _buildVendorInfo(VendorModel vendor) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    fontFamily: 'Poppins',
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildCategoryPills(vendor.category),
                    if (vendor.vendorBadge != null &&
                        vendor.vendorBadge!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.warning.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          vendor.vendorBadge!,
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 0,
                  children: [
                    if (vendor.distanceKm != null) ...[
                      _infoChip(
                        Icons.directions_bike_outlined,
                        '${vendor.distanceKm!.toStringAsFixed(1)} km',
                      ),
                      _dot(),
                    ],
                    _infoChip(Icons.location_on_outlined, vendor.area),
                    if (vendor.deliveryMinutes != null) ...[
                      _dot(),
                      _infoChip(
                        Icons.access_time_rounded,
                        '${vendor.deliveryMinutes} mins',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (vendor.rating != null) _RatingBox(rating: vendor.rating!),
        ],
      ),
    );
  }

  Widget _buildCategoryPills(String categoryString) {
    final cats = categoryString
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (cats.isEmpty) return const SizedBox.shrink();

    const maxShow = 3;
    final shown = cats.take(maxShow).join(', ');
    final remaining = cats.length - maxShow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Text(
              shown,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                fontFamily: 'Poppins',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (remaining > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$remaining more',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 10,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ── Offers Strip ──────────────────────────────────────────
  Widget _buildOffersStrip() {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const BouncingScrollPhysics(),
              itemCount: _offers.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.18),
                  ),
                ),
                child: Center(
                  child: Text(
                    _offers[i],
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  // ── Cart Bar ──────────────────────────────────────────────
  Widget _buildCartBar(CartProvider cart, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const Text(
                'View Cart →',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                '₹${cart.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stock Summary ─────────────────────────────────────────
  Widget _buildStockSummary() {
    final soldOutCount = _allItems
        .where((i) => i.stockStatus == 'sold_out')
        .length;
    final lowStockCount = _allItems
        .where((i) => i.stockStatus == 'low_stock')
        .length;
    if (soldOutCount == 0 && lowStockCount == 0) return const SizedBox.shrink();
    return Row(
      children: [
        if (lowStockCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Text(
              '$lowStockCount low',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (soldOutCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.error.withOpacity(0.25)),
            ),
            child: Text(
              '$soldOutCount sold out',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
      ],
    );
  }

  // ── More Options ──────────────────────────────────────────
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.share_rounded,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Share Vendor',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.report_outlined,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Report Issue',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Shimmer ───────────────────────────────────────────────
  Widget _buildShimmer() {
    return Column(
      children: List.generate(
        5,
        (_) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(12, 100),
                    const SizedBox(height: 8),
                    _shimmerBox(14, 160),
                    const SizedBox(height: 8),
                    _shimmerBox(16, 60),
                    const SizedBox(height: 8),
                    _shimmerBox(11, 180),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 104,
                  height: 104,
                  color: AppColors.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerBox(double h, double w) => Container(
    height: h,
    width: w,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  // ── Empty State ───────────────────────────────────────────
  Widget _buildEmptyState() {
    final isFilterActive = _filter.isActive;
    final isShiftOff = !widget.vendor.isOpenNow;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isShiftOff
                    ? AppColors.warning.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isShiftOff
                      ? '🕐'
                      : _filter.vegOnly
                      ? '🥦'
                      : isFilterActive
                      ? '🔍'
                      : '🍽️',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isShiftOff
                  ? 'Vendor Not Available Right Now'
                  : isFilterActive
                  ? 'No items match your filters'
                  : _filter.vegOnly
                  ? 'No Veg Items Found'
                  : 'Menu Not Available',
              style: AppStyles.sectionHeader,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isShiftOff
                  ? widget.vendor.unavailableTimingMessage
                  : isFilterActive
                  ? 'Try adjusting or clearing your filters'
                  : _filter.vegOnly
                  ? 'This vendor has no vegetarian items'
                  : 'Please try again in a little while',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontFamily: 'Poppins',
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (isFilterActive) ...[
              const SizedBox(height: 16),
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
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Clear All Filters',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
}

// ─── Rating Box ───────────────────────────────────────────
class _RatingBox extends StatelessWidget {
  final double rating;
  const _RatingBox({required this.rating});

  Color get _color {
    if (rating >= 4.0) return AppColors.success;
    if (rating >= 3.0) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 3),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const Text(
            'Rating',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Delegate ──────────────────────────────────────
class _FilterDelegate extends SliverPersistentHeaderDelegate {
  final double minH, maxH;
  final List<String> categories;
  final String selectedCategory;
  final bool isVegOnly;
  final bool filterActive;
  final int filterCount;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onVegToggle;
  final VoidCallback onFilterTap;
  final VoidCallback onFilterClear;

  const _FilterDelegate({
    required this.minH,
    required this.maxH,
    required this.categories,
    required this.selectedCategory,
    required this.isVegOnly,
    required this.filterActive,
    required this.filterCount,
    required this.onCategoryTap,
    required this.onVegToggle,
    required this.onFilterTap,
    required this.onFilterClear,
  });

  @override
  double get minExtent => minH;
  @override
  double get maxExtent => maxH;

  @override
  bool shouldRebuild(_FilterDelegate old) =>
      old.selectedCategory != selectedCategory ||
      old.isVegOnly != isVegOnly ||
      old.filterActive != filterActive ||
      old.filterCount != filterCount ||
      old.categories.length != categories.length;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overlapsContent)
            const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Filter button ─────────────────────────
                GestureDetector(
                  onTap: onFilterTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(left: 10, right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: filterActive
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: filterActive
                            ? AppColors.primary
                            : AppColors.border,
                        width: filterActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 14,
                          color: filterActive
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Filter',
                          style: TextStyle(
                            color: filterActive
                                ? Colors.white
                                : AppColors.textSecondary,
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
                            onTap: onFilterClear,
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
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),

                // ── Categories scroll ─────────────────────
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isSelected = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => onCategoryTap(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Veg toggle ────────────────────────────
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                GestureDetector(
                  onTap: onVegToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isVegOnly
                          ? AppColors.success
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isVegOnly ? AppColors.success : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isVegOnly
                                  ? Colors.white
                                  : AppColors.success,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isVegOnly
                                    ? Colors.white
                                    : AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Veg',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            color: isVegOnly ? Colors.white : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}
