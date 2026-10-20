// lib/screens/meals_screen.dart
// Curated Meals Page (Anonymous / Without Restaurant Names)
// ✅ Curated Thalis, High Protein Bowls, Dum Biryani Handis
// ✅ Fully dynamic from Supabase 'curated_meals' table
// ✅ Add to Cart support via CartProvider & CartUtils

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/curated_meal_model.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../providers/cart_provider.dart';
import '../utils/cart_utils.dart';
import '../constants/app_snackbar.dart';
import 'menu_item_detail_screen.dart';

class _LC {
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFEAE8E4);
  static const textPrimary = Color(0xFF1A1814);
  static const textSecondary = Color(0xFF6B6560);
  static const textMuted = Color(0xFF9E9893);
  static const accent = Color(0xFFFF6B2B);
  static const accentLight = Color(0xFFFFF1EB);
  static const accentBorder = Color(0xFFFFD4BC);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const gold = Color(0xFFD97706);
}

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  final _supabase = Supabase.instance.client;
  List<CuratedMealModel> _allMeals = [];
  List<CuratedMealModel> _filteredMeals = [];
  bool _isLoading = true;
  String _selectedCategory = 'All Meals';

  final List<String> _categories = [
    'All Meals',
    'Thalis',
    'Solo Meals',
    'High Protein',
    'Biryani',
    'Family Combos',
  ];

  static final VendorModel _streatEatsKitchenVendor = VendorModel(
    id: 'streateats_signature_kitchen',
    name: 'StreatEats Signature Kitchen',
    area: 'Curated Kitchen',
    city: 'Haldwani',
    phone: '',
    latitude: 29.2183,
    longitude: 79.5130,
    category: 'Curated Meals',
    timing: 'Open 10:00 AM - 11:00 PM',
    isActive: true,
    vendorType: 'both',
    businessType: 'street_food',
  );

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  final Map<String, VendorModel> _vendorsMap = {};

  Future<void> _loadMeals() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Vendors for distance & pickup mapping
      try {
        final vendorsData = await _supabase
            .from('vendors')
            .select()
            .eq('is_active', true);
        for (final v in vendorsData) {
          final vm = VendorModel.fromMap(Map<String, dynamic>.from(v));
          _vendorsMap[vm.id] = vm;
        }
      } catch (_) {}

      // 2. Fetch Curated Meals
      final data = await _supabase
          .from('curated_meals')
          .select()
          .eq('is_available', true)
          .order('display_order', ascending: true);

      final List<CuratedMealModel> loaded = [];
      for (final row in data) {
        loaded.add(CuratedMealModel.fromMap(row));
      }

      if (mounted) {
        setState(() {
          _allMeals = loaded;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading curated meals: $e');
      // If table empty or offline, fallback to sample curated meals
      if (mounted) {
        setState(() {
          _allMeals = _getFallbackMeals();
          _applyFilter();
          _isLoading = false;
        });
      }
    }
  }

  List<CuratedMealModel> _getFallbackMeals() {
    return [
      CuratedMealModel(
        id: 'fallback_meal_1',
        title: 'Royal Amritsari Deluxe Thali',
        tagline: 'StreatEats Signature • Serves 1-2',
        description:
            'Paneer Butter Masala + Dal Makhani + 3 Butter Phulkas + Jeera Rice + Gulab Jamun & Salad',
        price: 189,
        strikePrice: 249,
        category: 'Thalis',
        dietType: 'VEG',
        servesCount: 1,
        caloriesInfo: '480 kcal',
        imageUrl:
            'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=500&q=80',
      ),
      CuratedMealModel(
        id: 'fallback_meal_2',
        title: 'Paneer Tikka & Quinoa Rice Bowl',
        tagline: 'Fit & Healthy • High Protein',
        description:
            'Grilled 200g Paneer cubes, sautéed bell peppers, organic brown rice & mint Greek yogurt dip',
        price: 219,
        strikePrice: 269,
        category: 'High Protein',
        dietType: 'VEG',
        servesCount: 1,
        caloriesInfo: '34g Protein • 420 kcal',
        imageUrl:
            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&q=80',
      ),
      CuratedMealModel(
        id: 'fallback_meal_3',
        title: 'Lucknowi Paneer Dum Biryani Combo',
        tagline: 'Slow Dum Cooked • Clay Handi',
        description:
            'Clay Handi Biryani + Smoked Burani Raita + Mirchi Ka Salan + Roasted Papad + 2 Angoori Jamun',
        price: 239,
        strikePrice: 299,
        category: 'Biryani',
        dietType: 'VEG',
        servesCount: 1,
        caloriesInfo: '520 kcal',
        imageUrl:
            'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&q=80',
      ),
      CuratedMealModel(
        id: 'fallback_meal_4',
        title: 'Executive Ghar Ka Khana Tray',
        tagline: 'Daily Homestyle • Pocket Friendly',
        description:
            'Yellow Dal Tadka, Aloo Gobhi Dry, 4 Ghee Phulkas, Steamed Rice, Pickle & Papad',
        price: 119,
        strikePrice: 149,
        category: 'Solo Meals',
        dietType: 'VEG',
        servesCount: 1,
        caloriesInfo: '380 kcal',
        imageUrl:
            'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=500&q=80',
      ),
    ];
  }

  void _applyFilter() {
    if (_selectedCategory == 'All Meals') {
      _filteredMeals = List.from(_allMeals);
    } else {
      _filteredMeals = _allMeals
          .where(
            (m) =>
                m.category.toLowerCase().contains(
                  _selectedCategory.toLowerCase(),
                ) ||
                _selectedCategory.toLowerCase().contains(
                  m.category.toLowerCase(),
                ),
          )
          .toList();
    }
  }

  void _onCategorySelected(String cat) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = cat;
      _applyFilter();
    });
  }

  void _openMealDetail(CuratedMealModel meal) {
    HapticFeedback.lightImpact();

    VendorModel vendorToUse = _streatEatsKitchenVendor;
    if (meal.vendorId != null && _vendorsMap.containsKey(meal.vendorId)) {
      vendorToUse = _vendorsMap[meal.vendorId]!;
    }

    final item = MenuItemModel(
      id: 'meal_${meal.id}',
      vendorId: vendorToUse.id,
      vendorName: 'StreatEats Signature Kitchen',
      name: meal.title,
      description: meal.description,
      vendorPrice: meal.price,
      appPrice: meal.price,
      originalPrice: meal.strikePrice,
      isDiscounted: meal.strikePrice != null && meal.strikePrice! > meal.price,
      category: meal.category,
      isAvailable: true,
      imageUrl: meal.imageUrl,
      isVeg: meal.isVeg,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemDetailScreen(
          item: item,
          vendor: vendorToUse,
        ),
      ),
    );
  }

  void _addMealToCart(CuratedMealModel meal) {
    HapticFeedback.mediumImpact();

    VendorModel vendorToUse = _streatEatsKitchenVendor;
    if (meal.vendorId != null && _vendorsMap.containsKey(meal.vendorId)) {
      vendorToUse = _vendorsMap[meal.vendorId]!;
    }

    final item = MenuItemModel(
      id: 'meal_${meal.id}',
      vendorId: vendorToUse.id,
      vendorName: 'StreatEats Signature Kitchen',
      name: meal.title,
      description: meal.description,
      vendorPrice: meal.price,
      appPrice: meal.price,
      originalPrice: meal.strikePrice,
      isDiscounted: meal.strikePrice != null && meal.strikePrice! > meal.price,
      category: 'Curated Meals',
      isAvailable: true,
      imageUrl: meal.imageUrl,
      isVeg: meal.isVeg,
    );

    CartUtils.handleCartAddItem(
      context,
      item,
      vendorToUse,
      onSuccess: () {
        AppSnackBar.showSuccess(context, '${meal.title} added to cart!');
      },
      onLimitReached: () {
        AppSnackBar.showError(context, 'Cart limit reached!');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: _loadMeals,
        color: _LC.accent,
        backgroundColor: _LC.surface,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Sticky Header
            SliverPersistentHeader(
              pinned: true,
              delegate: _MealsHeaderDelegate(
                topPadding: topPadding,
                mealCount: _allMeals.length,
              ),
            ),

            // Assurance Banner (No Restaurant Name - Focus on Kitchen Quality)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _LC.gold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '100% Microwave Safe Packaging',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Spill-proof trays • Prepared fresh with pure ingredients',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories horizontal bar
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _onCategorySelected(cat),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSel ? _LC.accent : _LC.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? _LC.accent : _LC.border,
                              width: 1,
                            ),
                            boxShadow:
                                isSel
                                    ? [
                                      BoxShadow(
                                        color: _LC.accent.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : _LC.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == 'All Meals'
                          ? 'Signature Meals & Combos'
                          : _selectedCategory,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _LC.textPrimary,
                      ),
                    ),
                    Text(
                      '${_filteredMeals.length} Available',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _LC.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Meals List Content
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: _LC.accent),
                  ),
                ),
              )
            else if (_filteredMeals.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.lunch_dining_outlined,
                        size: 54,
                        color: _LC.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No meals in this category yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _LC.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final meal = _filteredMeals[i];
                    return _MealCard(
                      meal: meal,
                      onTap: () => _openMealDetail(meal),
                      onAddToCart: () => _addMealToCart(meal),
                    );
                  }, childCount: _filteredMeals.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Header Delegate ──────────────────────────────────────────
