import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import '../providers/veg_filter_provider.dart';
import '../utils/cart_utils.dart';
import '../screens/menu_item_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _supabase = Supabase.instance.client;
  
  Timer? _debounce;
  String _query = '';
  bool _isLoading = false;
  
  List<MenuItemModel> _searchResults = [];
  Map<String, VendorModel> _vendorMap = {};

  final List<String> _recentSearches = [];
  final List<String> _popularSearches = [
    'Momos', 'Burger', 'Chowmein', 'Pizza', 'Maggi', 'Chaat', 'Shake', 'Sandwich', 'Barfi', 'Halwa', 'Cake'
  ];
  final Map<String, String> _categoryEmojis = {
    'Momos': '🥟', 'Burger': '🍔', 'Chowmein': '🍜', 'Pizza': '🍕',
    'Chaat': '🍛', 'Maggi': '🍝', 'Sandwich': '🥪', 'Shake': '🥤',
    'Barfi': '🍬', 'Halwa': '🍮', 'Cake': '🎂', 'Other': '🍽️',
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
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    setState(() {
      _query = query.trim();
    });
    
    if (_query.isEmpty) {
      setState(() {
        _searchResults = [];
        _vendorMap = {};
        _isLoading = false;
      });
      return;
    }
    
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(_query);
    });
  }
  
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
      _vendorMap = {};
    });
    
    try {
      // 1. Search menu_items using .ilike
      final itemsData = await _supabase
          .from('menu_items')
          .select()
          .ilike('name', '%$query%')
          .eq('is_available', true);
          
      final items = (itemsData as List)
          .map((item) => MenuItemModel.fromMap(item as Map<String, dynamic>))
          .toList();
          
      if (items.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _searchResults = [];
          });
        }
        return;
      }
      
      // 2. Fetch unique vendors
      final vendorIds = items.map((i) => i.vendorId).toSet().toList();
      
      final vendorsData = await _supabase
          .from('vendors')
          .select()
          .inFilter('id', vendorIds)
          .eq('is_active', true);
          
      final vendorMap = <String, VendorModel>{};
      for (final v in vendorsData) {
        final vendor = VendorModel.fromMap(v as Map<String, dynamic>);
        vendorMap[vendor.id] = vendor;
      }
      
      // Filter out items whose vendors are not active
      final validItems = items.where((i) => vendorMap.containsKey(i.vendorId)).toList();
      
      if (mounted) {
        setState(() {
          _searchResults = validItems;
          _vendorMap = vendorMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _onSearchChanged(suggestion);
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
      _searchResults = [];
      _vendorMap = {};
    });
    _focusNode.requestFocus();
  }

  Future<void> _onItemTap(MenuItemModel item) async {
    final vendor = _vendorMap[item.vendorId];
    if (vendor == null) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemDetailScreen(item: item, vendor: vendor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVegOnly = context.watch<VegFilterProvider>().isVegOnly;
    
    List<MenuItemModel> displayItems = _searchResults;
    if (isVegOnly) {
      displayItems = displayItems.where((item) => item.isVeg).toList();
    }

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
                  : _buildResultsView(displayItems, isVegOnly),
            ),
          ],
        ),
      ),
    );
  }

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
                onChanged: _onSearchChanged,
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
            const Icon(Icons.history_rounded, color: AppColors.textMuted, size: 16),
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
              child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(List<MenuItemModel> displayItems, bool isVegOnly) {
    if (_isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFFFF8F0),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (displayItems.isEmpty) {
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
                  color: const Color(0xFFFFF1EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Center(
                  child: Text('🔍', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No items found for your search',
                style: AppStyles.sectionHeader,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isVegOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
              ),
              child: const Text(
                'Showing veg items only',
                style: TextStyle(
                  color: Color(0xFF16A34A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, isVegOnly ? 8 : 12, 16, 32),
            itemCount: displayItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final item = displayItems[i];
              final vendor = _vendorMap[item.vendorId];
              if (vendor == null) return const SizedBox.shrink();

              return _buildItemCard(item, vendor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(MenuItemModel item, VendorModel vendor) {
    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.fastfood, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          // Middle: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  vendor.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.appPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        CartUtils.handleCartAddItem(context, item, vendor);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'ADD',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
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
  }
}
