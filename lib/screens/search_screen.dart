// lib/screens/search_screen.dart
// v3.2 — FIXED
// ✅ Sweet vendors bhi search mein aate hain — alag '🍬 Sweets' tag
// ✅ Filter chips: All, Vendors, Items (Vendors mein sweet + street + restaurant sab)
// ✅ Sweet vendors ke liye alag badge styling
// ✅ SearchScreen ab sweetVendors bhi accept karta hai

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import 'vendor_detail_screen.dart';
import 'menu_item_detail_screen.dart';

// ─────────────────────────────────────────
// Sealed class — type-safe search results
// ─────────────────────────────────────────
sealed class SearchResult {
  const SearchResult();
}

class VendorResult extends SearchResult {
  final VendorModel vendor;
  const VendorResult(this.vendor);
}

class ItemResult extends SearchResult {
  final MenuItemModel item;
  final VendorModel vendor;
  const ItemResult({required this.item, required this.vendor});
}

// ─────────────────────────────────────────
// SearchScreen
// ─────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  final List<VendorModel> vendors;
  final List<VendorModel> restaurants;

  // ✅ FIX: Sweet vendors ka naya parameter
  final List<VendorModel> sweetVendors;

  final Map<String, List<MenuItemModel>> vendorMenuItems;

  const SearchScreen({
    super.key,
    required this.vendors,
    this.restaurants = const [],
    this.sweetVendors = const [], // ✅ Default empty — backward compatible
    this.vendorMenuItems = const {},
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<SearchResult> _results = [];
  String _query = '';
  String _activeFilter = 'Items';

  // ✅ FIX: Teeno types ke vendors ek saath — street + restaurant + sweets
  List<VendorModel> get _allVendors => [
    ...widget.vendors,
    ...widget.restaurants,
    ...widget.sweetVendors, // ✅ Sweet vendors included
  ];

  List<ItemResult> get _allItemResults {
    final results = <ItemResult>[];
    for (final vendor in _allVendors) {
      final items = widget.vendorMenuItems[vendor.id] ?? [];
      for (final item in items) {
        results.add(ItemResult(item: item, vendor: vendor));
      }
    }
    return results;
  }

  final List<String> _recentSearches = [];

  final List<String> _popularSearches = [
    'Momos',
    'Burger',
    'Chowmein',
    'Pizza',
    'Maggi',
    'Chaat',
    'Shake',
    'Sandwich',
    'Barfi', // ✅ Sweet categories bhi
    'Halwa',
    'Cake',
  ];

  final Map<String, String> _categoryEmojis = {
    'Momos': '🥟',
    'Burger': '🍔',
    'Chowmein': '🍜',
    'Pizza': '🍕',
    'Chaat': '🍛',
    'Maggi': '🍝',
    'Sandwich': '🥪',
    'Shake': '🥤',
    'Samosa': '🥘',
    'Barfi': '🍬', // ✅
    'Halwa': '🍮', // ✅
    'Cake': '🎂', // ✅
    'Other': '🍽️',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // Core Search Logic
  // ─────────────────────────────────────────
  void _onSearch(String query) {
    setState(() {
      _query = query.trim();
      _activeFilter = 'Items';
      if (_query.isEmpty) {
        _results = [];
        return;
      }

      final q = _query.toLowerCase();
      final results = <SearchResult>[];

      // 1️⃣ Menu item search — PEHLE items
      for (final itemResult in _allItemResults) {
        final item = itemResult.item;
        if (item.name.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            (item.tag?.toLowerCase().contains(q) ?? false) ||
            (item.suggestedCategory?.toLowerCase().contains(q) ?? false)) {
          results.add(itemResult);
        }
      }

      // 2️⃣ Vendor search — BAAD MEIN
      for (final vendor in _allVendors) {
        if (vendor.name.toLowerCase().contains(q) ||
            vendor.category.toLowerCase().contains(q) ||
            vendor.area.toLowerCase().contains(q) ||
            (vendor.cuisineType?.toLowerCase().contains(q) ?? false) ||
            (vendor.chaupatiName?.toLowerCase().contains(q) ?? false) ||
            // ✅ Sweet vendors ke liye business_type bhi check karo
            // ✅ Sweet vendors ke liye bhi check karo
            vendor.businessType.toLowerCase().contains(q) ||
            (vendor.specialtyCategory?.toLowerCase().contains(q) ?? false)) {
          results.add(VendorResult(vendor));
        }
      }

      _results = results;
    });
  }

  List<SearchResult> get _filteredResults {
    switch (_activeFilter) {
      case 'Vendors':
        return _results.whereType<VendorResult>().toList();
      case 'Items':
        return _results.whereType<ItemResult>().toList();
      default:
        return _results;
    }
  }

  int get _vendorCount => _results.whereType<VendorResult>().length;
  int get _itemCount => _results.whereType<ItemResult>().length;

  void _onSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _onSearch(suggestion);
    if (!_recentSearches.contains(suggestion)) {
      setState(() => _recentSearches.insert(0, suggestion));
    }
  }

  void _onSubmit(String query) {
    final q = query.trim();
    if (q.isNotEmpty && !_recentSearches.contains(q)) {
      setState(() => _recentSearches.insert(0, q));
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _results = [];
      _activeFilter = 'Items';
    });
    _focusNode.requestFocus();
  }

  void _onVendorTap(VendorModel vendor) {
    if (!_recentSearches.contains(vendor.name)) {
      setState(() => _recentSearches.insert(0, vendor.name));
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor)),
    );
  }

  void _onItemTap(ItemResult itemResult) {
    if (!_recentSearches.contains(itemResult.item.name)) {
      setState(() => _recentSearches.insert(0, itemResult.item.name));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemDetailScreen(
          item: itemResult.item,
          vendor: itemResult.vendor,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchHeader(),
            Expanded(
              child: _query.isEmpty
                  ? _buildSuggestionsView()
                  : _buildResultsView(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Search Header
  // ─────────────────────────────────────────
  Widget _buildSearchHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.primary
                      : AppColors.border,
                  width: _focusNode.hasFocus ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearch,
                onSubmitted: _onSubmit,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                decoration: InputDecoration(
                  hintText: 'Momos, barfi, burger... sab dhundho',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Suggestions View
  // ─────────────────────────────────────────
  Widget _buildSuggestionsView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent', style: AppStyles.sectionHeader),
                GestureDetector(
                  onTap: () => setState(() => _recentSearches.clear()),
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...(_recentSearches.take(5).map((s) => _recentItem(s))),
            const SizedBox(height: 20),
          ],

          const Text('Popular Categories', style: AppStyles.sectionHeader),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: _popularSearches.length,
            itemBuilder: (_, i) {
              final cat = _popularSearches[i];
              return GestureDetector(
                onTap: () => _onSuggestionTap(cat),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _categoryEmojis[cat] ?? '🍽️',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text('All Vendors', style: AppStyles.sectionHeader),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_allVendors.length} total',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._allVendors.map((v) => _vendorListItem(VendorResult(v))),
        ],
      ),
    );
  }

  Widget _recentItem(String text) {
    return GestureDetector(
      onTap: () => _onSuggestionTap(text),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              color: AppColors.textMuted,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _recentSearches.remove(text)),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textMuted,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Results View
  // ─────────────────────────────────────────
  Widget _buildResultsView() {
    final filtered = _filteredResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_results.isNotEmpty)
          Container(
            height: 40,
            color: AppColors.surface,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _filterChip('All', _results.length),
                const SizedBox(width: 8),
                _filterChip('Vendors', _vendorCount),
                const SizedBox(width: 8),
                _filterChip('Items', _itemCount),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            '${filtered.length} result${filtered.length == 1 ? '' : 's'} for "$_query"',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final result = filtered[i];
                    return switch (result) {
                      VendorResult r => _vendorListItem(r),
                      ItemResult r => _itemListItem(r),
                    };
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, int count) {
    final isActive = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.25),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.primary,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: const Center(
                child: Text('🔍', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_query"',
              style: AppStyles.sectionHeader,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different keyword\nor browse by category',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _popularSearches.take(6).map((s) {
                return GestureDetector(
                  onTap: () => _onSuggestionTap(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      '${_categoryEmojis[s] ?? '🍽️'} $s',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ✅ Vendor Card — sweet vendors ka alag badge
  // ─────────────────────────────────────────
  Widget _vendorListItem(VendorResult result) {
    final vendor = result.vendor;
    final isOpen = vendor.isActive;
    final statusColor = isOpen ? AppColors.success : AppColors.error;

    // ✅ Vendor type determine karo — badge styling ke liye
    final isSweet = vendor.businessType == 'sweets';

    // Badge text + colors
    final String badgeText;
    final Color badgeBg;
    final Color badgeFg;

    if (isSweet) {
      badgeText = '🍬 Sweets';
      badgeBg = const Color(0xFFFFF1EB);
      badgeFg = const Color(0xFFFF6B2B);
    } else {
      badgeText = '🥟 Street Food';
      badgeBg = const Color(0xFFFFF1EB);
      badgeFg = AppColors.primary;
    }

    return GestureDetector(
      onTap: () => _onVendorTap(vendor),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Vendor image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: vendor.imageUrl != null
                  ? Image.network(
                      vendor.imageUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _vendorPlaceholder(vendor, isSweet),
                    )
                  : _vendorPlaceholder(vendor, isSweet),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vendor.name,
                          style: AppStyles.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vendor.vendorBadge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            vendor.vendorBadge!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Area + distance
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          vendor.area,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vendor.distanceKm != null) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${vendor.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Tags row
                  Row(
                    children: [
                      _smallTag(
                        vendor.category.split(',').first.trim(),
                        AppColors.primary.withOpacity(0.08),
                        AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      // ✅ Type badge — alag color sweet ke liye
                      _smallTag(badgeText, badgeBg, badgeFg),
                    ],
                  ),
                ],
              ),
            ),

            // Status + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? 'Open' : 'Band',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                if (vendor.deliveryMinutes != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${vendor.deliveryMinutes} min',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Sweet vendor ke liye alag placeholder emoji
  Widget _vendorPlaceholder(VendorModel vendor, bool isSweet) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isSweet
            ? const Color(0xFFFFF1EB) // Warm orange for sweets
            : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          isSweet
              ? '🍬'
              : _categoryEmojis[vendor.category.split(',').first.trim()] ??
                    '🥘',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Menu Item Card
  // ─────────────────────────────────────────
  Widget _itemListItem(ItemResult result) {
    final item = result.item;
    final vendor = result.vendor;

    final displayPrice = item.minPrice;
    final showFromLabel = item.hasHalfFull;

    return GestureDetector(
      onTap: () => _onItemTap(result),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Item image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _itemPlaceholder(item),
                    )
                  : _itemPlaceholder(item),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + veg/nonveg
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: item.isVeg
                                ? AppColors.success
                                : AppColors.error,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Center(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: item.isVeg
                                  ? AppColors.success
                                  : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppStyles.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Vendor name
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          vendor.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
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
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${showFromLabel ? 'From ' : ''}Rs.${displayPrice.toInt()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (item.isDiscounted && item.originalPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Rs.${item.originalPrice!.toInt()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.discountPercent}% OFF',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (item.tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.tag!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Availability
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: item.isAvailable
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.isAvailable ? 'Available' : 'Nahi hai',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: item.isAvailable
                          ? AppColors.success
                          : AppColors.error,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemPlaceholder(MenuItemModel item) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          _categoryEmojis[item.category] ?? '🍽️',
          style: const TextStyle(fontSize: 26),
        ),
      ),
    );
  }

  Widget _smallTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
