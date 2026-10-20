import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import '../providers/veg_filter_provider.dart';
import '../providers/cart_provider.dart';
import '../utils/cart_utils.dart';
import '../screens/menu_item_detail_screen.dart';
import '../screens/vendor_detail_screen.dart';
import '../widgets/explore_item_card.dart';
import '../widgets/global_floating_cart.dart';

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
}

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
  Timer? _placeholderTimer;
  String _query = '';
  bool _isLoading = false;

  // Selected tab: 'All', 'Dishes', 'Vendors'
  String _selectedTab = 'All';
  // Dish filter: 'All', 'Veg', 'Non-Veg', 'Under100'
  String _selectedFilter = 'All';
  // Vendor filter: 'All', 'Veg', 'TopRated', 'OpenNow'
  String _vendorFilter = 'All';

  List<MenuItemModel> _searchResults = [];
  List<VendorModel> _searchVendorResults = [];
  Map<String, VendorModel> _vendorMap = {};
  List<MenuItemModel> _recommendedItems = [];

  List<String> _recentSearches = [];
  static const String _prefRecentKey = 'streateats_recent_searches_v2';

  // Animated Rotating Placeholder Hints
  final List<String> _placeholderHints = [
    'Momos, barfi, burger... sab dhundho',
    'Search "Kurkure Momos" 🥟',
    'Search "Kaju Katli" 🍬',
    'Search "Double Cheese Burger" 🍔',
    'Search "Cold Coffee Shake" 🥤',
    'Search "Farmhouse Pizza" 🍕',
    'Search "Paneer Chowmein" 🍜',
    'Search "Crispy Chaat" 🍛',
    'Search "Gulab Jamun" 🍯',
  ];
  int _currentHintIndex = 0;

  // Trending Searches Chips with rank
  final List<Map<String, String>> _trendingSearches = [
    {'title': 'Kurkure Momos', 'emoji': '🥟'},
    {'title': 'Kaju Katli', 'emoji': '🍬'},
    {'title': 'Double Cheese Burger', 'emoji': '🍔'},
    {'title': 'Cold Coffee', 'emoji': '🥤'},
    {'title': 'Farmhouse Pizza', 'emoji': '🍕'},
    {'title': 'Paneer Chowmein', 'emoji': '🍜'},
    {'title': 'Crispy Chaat', 'emoji': '🍛'},
    {'title': 'Grilled Sandwich', 'emoji': '🥪'},
    {'title': 'Gulab Jamun', 'emoji': '🍯'},
  ];

  // Popular Categories
  List<Map<String, dynamic>> _popularCategories = [
    {'name': 'Momos', 'emoji': '🥟', 'image_url': null},
    {'name': 'Burger', 'emoji': '🍔', 'image_url': null},
    {'name': 'Chowmein', 'emoji': '🍜', 'image_url': null},
    {'name': 'Pizza', 'emoji': '🍕', 'image_url': null},
    {'name': 'Chaat', 'emoji': '🍛', 'image_url': null},
    {'name': 'Maggi', 'emoji': '🍝', 'image_url': null},
    {'name': 'Shake', 'emoji': '🥤', 'image_url': null},
    {'name': 'Sandwich', 'emoji': '🥪', 'image_url': null},
    {'name': 'Barfi', 'emoji': '🍬', 'image_url': null},
    {'name': 'Halwa', 'emoji': '🍮', 'image_url': null},
    {'name': 'Cake', 'emoji': '🎂', 'image_url': null},
    {'name': 'Rolls', 'emoji': '🌯', 'image_url': null},
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadCategoriesAndRecommended();
    _startPlaceholderRotation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startPlaceholderRotation() {
    _placeholderTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted && _query.isEmpty) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _placeholderHints.length;
        });
      }
    });
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefRecentKey) ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefRecentKey, _recentSearches);
    } catch (_) {}
  }

  Future<void> _loadCategoriesAndRecommended() async {
    try {
      // 1. Fetch dynamic categories from food_categories
      final catRows = await _supabase
          .from('food_categories')
          .select('name, image_url')
          .limit(16);

      if (catRows.isNotEmpty) {
        final List<Map<String, dynamic>> dynamicCats = [];
        for (final r in catRows) {
          final name = r['name'] as String? ?? '';
          if (name.isNotEmpty) {
            dynamicCats.add({
              'name': name,
              'image_url': r['image_url'] as String?,
              'emoji': _getEmojiForCategory(name),
            });
          }
        }
        if (dynamicCats.isNotEmpty && mounted) {
          setState(() {
            _popularCategories = dynamicCats;
          });
        }
      }

      // 2. Fetch popular recommended items
      final itemsData = await _supabase
          .from('menu_items')
          .select()
          .eq('is_available', true)
          .limit(8);

      final items = (itemsData as List)
          .map((i) => MenuItemModel.fromMap(i as Map<String, dynamic>))
          .toList();

      if (items.isNotEmpty && mounted) {
        final vendorIds = items.map((i) => i.vendorId).toSet().toList();
        final vendorsData = await _supabase
            .from('vendors')
            .select()
            .inFilter('id', vendorIds)
            .eq('is_active', true);

        for (final v in (vendorsData as List)) {
          final vendor = VendorModel.fromMap(v as Map<String, dynamic>);
          _vendorMap[vendor.id] = vendor;
        }

        setState(() {
          _recommendedItems = items.where((i) => _vendorMap.containsKey(i.vendorId)).toList();
        });
      }
    } catch (_) {}
  }

  String _getEmojiForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('momo')) return '🥟';
    if (lower.contains('burger')) return '🍔';
    if (lower.contains('chowmein') || lower.contains('noodle')) return '🍜';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('chaat')) return '🍛';
    if (lower.contains('maggi')) return '🍝';
    if (lower.contains('shake') || lower.contains('coffee') || lower.contains('beverage')) return '🥤';
    if (lower.contains('sandwich')) return '🥪';
    if (lower.contains('barfi') || lower.contains('sweet') || lower.contains('mithai')) return '🍬';
    if (lower.contains('halwa') || lower.contains('pudding')) return '🍮';
    if (lower.contains('cake') || lower.contains('pastry')) return '🎂';
    if (lower.contains('roll')) return '🌯';
    if (lower.contains('juice')) return '🍹';
    if (lower.contains('dosa') || lower.contains('idli') || lower.contains('south')) return '🥞';
    return '🍽️';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    _placeholderTimer?.cancel();
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
        _searchVendorResults = [];
        _isLoading = false;
        _selectedTab = 'All';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(_query);
    });
  }

  Future<void> _performSearch(String query) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _searchVendorResults = [];
    });

    try {
      final safeQ = cleanQ.replaceAll(RegExp(r'[,%()"]'), ' ').trim();

      // ── 1. Search Vendors from DB ─────────────────────────
      List<VendorModel> matchedVendors = [];
      try {
        final vData = await _supabase
            .from('vendors')
            .select()
            .eq('is_active', true)
            .or('name.ilike.%$safeQ%,category.ilike.%$safeQ%,cuisine_type.ilike.%$safeQ%,area.ilike.%$safeQ%');

        matchedVendors = (vData as List)
            .map((v) => VendorModel.fromMap(v as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Vendor complex search failed: $e, falling back to name ilike');
        try {
          final vDataFallback = await _supabase
              .from('vendors')
              .select()
              .eq('is_active', true)
              .ilike('name', '%$safeQ%');
          matchedVendors = (vDataFallback as List)
              .map((v) => VendorModel.fromMap(v as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }

      // ── 2. Search Menu Items from DB ───────────────────────
      List<MenuItemModel> matchedItems = [];
      try {
        final iData = await _supabase
            .from('menu_items')
            .select()
            .eq('is_available', true)
            .or('name.ilike.%$safeQ%,category.ilike.%$safeQ%');

        matchedItems = (iData as List)
            .map((item) => MenuItemModel.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Item search or failed: $e, falling back to name ilike');
        try {
          final iDataFallback = await _supabase
              .from('menu_items')
              .select()
              .eq('is_available', true)
              .ilike('name', '%$safeQ%');
          matchedItems = (iDataFallback as List)
              .map((item) => MenuItemModel.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }

      // ── 3. If matched vendors found, fetch top items from them ──
      // E.g. If user searched "Sharma Sweets", matchedItems might have 0 items matching "Sharma".
      // Fetch items from the matched vendor so dishes tab also has their offerings!
      if (matchedVendors.isNotEmpty) {
        final matchedVendorIds = matchedVendors.map((v) => v.id).toList();
        final existingItemIds = matchedItems.map((i) => i.id).toSet();

        try {
          final vendorItemsData = await _supabase
              .from('menu_items')
              .select()
              .inFilter('vendor_id', matchedVendorIds)
              .eq('is_available', true)
              .limit(16);

          final vendorItems = (vendorItemsData as List)
              .map((i) => MenuItemModel.fromMap(i as Map<String, dynamic>))
              .where((i) => !existingItemIds.contains(i.id))
              .toList();

          matchedItems.addAll(vendorItems);
        } catch (e) {
          debugPrint('Error fetching menu items for matched vendors: $e');
        }
      }

      // ── 4. Populate _vendorMap for all items & vendors ────
      final Map<String, VendorModel> vMap = {..._vendorMap};
      for (final v in matchedVendors) {
        vMap[v.id] = v;
      }

      final missingVendorIds = matchedItems
          .map((i) => i.vendorId)
          .where((id) => !vMap.containsKey(id))
          .toSet()
          .toList();

      if (missingVendorIds.isNotEmpty) {
        try {
          final vendorsData = await _supabase
              .from('vendors')
              .select()
              .inFilter('id', missingVendorIds)
              .eq('is_active', true);

          for (final v in (vendorsData as List)) {
            final vendor = VendorModel.fromMap(v as Map<String, dynamic>);
            vMap[vendor.id] = vendor;
          }
        } catch (e) {
          debugPrint('Error fetching missing item vendors: $e');
        }
      }

      final validItems = matchedItems.where((i) => vMap.containsKey(i.vendorId)).toList();

      // Combined vendors: direct matches first, then any vendors from matched items
      final Map<String, VendorModel> allSearchVendorsMap = {};
      for (final v in matchedVendors) {
        allSearchVendorsMap[v.id] = v;
      }
      for (final item in validItems) {
        final v = vMap[item.vendorId];
        if (v != null && !allSearchVendorsMap.containsKey(v.id)) {
          allSearchVendorsMap[v.id] = v;
        }
      }

      // Check if query changed while waiting
      if (!mounted || cleanQ != _query) return;

      setState(() {
        _searchResults = validItems;
        _searchVendorResults = allSearchVendorsMap.values.toList();
        _vendorMap = vMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSuggestionTap(String suggestion) {
    HapticFeedback.lightImpact();
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _onSearchChanged(suggestion);
    _addToRecentSearches(suggestion);
  }

  void _onSubmit(String query) {
    final q = query.trim();
    if (q.isNotEmpty) {
      _addToRecentSearches(q);
    }
  }

  void _addToRecentSearches(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _recentSearches.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.take(8).toList();
    }
    setState(() {});
    _saveRecentSearches();
  }

  void _removeRecentSearch(String text) {
    HapticFeedback.lightImpact();
    setState(() {
      _recentSearches.remove(text);
    });
    _saveRecentSearches();
  }

  void _clearAllRecentSearches() {
    HapticFeedback.mediumImpact();
    setState(() {
      _recentSearches.clear();
    });
    _saveRecentSearches();
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    setState(() {
      _query = '';
      _searchResults = [];
      _searchVendorResults = [];
      _selectedTab = 'All';
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
    if (isVegOnly || _selectedFilter == 'Veg') {
      displayItems = displayItems.where((item) => item.isVeg).toList();
    } else if (_selectedFilter == 'Non-Veg') {
      displayItems = displayItems.where((item) => !item.isVeg).toList();
    } else if (_selectedFilter == 'Under100') {
      displayItems = displayItems.where((item) => item.appPrice <= 100).toList();
    }

    List<VendorModel> displayVendors = _searchVendorResults;
    if (isVegOnly || _vendorFilter == 'Veg') {
      displayVendors = displayVendors.where((v) => v.vendorType == 'veg' || v.vendorType == 'both').toList();
    } else if (_vendorFilter == 'TopRated') {
      displayVendors = displayVendors.where((v) => (v.rating ?? 0) >= 4.0).toList();
    } else if (_vendorFilter == 'OpenNow') {
      displayVendors = displayVendors.where((v) => v.isOpenNow).toList();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _LC.background,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchHeader(),
                  Expanded(
                    child: _query.isEmpty
                        ? _buildSuggestionsView()
                        : _buildResultsView(displayItems, displayVendors),
                  ),
                ],
              ),
              const GlobalFloatingCart(bottomOffset: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Top Search Header with Animated Placeholder ──────────
  Widget _buildSearchHeader() {
    return Container(
      color: _LC.surface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: _LC.surface,
        border: Border(
          bottom: BorderSide(color: _LC.border.withValues(alpha: 0.8), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _LC.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _LC.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _LC.textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Search Field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _LC.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _focusNode.hasFocus ? _LC.accent : _LC.border,
                  width: _focusNode.hasFocus ? 1.6 : 1.1,
                ),
                boxShadow: _focusNode.hasFocus
                    ? [
                        BoxShadow(
                          color: _LC.accent.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.search_rounded,
                    color: _LC.accent,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Animated Placeholder
                        if (_query.isEmpty)
                          IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.25),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _placeholderHints[_currentHintIndex],
                                key: ValueKey<String>(_placeholderHints[_currentHintIndex]),
                                style: const TextStyle(
                                  color: _LC.textMuted,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: _onSearchChanged,
                          onSubmitted: _onSubmit,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            color: _LC.textPrimary,
                            fontSize: 13.5,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        color: _LC.textMuted,
                        size: 19,
                      ),
                      onPressed: _clearSearch,
                      splashRadius: 18,
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Idle State: Trending Ticker, Recent, Categories & Recs ──
  Widget _buildSuggestionsView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Moving / Animated Trending Searches Ticker ──
          _buildTrendingTickerSection(),

          // ── Persistent Recent Searches Section ─────────
          if (_recentSearches.isNotEmpty) _buildRecentSearchesSection(),

          // ── Popular Categories 4-Column Grid ───────────
          _buildPopularCategoriesSection(),

          // ── Recommended Dishes (Instant Discovery) ────
          if (_recommendedItems.isNotEmpty) _buildRecommendedDishesSection(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── A. Moving / Trending Searches Banner & Chips ────────────
  Widget _buildTrendingTickerSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: _LC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _LC.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Trending Searches',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _LC.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _LC.accentLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _LC.accentBorder),
                  ),
                  child: const Text(
                    'HALDWANI',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _LC.accent,
                      fontFamily: 'Poppins',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              physics: const BouncingScrollPhysics(),
              itemCount: _trendingSearches.length,
              itemBuilder: (ctx, i) {
                final item = _trendingSearches[i];
                final title = item['title'] ?? '';
                final emoji = item['emoji'] ?? '🍴';

                return GestureDetector(
                  onTap: () => _onSuggestionTap(title),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _LC.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _LC.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _LC.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.north_west_rounded,
                          size: 11,
                          color: _LC.accent,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── B. Persistent Recent Searches Section ───────────────────
  Widget _buildRecentSearchesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _LC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: _LC.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Recent Searches',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _LC.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _clearAllRecentSearches,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12,
                      color: _LC.accent,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((term) {
              return Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(
                  color: _LC.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _LC.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _onSuggestionTap(term),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 13,
                            color: _LC.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            term,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _LC.textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeRecentSearch(term),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: _LC.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── C. Popular Categories Grid (Enhanced 4-column) ──────────
  Widget _buildPopularCategoriesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _LC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _LC.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('✨', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Explore Popular Categories',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.88,
            ),
            itemCount: _popularCategories.length,
            itemBuilder: (_, i) {
              final cat = _popularCategories[i];
              final name = cat['name'] as String? ?? '';
              final emoji = cat['emoji'] as String? ?? '🍴';
              final imgUrl = cat['image_url'] as String?;

              return GestureDetector(
                onTap: () => _onSuggestionTap(name),
                child: Container(
                  decoration: BoxDecoration(
                    color: _LC.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _LC.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _LC.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: _LC.border),
                        ),
                        child: ClipOval(
                          child: imgUrl != null && imgUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(
                                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                  ),
                                )
                              : Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _LC.textPrimary,
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

  // ── D. Recommended Dishes Carousel (Instant Cart Adding) ─────
  Widget _buildRecommendedDishesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Text(
            '🌟 Popular Right Now',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _LC.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: _recommendedItems.length,
            itemBuilder: (ctx, i) {
              final item = _recommendedItems[i];
              return Container(
                width: 155,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ExploreItemCard(
                  item: item,
                  onTap: () => _onItemTap(item),
                  rank: i + 1,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 3. Search Results View with Filter Pills ─────────────────
  Widget _buildResultsView(
    List<MenuItemModel> displayItems,
    List<VendorModel> displayVendors,
  ) {
    if (_isLoading) {
      return Column(
        children: [
          Container(
            color: _LC.surface,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Shimmer.fromColors(
                    baseColor: const Color(0xFFE5E7EB),
                    highlightColor: const Color(0xFFFFF8F0),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Shimmer.fromColors(
                    baseColor: const Color(0xFFE5E7EB),
                    highlightColor: const Color(0xFFFFF8F0),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Shimmer.fromColors(
                    baseColor: const Color(0xFFE5E7EB),
                    highlightColor: const Color(0xFFFFF8F0),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFilterChipsRow(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: const Color(0xFFE5E7EB),
                highlightColor: const Color(0xFFFFF8F0),
                child: Container(
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final totalFound = _searchResults.length + _searchVendorResults.length;
    final totalDisplay = displayItems.length + displayVendors.length;

    if (totalFound == 0) {
      return _buildEmptyResultsState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPrimaryTabsRow(displayItems.length, displayVendors.length),
        _buildFilterChipsRow(),
        Expanded(
          child: totalDisplay == 0
              ? _buildFilteredEmptyState()
              : _buildTabContent(displayItems, displayVendors),
        ),
      ],
    );
  }

  // ── Primary Segmented Tabs Row ──────────────────────────────
  Widget _buildPrimaryTabsRow(int dishCount, int vendorCount) {
    final totalCount = dishCount + vendorCount;

    return Container(
      color: _LC.surface,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildTabPill(
              key: 'All',
              label: 'All',
              count: totalCount,
              icon: Icons.grid_view_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabPill(
              key: 'Dishes',
              label: 'Dishes',
              count: dishCount,
              icon: Icons.fastfood_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabPill(
              key: 'Vendors',
              label: 'Vendors',
              count: vendorCount,
              icon: Icons.storefront_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String key,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == key;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? _LC.accent : _LC.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _LC.accent : _LC.border,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _LC.accent.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : _LC.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : _LC.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? _LC.accent : _LC.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter Chips Row (Context-aware) ────────────────────────
  Widget _buildFilterChipsRow() {
    if (_selectedTab == 'Vendors') {
      return Container(
        height: 44,
        color: _LC.surface,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          children: [
            _buildVendorFilterChip('All', 'All Outlets'),
            _buildVendorFilterChip('Veg', '🌱 Pure Veg'),
            _buildVendorFilterChip('TopRated', '⭐ Top Rated (4.0+)'),
            _buildVendorFilterChip('OpenNow', '⚡ Open Now'),
          ],
        ),
      );
    }

    return Container(
      height: 44,
      color: _LC.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          _buildDishFilterChip('All', 'All Items'),
          _buildDishFilterChip('Veg', '🌱 Veg Only'),
          _buildDishFilterChip('Non-Veg', '🍗 Non-Veg'),
          _buildDishFilterChip('Under100', '💰 Under ₹100'),
        ],
      ),
    );
  }

  Widget _buildDishFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = key);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _LC.accentLight : _LC.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _LC.accent : _LC.border,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? _LC.accent : _LC.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorFilterChip(String key, String label) {
    final isSelected = _vendorFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _vendorFilter = key);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _LC.accentLight : _LC.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _LC.accent : _LC.border,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? _LC.accent : _LC.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }



  // ── Tab Content Switcher ─────────────────────────────────────
  Widget _buildTabContent(
    List<MenuItemModel> displayItems,
    List<VendorModel> displayVendors,
  ) {
    if (_selectedTab == 'Vendors') {
      return _buildVendorsOnlyList(displayVendors);
    }
    if (_selectedTab == 'Dishes') {
      return _buildDishesOnlyList(displayItems);
    }
    return _buildCombinedList(displayItems, displayVendors);
  }

  // ── A. Combined "All" View with Clean Categorized Sections ───
  Widget _buildCombinedList(
    List<MenuItemModel> displayItems,
    List<VendorModel> displayVendors,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 72),
      children: [
        // Summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Found ${displayVendors.length} outlet${displayVendors.length != 1 ? 's' : ''} & ${displayItems.length} dish${displayItems.length != 1 ? 'es' : ''} for "$_query"',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _LC.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ),

        // 1. Vendors / Outlets Section
        if (displayVendors.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _LC.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 15,
                    color: _LC.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Restaurants & Stalls (${displayVendors.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _LC.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Spacer(),
                if (displayVendors.length > 2)
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedTab = 'Vendors');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _LC.accent,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: _LC.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Show top vendors (up to 2 in combined view)
          ...displayVendors.take(2).map((v) => _buildVendorSearchCard(v)),

          if (displayVendors.length > 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedTab = 'Vendors');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _LC.accent,
                  side: const BorderSide(color: _LC.accentBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: _LC.surface,
                ),
                icon: const Icon(Icons.storefront_rounded, size: 16),
                label: Text(
                  'View all ${displayVendors.length} restaurants & stalls',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),

          if (displayItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: _LC.border.withValues(alpha: 0.8),
                height: 1,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],

        // 2. Dishes Section
        if (displayItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _LC.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fastfood_rounded,
                    size: 15,
                    color: _LC.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Dishes & Food Items (${displayItems.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _LC.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          ...displayItems.map((item) {
            final vendor = _vendorMap[item.vendorId];
            if (vendor == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: _buildEnhancedItemCard(item, vendor),
            );
          }),
        ],
      ],
    );
  }

  // ── B. Vendors Only View ─────────────────────────────────────
  Widget _buildVendorsOnlyList(List<VendorModel> displayVendors) {
    if (displayVendors.isEmpty) {
      return _buildFilteredEmptyState();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 72),
      itemCount: displayVendors.length + 1,
      separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 4) : const SizedBox(height: 6),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              'Showing ${displayVendors.length} restaurants & food stalls for "$_query"',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _LC.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          );
        }
        return _buildVendorSearchCard(displayVendors[i - 1]);
      },
    );
  }

  // ── C. Dishes Only View ──────────────────────────────────────
  Widget _buildDishesOnlyList(List<MenuItemModel> displayItems) {
    if (displayItems.isEmpty) {
      return _buildFilteredEmptyState();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 72),
      itemCount: displayItems.length + 1,
      separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 4) : const SizedBox(height: 6),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              'Showing ${displayItems.length} dishes for "$_query"',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _LC.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          );
        }
        final item = displayItems[i - 1];
        final vendor = _vendorMap[item.vendorId];
        if (vendor == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: _buildEnhancedItemCard(item, vendor),
        );
      },
    );
  }

  // ── Modern Dedicated Vendor Search Card ──────────────────────
  Widget _buildVendorSearchCard(VendorModel vendor) {
    final isOpen = vendor.isOpenNow;
    final hasImage = vendor.imageUrl != null && vendor.imageUrl!.isNotEmpty;
    final cats = vendor.categories;
    final cuisineText = cats.isNotEmpty
        ? cats.take(3).join(' • ')
        : (vendor.cuisineType?.isNotEmpty == true
            ? vendor.cuisineType!
            : (vendor.specialtyCategory?.isNotEmpty == true
                ? vendor.specialtyCategory!
                : 'Street Food & Snacks'));

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorDetailScreen(vendor: vendor),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _LC.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Vendor Image with Open/Closed Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: vendor.imageUrl!,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 86,
                            height: 86,
                            color: Colors.grey[200],
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 86,
                            height: 86,
                            color: _LC.accentLight,
                            child: const Center(
                              child: Icon(Icons.storefront_rounded, color: _LC.accent, size: 36),
                            ),
                          ),
                        )
                      : Container(
                          width: 86,
                          height: 86,
                          color: _LC.accentLight,
                          child: const Center(
                            child: Text('🏪', style: TextStyle(fontSize: 34)),
                          ),
                        ),
                ),
                // Status Badge (Open / Closed)
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOpen ? _LC.green : _LC.red,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Text(
                      isOpen ? 'OPEN' : 'CLOSED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Right: Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Name + Rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          vendor.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: _LC.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vendor.rating != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _LC.greenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: _LC.green),
                              const SizedBox(width: 2),
                              Text(
                                vendor.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _LC.green,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: Cuisine / Categories
                  Text(
                    cuisineText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _LC.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Row 3: Area & Distance
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: _LC.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          vendor.area.isNotEmpty ? vendor.area : vendor.city,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _LC.textMuted,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vendor.distanceKm != null) ...[
                        Text(
                          ' • ${vendor.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _LC.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),

                  // Row 4: Timing/Delivery + "Menu →"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: _LC.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            vendor.deliveryTime,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _LC.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (vendor.priceForTwo != null) ...[
                            Text(
                              ' • ₹${vendor.priceForTwo} for 2',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _LC.textMuted,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _LC.accentLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _LC.accentBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Menu',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _LC.accent,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _LC.accent),
                          ],
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

  // ── Filtered Empty State (when results exist but filter hides all) ─
  Widget _buildFilteredEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _LC.accentLight,
                shape: BoxShape.circle,
                border: Border.all(color: _LC.accentBorder),
              ),
              child: const Center(
                child: Text('🔍', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No items matching current filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _LC.textPrimary,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Try resetting your filter or switching between Dishes / Vendors.',
              style: TextStyle(
                color: _LC.textMuted,
                fontSize: 12.5,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedFilter = 'All';
                  _vendorFilter = 'All';
                  _selectedTab = 'All';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _LC.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Show All Results',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── True Empty Results State (when zero items/vendors found) ─
  Widget _buildEmptyResultsState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _LC.accentLight,
                shape: BoxShape.circle,
                border: Border.all(color: _LC.accentBorder),
              ),
              child: const Center(
                child: Text('🔍', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No results for "$_query"',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: _LC.textPrimary,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Try searching with a vendor name, dish name, or check trending food below.',
              style: TextStyle(
                color: _LC.textMuted,
                fontSize: 12.5,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickSearchChip('Momos 🥟', 'Momos'),
                _buildQuickSearchChip('Burger 🍔', 'Burger'),
                _buildQuickSearchChip('Chowmein 🍜', 'Chowmein'),
                _buildQuickSearchChip('Pizza 🍕', 'Pizza'),
                _buildQuickSearchChip('Rolls 🌯', 'Rolls'),
                _buildQuickSearchChip('Biryani 🍲', 'Biryani'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSearchChip(String label, String keyword) {
    return InkWell(
      onTap: () => _onSuggestionTap(keyword),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _LC.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _LC.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  // ── Enhanced Modern Search Result Card ───────────────────────
  Widget _buildEnhancedItemCard(MenuItemModel item, VendorModel vendor) {
    final cartProvider = context.watch<CartProvider>();
    final inCartQty = cartProvider.getTotalQuantity(item.id);

    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _LC.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: High Res Food Image with Veg Dot Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 88,
                            height: 88,
                            color: Colors.grey[200],
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 88,
                            height: 88,
                            color: Colors.grey[200],
                            child: const Icon(Icons.fastfood_rounded, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 88,
                          height: 88,
                          color: _LC.accentLight,
                          child: const Center(
                            child: Text('🥟', style: TextStyle(fontSize: 32)),
                          ),
                        ),
                ),
                // Veg / Non-Veg Indicator Icon
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.isVeg ? _LC.green : _LC.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Middle & Right: Details + Direct Cart Button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _LC.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          vendor.name,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _LC.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vendor.rating != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _LC.greenLight,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 11, color: _LC.green),
                              const SizedBox(width: 1.5),
                              Text(
                                vendor.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _LC.green,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price and Add Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '₹${item.appPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: _LC.textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (item.originalPrice != null && item.originalPrice! > item.appPrice) ...[
                            const SizedBox(width: 5),
                            Text(
                              '₹${item.originalPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _LC.textMuted,
                                decoration: TextDecoration.lineThrough,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Direct Add Button with Portions support
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          CartUtils.handleCartAddItem(context, item, vendor);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: inCartQty > 0 ? _LC.accent : _LC.accentLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: inCartQty > 0 ? _LC.accent : _LC.accentBorder,
                            ),
                          ),
                          child: Text(
                            inCartQty > 0 ? 'ADDED ($inCartQty)' : '+ ADD',
                            style: TextStyle(
                              color: inCartQty > 0 ? Colors.white : _LC.accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
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