class _MealsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final int mealCount;
  _MealsHeaderDelegate({required this.topPadding, required this.mealCount});

  @override
  double get minExtent => topPadding + 58;
  @override
  double get maxExtent => topPadding + 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
      decoration: BoxDecoration(
        color: _LC.surface,
        border: Border(
          bottom: BorderSide(
            color: _LC.border.withValues(alpha: shrinkOffset > 0 ? 1 : 0),
            width: 0.8,
          ),
        ),
        boxShadow:
            shrinkOffset > 0
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _LC.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lunch_dining_rounded,
              color: _LC.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Curated Chef Meals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _LC.textPrimary,
                  ),
                ),
                Text(
                  'Deluxe Thalis, Bowls & Handi Combos',
                  style: TextStyle(
                    fontSize: 11,
                    color: _LC.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _LC.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _LC.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.bolt, color: _LC.green, size: 13),
                SizedBox(width: 3),
                Text(
                  'Fresh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _LC.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MealsHeaderDelegate oldDelegate) =>
      oldDelegate.topPadding != topPadding ||
      oldDelegate.mealCount != mealCount;
}

// ── Meal Item Card ───────────────────────────────────────────
class _MealCard extends StatelessWidget {
  final CuratedMealModel meal;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _MealCard({
    required this.meal,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCartQty = cart.getQuantity('meal_${meal.id}');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _LC.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Left: Meal Image with Badges
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 95,
                height: 95,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: meal.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, __, ___) => _fallbackImagePlaceholder(),
                      )
                    else
                      _fallbackImagePlaceholder(),

                    // Serves badge
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          meal.servesCount > 1
                              ? 'Serves ${meal.servesCount}'
                              : 'Meal for 1',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Right: Info & Add button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tagline & Diet icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: meal.isVeg ? _LC.green : _LC.red,
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: meal.isVeg ? _LC.green : _LC.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meal.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _LC.gold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Meal Title
                  Text(
                    meal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: _LC.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Description / Components
                  Text(
                    meal.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _LC.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Calories & Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price & calories
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '₹${meal.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: _LC.textPrimary,
                                ),
                              ),
                              if (meal.strikePrice != null &&
                                  meal.strikePrice! > meal.price) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₹${meal.strikePrice!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _LC.textMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (meal.caloriesInfo != null &&
                              meal.caloriesInfo!.isNotEmpty)
                            Text(
                              meal.caloriesInfo!,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: _LC.green,
                              ),
                            ),
                        ],
                      ),

                      // Add to Cart Button
                      InkWell(
                        onTap: onAddToCart,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                inCartQty > 0 ? _LC.accent : _LC.accentLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  inCartQty > 0 ? _LC.accent : _LC.accentBorder,
                            ),
                          ),
                          child: Text(
                            inCartQty > 0 ? 'ADDED ($inCartQty)' : '+ ADD',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  inCartQty > 0 ? Colors.white : _LC.accent,
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
    ),
  );
}

  Widget _fallbackImagePlaceholder() {
    return Container(
      color: _LC.accentLight,
      child: const Center(
        child: Icon(
          Icons.lunch_dining_rounded,
          color: _LC.accent,
          size: 32,
        ),
      ),
    );
  }
}
