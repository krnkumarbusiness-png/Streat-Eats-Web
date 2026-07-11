// lib/screens/street_food_screen.dart
// v3.3 — Search fix: vendorMenuItems ab SearchScreen ko pass hoga
// ✅ FIX 1: _menuItemsMap field added
// ✅ FIX 2: _loadVendors() mein fetchAllMenuItemsGrouped() call added
// ✅ FIX 3: _StreetFoodHeaderDelegate ko menuItemsMap pass hoga
// ✅ All v3.2 features 100% preserved

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import '../providers/user_provider.dart';
import '../providers/cart_provider.dart';
import '../services/vendor_service.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../services/menu_service.dart'; // ✅ FIX 1 — import added
import 'vendor_detail_screen.dart';
import 'search_screen.dart';
import '../widgets/vendor_card.dart';
import '../widgets/disclaimer_widget.dart';

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
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
}

class StreetFoodScreen extends StatefulWidget {
  final ValueNotifier<String>? selectedCategoryNotifier;

  const StreetFoodScreen({super.key, this.selectedCategoryNotifier});

  @override
  State<StreetFoodScreen> createState() => _StreetFoodScreenState();
}

class _StreetFoodScreenState extends State<StreetFoodScreen>
    with WidgetsBindingObserver {
  final _vendorService = VendorService();
  final _locationService = LocationService();
  final _menuService = MenuService(); // ✅ FIX 2 — MenuService instance
  final _supabase = Supabase.instance.client;

  List<VendorModel> _allVendors = [];
  List<VendorModel> _filteredVendors = [];
  Position? _userPosition;
  bool _isLoading = true;
  String _selectedCategory = 'All';

  // ✅ FIX 3 — menu items map for SearchScreen
  Map<String, List<MenuItemModel>> _menuItemsMap = {};

  bool? _locationGranted;
  bool _locationServiceEnabled = true;

  bool _isWithinTime = true;
  bool _isTimingEnabled = false;
  bool get _isAppActive => !_isTimingEnabled || _isWithinTime;
  String _openTime = '17:00';
  final String _closeTime = '21:00';

  Timer? _timingCheckTimer;

  final List<String> _staticCategories = [
    'All',
    'Momos',
    'Burger',
    'Chowmein',
    'Pizza',
    'Chaat',
    'Maggi',
    'Sandwich',
    'Shake',
  ];

  List<Map<String, dynamic>> _categories = [];

  final Map<String, String> _categoryEmojis = {
    'All': '✦',
    'Momos': '🥟',
    'Burger': '🍔',
    'Chowmein': '🍜',
    'Pizza': '🍕',
    'Chaat': '🍛',
    'Maggi': '🍝',
    'Sandwich': '🥪',
    'Shake': '🥤',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _categories = _staticCategories
        .map(
          (c) => {
            'name': c,
            'emoji': _categoryEmojis[c] ?? '🍴',
            'image_url': null,
          },
        )
        .toList();

    widget.selectedCategoryNotifier?.addListener(_onExternalCategoryChange);

    _initScreen();
  }

  @override
  void dispose() {
    widget.selectedCategoryNotifier?.removeListener(_onExternalCategoryChange);
    WidgetsBinding.instance.removeObserver(this);
    _timingCheckTimer?.cancel();
    super.dispose();
  }

  void _onExternalCategoryChange() {
    final cat = widget.selectedCategoryNotifier?.value ?? 'All';
    if (cat != _selectedCategory) {
      _onCategorySelected(cat);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      final granted = await _locationService.hasPermission();
      if (!mounted) return;
      setState(() {
        _locationServiceEnabled = serviceEnabled;
        _locationGranted = granted;
      });
      if (granted && _userPosition == null) {
        _fetchLocationAndUpdateVendors();
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
    }
  }

  Future<void> _onLocationBannerTap() async {
    HapticFeedback.lightImpact();
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _locationService.openLocationSettings();
      return;
    }
    final permanentlyDenied = await _locationService.isPermanentlyDenied();
    if (permanentlyDenied) {
      await _locationService.openAppSettings();
      return;
    }
    final granted = await _locationService.requestPermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _locationGranted = true);
      _fetchLocationAndUpdateVendors();
    } else {
      setState(() => _locationGranted = false);
    }
  }

  Future<void> _fetchLocationAndUpdateVendors() async {
    final position = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (position != null) {
      _userPosition = position;
      if (_allVendors.isNotEmpty) {
        for (var v in _allVendors) {
          v.distanceKm = _locationService.getDistanceKm(
            position.latitude,
            position.longitude,
            v.latitude,
            v.longitude,
          );
          v.deliveryMinutes = _locationService.getDeliveryMinutes(
            v.distanceKm!,
          );
        }
        _allVendors.sort(
          (a, b) => (a.distanceKm ?? 99).compareTo(b.distanceKm ?? 99),
        );
        setState(() {
          _filteredVendors = _selectedCategory == 'All'
              ? _allVendors
              : _allVendors
                    .where(
                      (v) => v.category
                          .split(',')
                          .map((c) => c.trim().toLowerCase())
                          .contains(_selectedCategory.toLowerCase()),
                    )
                    .toList();
        });
      } else {
        await _loadVendors();
      }
    }
  }

  Future<void> _checkAppTiming() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('is_timing_enabled, open_time, close_time')
          .limit(1)
          .maybeSingle();
      if (data == null) {
        _applyFallbackTiming();
        return;
      }
      final bool timingEnabled = data['is_timing_enabled'] as bool? ?? true;
      final String openTime = data['open_time'] as String? ?? '17:00';
      if (!timingEnabled) {
        if (mounted) {
          setState(() {
            _isTimingEnabled = false;
            _isWithinTime = true;
            _openTime = openTime;
          });
        }
        return;
      }
      final isOpen = await OrderService().isAppOpen();
      final nextOpen = await OrderService().getNextOpenTime();
      // Vendor shift hours sync karo
      final settingsData = await Supabase.instance.client
          .from('app_settings')
          .select('time_slots')
          .limit(1)
          .maybeSingle();
      if (settingsData != null) {
        final slotsRaw = settingsData['time_slots'];
        if (slotsRaw != null) {
          final enabledSlots = (slotsRaw as List)
              .map((s) => Map<String, dynamic>.from(s as Map))
              .where(
                (s) =>
                    (s['enabled'] as bool? ?? true) &&
                    (s['open'] as String? ?? '').isNotEmpty &&
                    (s['close'] as String? ?? '').isNotEmpty,
              )
              .toList();

          if (enabledSlots.length == 1) {
            // ✅ Single global slot — morning aur evening dono isi se set honge
            final s = enabledSlots.first;
            final openHour =
                int.tryParse((s['open'] as String).split(':')[0]) ?? 0;
            final closeHour =
                int.tryParse((s['close'] as String).split(':')[0]) ?? 0;
            VendorModel.morningStartHour = openHour;
            VendorModel.morningEndHour = closeHour;
            VendorModel.eveningStartHour = openHour;
            VendorModel.eveningEndHour = closeHour;
          } else {
            for (final slot in enabledSlots) {
              final open = slot['open'] as String;
              final close = slot['close'] as String;
              final openHour = int.tryParse(open.split(':')[0]) ?? 0;
              final closeHour = int.tryParse(close.split(':')[0]) ?? 0;
              if (openHour < 14) {
                VendorModel.morningStartHour = openHour;
                VendorModel.morningEndHour = closeHour;
              } else {
                VendorModel.eveningStartHour = openHour;
                VendorModel.eveningEndHour = closeHour;
              }
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _isTimingEnabled = true;
          _isWithinTime = isOpen;
          _openTime = nextOpen.isNotEmpty ? nextOpen : openTime;
        });
      }
    } catch (_) {
      _applyFallbackTiming();
    }
  }

  void _applyFallbackTiming() {
    if (mounted) setState(() => _isWithinTime = true);
  }

  Future<void> _initScreen() async {
    await _checkLocationPermission();
    await context.read<UserProvider>().fetchUserData();
    await context.read<CartProvider>().reloadSettings();
    await _checkAppTiming();

    _timingCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (mounted) {
        await _checkAppTiming();
        await context.read<CartProvider>().reloadSettings();
      }
    });

    if (_locationGranted == true) {
      _userPosition = await _locationService.getCurrentLocation();
    }
    await _loadVendors();

    final pendingCat = widget.selectedCategoryNotifier?.value ?? 'All';
    if (pendingCat != 'All' && mounted) {
      _onCategorySelected(pendingCat);
    }
  }

  Future<void> _loadVendors() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final vendors = await _vendorService.getStreetFoodVendors();

      if (_userPosition != null) {
        for (var v in vendors) {
          final dist = _locationService.getDistanceKm(
            _userPosition!.latitude,
            _userPosition!.longitude,
            v.latitude,
            v.longitude,
          );
          v.distanceKm = dist;
          v.deliveryMinutes = _locationService.getDeliveryMinutes(dist);
        }
        vendors.sort(
          (a, b) => (a.distanceKm ?? 99).compareTo(b.distanceKm ?? 99),
        );
      }

      // Build unique category set from vendor data
      final Set<String> vendorCategorySet = {};
      for (final v in vendors) {
        vendorCategorySet.addAll(
          v.category.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty),
        );
      }

      // Merge static + dynamic categories
      final List<String> merged = ['All'];
      for (final cat in _staticCategories.skip(1)) {
        if (vendorCategorySet.contains(cat)) merged.add(cat);
      }
      for (final cat in vendorCategorySet) {
        if (!merged.contains(cat)) {
          merged.add(cat);
          if (!_categoryEmojis.containsKey(cat)) {
            _categoryEmojis[cat] = '🍴';
          }
        }
      }

      // food_categories table se image_url fetch karo
      Map<String, String?> catImages = {};
      try {
        final imgRows = await _supabase
            .from('food_categories')
            .select('name, image_url');
        for (final r in (imgRows as List)) {
          catImages[r['name'] as String] = r['image_url'] as String?;
        }
      } catch (_) {
        // emoji fallback chalega
      }

      // String list ko Map list mein convert karo with images
      final List<Map<String, dynamic>> mergedMaps = merged
          .map(
            (name) => {
              'name': name,
              'emoji': _categoryEmojis[name] ?? '🍴',
              'image_url': catImages[name],
            },
          )
          .toList();

      // ✅ FIX 4 — Saare menu items grouped by vendorId fetch karo
      Map<String, List<MenuItemModel>> menuMap = {};
      try {
        menuMap = await _menuService.fetchAllMenuItemsGrouped();
      } catch (e) {
        debugPrint('Menu items fetch error: $e');
      }

      if (!mounted) return;
      setState(() {
        _allVendors = vendors;
        _categories = mergedMaps;
        _menuItemsMap = menuMap; // ✅ FIX 5 — state mein set karo
        _filteredVendors = _selectedCategory == 'All'
            ? vendors
            : vendors
                  .where(
                    (v) => v.category
                        .split(',')
                        .map((c) => c.trim().toLowerCase())
                        .contains(_selectedCategory.toLowerCase()),
                  )
                  .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filteredVendors = category == 'All'
          ? _allVendors
          : _allVendors
                .where(
                  (v) => v.category
                      .split(',')
                      .map((c) => c.trim().toLowerCase())
                      .contains(category.toLowerCase()),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final showLocationBanner =
        _locationGranted == false || !_locationServiceEnabled;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await _checkLocationPermission();
          await _checkAppTiming();
          await context.read<CartProvider>().reloadSettings();
          await _loadVendors();
        },
        color: _LC.accent,
        backgroundColor: _LC.surface,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sticky Header ──────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StreetFoodHeaderDelegate(
                isAppActive: _isAppActive,
                allVendors: _allVendors,
                topPadding: topPadding,
                menuItemsMap: _menuItemsMap, // ✅ FIX 6 — pass karo
              ),
            ),

            // Location permission banner
            if (showLocationBanner)
              SliverToBoxAdapter(
                child: _LocationPermissionBanner(
                  serviceEnabled: _locationServiceEnabled,
                  onTap: _onLocationBannerTap,
                ),
              ),

            // Categories
            SliverToBoxAdapter(child: _buildCategoriesSection()),

            // Vendor section header
            SliverToBoxAdapter(child: _buildVendorSectionHeader()),

            // Vendors
            if (!_isAppActive)
              SliverToBoxAdapter(
                child: _ClosedInlineWidget(openTime: _openTime),
              )
            else if (_isLoading)
              const SliverToBoxAdapter(child: _ShimmerList())
            else if (_filteredVendors.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final v = _filteredVendors[i];
                    return VendorCard(
                      vendor: v,
                      onTap: () {
                        if (v.distanceKm != null && v.distanceKm! > 0) {
                          context
                              .read<CartProvider>()
                              .setDeliveryChargeForDistance(v.distanceKm!);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VendorDetailScreen(vendor: v),
                          ),
                        );
                      },
                      layout: 'list',
                    );
                  }, childCount: _filteredVendors.length),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: DisclaimerWidget()),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            'What are you craving? 🤤',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _LC.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        SizedBox(
          height: 94,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final name = cat['name'] as String? ?? '';
              final emoji = cat['emoji'] as String? ?? '🍴';
              final imgUrl = cat['image_url'] as String?;
              final isSelected = _selectedCategory == name;

              return GestureDetector(
                onTap: () => _onCategorySelected(name),
                child: Container(
                  width: 68,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: isSelected ? _LC.accentLight : _LC.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? _LC.accent : _LC.border,
                            width: isSelected ? 2.0 : 1.2,
                          ),
                        ),
                        child: ClipOval(
                          child: imgUrl != null && imgUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  width: 58,
                                  height: 58,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? _LC.accent : _LC.textSecondary,
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildVendorSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isAppActive ? 'Vendors Near You 🏪' : "We're Closed 🔒",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isAppActive
                    ? (_userPosition != null
                          ? 'Sorted by distance'
                          : 'Haldwani area')
                    : 'Opens at $_openTime daily',
                style: const TextStyle(
                  fontSize: 12,
                  color: _LC.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          if (_isAppActive && _filteredVendors.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _LC.accentLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _LC.accentBorder),
              ),
              child: Text(
                '${_filteredVendors.length} open',
                style: const TextStyle(
                  color: _LC.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: _LC.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('😕', style: TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Vendors Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _LC.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No street food vendors available right now.',
              style: TextStyle(
                color: _LC.textMuted,
                fontSize: 13,
                height: 1.5,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadVendors,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _LC.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Street Food Header Delegate ──────────────────────────────
class _StreetFoodHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isAppActive;
  final List<VendorModel> allVendors;
  final double topPadding;
  final Map<String, List<MenuItemModel>> menuItemsMap; // ✅ FIX 7 — new param

  _StreetFoodHeaderDelegate({
    required this.isAppActive,
    required this.allVendors,
    required this.topPadding,
    required this.menuItemsMap, // ✅ FIX 8 — required
  });

  static const double _headerContentHeight = 106.0;

  @override
  double get minExtent => topPadding + _headerContentHeight;
  @override
  double get maxExtent => topPadding + _headerContentHeight;

  @override
  bool shouldRebuild(_StreetFoodHeaderDelegate old) {
    return old.isAppActive != isAppActive ||
        old.allVendors != allVendors ||
        old.topPadding != topPadding ||
        old.menuItemsMap != menuItemsMap; // ✅ FIX 9 — rebuild check
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: topPadding + _headerContentHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('🥟', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Street Food',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isAppActive ? _LC.green : _LC.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAppActive ? 'Open' : 'Closed',
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
            const SizedBox(height: 10),
            // ✅ FIX 10 — SearchScreen ko vendorMenuItems pass karo
            Builder(
              builder: (ctx) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    ctx,
                    PageRouteBuilder(
                      pageBuilder: (_, anim, __) => SearchScreen(
                        vendors: allVendors,
                        vendorMenuItems: menuItemsMap, // ✅ THE KEY FIX
                      ),
                      transitionsBuilder: (_, anim, __, child) =>
                          SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.05),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                      transitionDuration: const Duration(milliseconds: 280),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: _LC.textMuted,
                          size: 17,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Search street food...',
                          style: TextStyle(
                            color: _LC.textMuted,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Location Banner ──────────────────────────────────────────
class _LocationPermissionBanner extends StatelessWidget {
  final bool serviceEnabled;
  final VoidCallback onTap;
  const _LocationPermissionBanner({
    required this.serviceEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isServiceOff = !serviceEnabled;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _LC.warningLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _LC.warning.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _LC.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: _LC.warning,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isServiceOff
                        ? 'Location service is off'
                        : 'Location permission not granted',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _LC.textPrimary,
                    ),
                  ),
                  Text(
                    isServiceOff
                        ? 'Turn on location in settings'
                        : 'Tap to allow location access',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _LC.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _LC.textMuted,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Closed Widget ────────────────────────────────────────────
class _ClosedInlineWidget extends StatefulWidget {
  final String openTime;
  const _ClosedInlineWidget({required this.openTime});

  @override
  State<_ClosedInlineWidget> createState() => _ClosedInlineWidgetState();
}

class _ClosedInlineWidgetState extends State<_ClosedInlineWidget> {
  late Duration _timeUntilOpen;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(_calculateTimeLeft),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    final parts = widget.openTime.split(':');
    final openHour = int.tryParse(parts[0]) ?? 17;
    final openMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    var nextOpen = DateTime(now.year, now.month, now.day, openHour, openMinute);
    if (nextOpen.isBefore(now)) {
      nextOpen = nextOpen.add(const Duration(days: 1));
    }
    _timeUntilOpen = nextOpen.difference(now);
    if (_timeUntilOpen.isNegative) _timeUntilOpen = Duration.zero;
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _two(_timeUntilOpen.inHours);
    final m = _two(_timeUntilOpen.inMinutes.remainder(60));
    final s = _two(_timeUntilOpen.inSeconds.remainder(60));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _LC.border),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _LC.accentLight,
                shape: BoxShape.circle,
                border: Border.all(color: _LC.accentBorder, width: 2),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/illus_sleeping_chef.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We Are Closed 🔒',
              style: TextStyle(
                color: _LC.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'We open daily at ${widget.openTime}',
              style: const TextStyle(
                color: _LC.textMuted,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            const Text(
              'OPENS IN',
              style: TextStyle(
                color: _LC.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimerBox(value: h, label: 'HRS'),
                const _TimerDivider(),
                _TimerBox(value: m, label: 'MIN'),
                const _TimerDivider(),
                _TimerBox(value: s, label: 'SEC'),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _LC.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _LC.accentBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📱', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Follow us!',
                        style: TextStyle(
                          color: _LC.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        '@streateats.app',
                        style: TextStyle(
                          color: _LC.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
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

class _TimerBox extends StatelessWidget {
  final String value, label;
  const _TimerBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 58,
          decoration: BoxDecoration(
            color: _LC.accentLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _LC.accentBorder),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: _LC.accent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: _LC.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _TimerDivider extends StatelessWidget {
  const _TimerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18, left: 6, right: 6),
      child: Text(
        ':',
        style: TextStyle(
          color: _LC.accent,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

// ── Shimmer List ─────────────────────────────────────────────
class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => AnimatedBuilder(
          animation: _shimmerAnim,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
                colors: const [
                  Color(0xFFEEEBE6),
                  Color(0xFFF7F5F2),
                  Color(0xFFEEEBE6),
                ],
                transform: GradientRotation(_shimmerAnim.value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Different Vendor Dialog ──────────────────────────────────
class DifferentVendorDialog {
  static Future<bool> show({
    required BuildContext context,
    required String newVendorName,
    required String currentVendorName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _LC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _LC.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _LC.warningLight,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🛒', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Start New Cart? 🛒',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: _LC.textSecondary,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Your cart has items from '),
                    TextSpan(
                      text: currentVendorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _LC.textPrimary,
                      ),
                    ),
                    const TextSpan(text: '.\nAdding from '),
                    TextSpan(
                      text: newVendorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _LC.accent,
                      ),
                    ),
                    const TextSpan(text: ' will clear your current cart.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _LC.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _LC.textMuted,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _LC.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Clear & Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
