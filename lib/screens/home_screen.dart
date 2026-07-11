// lib/screens/home_screen.dart
// v23.0 — UI Updates: 4 sections redesigned as per HTML mockups
// ✅ CHANGE 1: _RecommendedItemsSection — Featured big card + small horizontal cards
// ✅ CHANGE 2: _RecommendedRestaurantsSection — Vertical list style (not horizontal scroll)
// ✅ CHANGE 3: _WhyChooseUs — 4 rows + updated header text
// ✅ CHANGE 4: _HowItWorks — Step numbers + updated icons/labels
// ✅ CHANGE 5: _VendorCard — New banner-top design with category tag + item chips
// ✅ Everything else IDENTICAL to v22.0 — no logic/function changes
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';
import '../services/menu_service.dart';
import '../services/vendor_service.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import 'street_food_screen.dart';
import 'profile_screen.dart';
import 'order_history_screen.dart';
import 'cart_screen.dart';
import 'vendor_detail_screen.dart';
import 'menu_item_detail_screen.dart';
import 'search_screen.dart';
import 'package:geocoding/geocoding.dart';
import 'sweets_screen.dart'; // naya screen
import '../models/combo_model.dart';
import '../services/combo_service.dart';
import '../services/offer_service.dart';
import 'combos_list_screen.dart';
import 'combo_detail_screen.dart';
import 'order_status_screen.dart';
import '../widgets/vendor_card.dart';
import 'location_picker_screen.dart';
import 'address_selection_screen.dart';
import 'login_screen.dart';
import '../widgets/disclaimer_widget.dart';

// ─── Local Colors ─────────────────────────────────────────
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
  static const blue = Color(0xFF2563EB);
  static const blueLight = Color(0xFFEFF6FF);
  static const gold = Color(0xFFD97706);
  static const goldLight = Color(0xFFFEF3C7);
}

// ─── Banner Model ─────────────────────────────────────────
class _BannerData {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? emoji;
  final String? emojiImageUrl;
  final Color themeColor;
  final String? actionRoute;
  final String bannerType;

  const _BannerData({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.emoji,
    this.emojiImageUrl,
    required this.themeColor,
    this.actionRoute,
    this.bannerType = 'text',
  });

  bool get isImageBanner {
    if (bannerType == 'image') return true;
    if (bannerType == 'text') return false;
    return imageUrl != null && imageUrl!.trim().isNotEmpty;
  }

  factory _BannerData.fromMap(Map<String, dynamic> m) {
    Color color = _LC.accent;
    for (final key in ['theme_color', 'bg_color']) {
      final hex = m[key] as String?;
      if (hex != null && hex.isNotEmpty) {
        try {
          color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
          break;
        } catch (_) {}
      }
    }
    final imageUrl = m['image_url'] as String?;
    final cleanUrl = (imageUrl != null && imageUrl.trim().isNotEmpty)
        ? imageUrl.trim()
        : null;
    final bannerType =
        (m['banner_type'] as String?)?.trim().toLowerCase() ?? 'text';
    return _BannerData(
      id: m['id']?.toString() ?? '',
      title: m['title'] as String? ?? '',
      subtitle: m['subtitle'] as String? ?? '',
      imageUrl: cleanUrl,
      emoji: m['emoji'] as String?,
      emojiImageUrl: m['emoji_image_url'] as String?,
      themeColor: color,
      actionRoute: m['action_route'] as String?,
      bannerType: bannerType,
    );
  }
}

final _kFallbackBanners = [
  const _BannerData(
    id: 'f1',
    title: 'Hungry?\nOrder on Streat Eats',
    subtitle: "Today's Special",
    emoji: '🥟',
    themeColor: Color(0xFF8B1A00),
    actionRoute: 'street_food',
    bannerType: 'text',
  ),
  const _BannerData(
    id: 'f2',
    title: 'Local Restaurants\nAt Lower Prices',
    subtitle: 'Now on Streat Eats',
    emoji: '🍽️',
    themeColor: _LC.blue,
    actionRoute: 'restaurants',
    bannerType: 'text',
  ),
];

const _kQuickFilters = [
  '⚡ Near & Fast',
  '⭐ Top Rated',
  '₹ Under ₹200',
  '🆕 New Vendors',
  '🔥 Trending',
];

// ── Session cache ─────────────────────────────────────────
class _HomeCache {
  static List<_BannerData>? banners;
  static List<Map<String, dynamic>>? categories;
  static List<MenuItemModel>? recommendedItems;
  static List<VendorModel>? allVendors;
  static List<VendorModel>? recommendedRestaurants;
  static bool? isAppActive;
  static String openTime = '17:00';
  static String closeTime = '21:00';
  static String nextOpenTime = '17:00';
  static DateTime? lastFetched;
  static bool isInDeliveryZone = true;
  static double? userLat;
  static double? userLng;
  static bool isTimingEnabled = true;
  static List<ComboModel>? homeCombos;
  static List<Map<String, dynamic>>? homeOffers;

  static bool get isStale {
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched!) >
        const Duration(minutes: 10);
  }

  static void invalidate() {
    banners = null;
    categories = null;
    recommendedItems = null;
    allVendors = null;
    recommendedRestaurants = null;
    isAppActive = null;
    isInDeliveryZone = true;
    lastFetched = null;
    homeCombos = null; // ✅ NEW
    homeOffers = null; // ✅ NEW OFFERS
  }
}

const _kLocationSheetShownKey = 'se_location_sheet_shown';

// ═══════════════════════════════════════════════════════════
// ROOT — HomeScreen
// ═══════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final ValueNotifier<String> _streetFoodCatNotifier = ValueNotifier('All');
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeTab(onSwitchTab: _switchTab, onNavVisibilityChanged: (_) {}),
      StreetFoodScreen(selectedCategoryNotifier: _streetFoodCatNotifier),
      const ProfileScreen(),
      const SweetsScreen(),
      const OrderHistoryScreen(),
      const CartScreen(),
    ];
  }

  @override
  void dispose() {
    _streetFoodCatNotifier.dispose();
    super.dispose();
  }

  void _switchTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_tab != 0) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: _LC.background,
        body: IndexedStack(index: _tab, children: _pages),
        bottomNavigationBar: _BottomNav(
          current: _tab,
          onTap: _switchTab,
          cartCount: context.watch<CartProvider>().totalItems,
        ),
      ),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final int cartCount;
  const _BottomNav({
    required this.current,
    required this.onTap,
    required this.cartCount,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            border: Border(
              top: BorderSide(color: _LC.border.withOpacity(0.6), width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, -8),
              ),
              BoxShadow(
                color: _LC.accent.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    idx: 0,
                    current: current,
                    onTap: onTap,
                  ),
                  _NavItem(
                    icon: Icons.storefront_outlined,
                    activeIcon: Icons.storefront_rounded,
                    label: 'Street Food',
                    idx: 1,
                    current: current,
                    onTap: onTap,
                  ),
                  _NavProfile(idx: 2, current: current, onTap: onTap),
                  _NavItem(
                    icon: Icons.cake_outlined,
                    activeIcon: Icons.cake_rounded,
                    label: 'Sweets',
                    idx: 3,
                    current: current,
                    onTap: onTap,
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    label: 'Orders',
                    idx: 4,
                    current: current,
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int idx, current;
  final ValueChanged<int> onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.idx,
    required this.current,
    required this.onTap,
  });
  bool get _sel => current == idx;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _sel ? _LC.accentLight : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _sel ? activeIcon : icon,
                size: 22,
                color: _sel ? _LC.accent : _LC.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: _sel ? FontWeight.w700 : FontWeight.normal,
                color: _sel ? _LC.accent : _LC.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavProfile extends StatefulWidget {
  final int idx, current;
  final ValueChanged<int> onTap;
  const _NavProfile({
    required this.idx,
    required this.current,
    required this.onTap,
  });

  @override
  State<_NavProfile> createState() => _NavProfileState();
}

class _NavProfileState extends State<_NavProfile> {
  String? _avatarUrl;
  final bool _sel = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('users')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      final url = data?['avatar_url'] as String?;
      if (url != null && url.trim().isNotEmpty && mounted) {
        setState(() => _avatarUrl = url.trim());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.current == widget.idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTap(widget.idx),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [_LC.accent, Color(0xFFFF8C5A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFFEAE8E4),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _LC.accent.withOpacity(0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                  border: isSelected
                      ? Border.all(color: _LC.accent, width: 2.5)
                      : Border.all(color: const Color(0xFFD0CEC9), width: 1.5),
                ),
                child: ClipOval(
                  child: _avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _avatarUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _defaultIcon(isSelected),
                        )
                      : _defaultIcon(isSelected),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected ? _LC.accent : _LC.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultIcon(bool isSelected) => Container(
    color: isSelected ? _LC.accent : const Color(0xFFEAE8E4),
    child: Icon(
      Icons.person_rounded,
      color: isSelected ? Colors.white : _LC.textMuted,
      size: 22,
    ),
  );
}

class _NavBadge extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int idx, current, badge;
  final ValueChanged<int> onTap;
  const _NavBadge({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.idx,
    required this.current,
    required this.onTap,
    required this.badge,
  });
  bool get _sel => current == idx;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _sel ? _LC.accentLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _sel ? activeIcon : icon,
                    size: 22,
                    color: _sel ? _LC.accent : _LC.textMuted,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: _LC.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: _sel ? FontWeight.w700 : FontWeight.normal,
                color: _sel ? _LC.accent : _LC.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  final void Function(int) onSwitchTab;
  final void Function(bool) onNavVisibilityChanged;
  const _HomeTab({
    required this.onSwitchTab,
    required this.onNavVisibilityChanged,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  final _vendorService = VendorService();
  final _locationService = LocationService();

  final Map<String, VendorModel> _vendorCache = {};

  final ScrollController _scrollController = ScrollController();
  final double _lastScrollOffset = 0;

  late final PageController _bannerCtrl;
  Timer? _bannerTimer;
  Timer? _timingTimer;

  List<_BannerData> _banners = [];
  int _activePage = 0;
  Color _bannerColor = const Color(0xFF8B1A00);
  bool _loadingBanners = true;

  List<Map<String, dynamic>> _categories = [];
  bool _loadingCats = true;

  List<VendorModel> _allVendors = [];
  List<MenuItemModel> _recommendedItems = [];
  bool _loadingRec = true;

  List<VendorModel> _recommendedRestaurants = [];
  bool _loadingRecRest = true;

  bool _isAppActive = true;
  String _openTime = '17:00';
  String _closeTime = '21:00';

  bool _isInDeliveryZone = true;
  bool _checkingZone = false;

  bool? _locationGranted;
  bool _locationServiceEnabled = true;

  bool _locationSheetShown = false;
  bool _manualLocationActive =
      false; // ✅ true jab user explicitly address select kare

  String _selectedCategory = 'All';
  List<MenuItemModel> _filteredItems = [];
  bool _loadingFiltered = false;

  bool _popupShown = false;
  Timer? _loginPromptTimer;
  final bool _loginPromptShown = false;
  bool _loginPromptStopped =
      false; // ✅ NEW — login screen pe gaya to dobara popup na aaye
  Map<String, List<MenuItemModel>> _menuItemsGrouped = {};
  String _userArea = 'Haldwani'; // ← YE ADD KARO
  List<ComboModel> _homeCombos = [];
  bool _loadingCombos = true;
  List<Map<String, dynamic>> _homeOffers = [];
  bool _loadingOffers = true;

  static const double _bannerH = 200.0;
  static const double _locationH = 52.0;
  static const double _searchH = 50.0;

  double get _topPad => MediaQuery.of(context).padding.top;
  double get _headerTotalH => _topPad + _locationH + _searchH + _bannerH + 24;

  static const String _popupPrefKey = 'se_banner_popup_last_shown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(() {});
    _bannerCtrl = PageController(initialPage: 0);
    _loadAll(forceRefresh: _HomeCache.isStale);
    _startTimingTimer();
    _checkLocationAndMaybeShowSheet();
    _scheduleLoginPrompt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _bannerTimer?.cancel();
    _timingTimer?.cancel();
    _loginPromptTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission();
    }
  }

  void _startTimingTimer() {
    _timingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _checkTiming();
    });
  }

  Future<void> _checkLocationAndMaybeShowSheet() async {
    try {
      final serviceEnabled = await LocationService().isLocationServiceEnabled();
      final granted = await LocationService().hasPermission();

      if (!mounted) return;

      setState(() {
        _locationServiceEnabled = serviceEnabled;
        _locationGranted = granted;
      });

      if (granted && serviceEnabled) {
        _fetchUserLocation();
        return;
      }

      if (!_locationSheetShown) {
        _locationSheetShown = true;
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        _showLocationBottomSheet();
      }
    } catch (_) {}
  }

  Future<void> _checkLocationPermission() async {
    try {
      final serviceEnabled = await LocationService().isLocationServiceEnabled();
      final granted = await LocationService().hasPermission();
      if (!mounted) return;
      setState(() {
        _locationServiceEnabled = serviceEnabled;
        _locationGranted = granted;
      });
      if (granted && serviceEnabled) {
        _fetchUserLocation();
      }
    } catch (_) {}
  }

  // Naya function add karo _HomeTabState mein:
  Future<void> _loadUserArea() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('users')
          .select('area')
          .eq('id', userId)
          .maybeSingle();
      final area = data?['area'] as String?;
      if (area != null && area.trim().isNotEmpty && mounted) {
        setState(() => _userArea = area.trim());
      }
    } catch (_) {}
  }

  Future<void> _fetchUserLocation() async {
    // ✅ User ne manually address select kiya hai — GPS se overwrite mat karo
    if (_manualLocationActive) return;
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _HomeCache.userLat = position.latitude;
        _HomeCache.userLng = position.longitude;
        _updateVendorDistances();
        _updateUserAreaFromGPS(position.latitude, position.longitude);
      }
    } catch (_) {}
  }

  Future<void> _updateUserAreaFromGPS(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;

      final place = placemarks.first;

      // Locality ya subLocality — jo bhi available ho
      final locality = place.locality ?? '';
      final subLocality = place.subLocality ?? '';
      final area = subLocality.isNotEmpty ? subLocality : locality;

      if (area.isEmpty) return;

      // UI update karo
      if (mounted) setState(() => _userArea = area);

      // Supabase mein bhi save karo
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('users').update({'area': area}).eq('id', userId);
    } catch (_) {}
  }

  void _updateVendorDistances() {
    final userLat = _HomeCache.userLat;
    final userLng = _HomeCache.userLng;
    if (userLat == null || userLng == null) return;

    final updatedVendors = (_HomeCache.allVendors ?? []).map((v) {
      final distMeters = _locationService.distanceBetween(
        userLat,
        userLng,
        v.latitude,
        v.longitude,
      );
      v.distanceKm = distMeters / 1000;
      return v;
    }).toList();

    updatedVendors.sort((a, b) {
      final da = a.distanceKm ?? 999.0;
      final db = b.distanceKm ?? 999.0;
      return da.compareTo(db);
    });

    _HomeCache.allVendors = updatedVendors;
    for (final v in updatedVendors) {
      _vendorCache[v.id] = v;
    }

    if (mounted) setState(() => _allVendors = updatedVendors);
  }

  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocationRequestSheet(
        onAllow: () async {
          Navigator.pop(context);
          await _handleLocationRequest();
        },
        onSkip: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _handleLocationRequest() async {
    try {
      final ls = LocationService();
      final serviceEnabled = await ls.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await ls.openLocationSettings();
        return;
      }

      final permanentlyDenied = await ls.isPermanentlyDenied();
      if (permanentlyDenied) {
        await ls.openAppSettings();
        return;
      }

      final granted = await ls.requestPermission();
      if (!mounted) return;
      setState(() => _locationGranted = granted);

      if (granted) {
        _fetchUserLocation();
        _checkDeliveryZone();
      }
    } catch (_) {}
  }

  void _scheduleLoginPrompt() {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    if (isLoggedIn) return;

    _loginPromptTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      final stillLoggedOut = Supabase.instance.client.auth.currentUser == null;
      if (!stillLoggedOut) return;
      _showLoginPrompt();
    });
  }

  void _showLoginPrompt() {
    if (!mounted) return;
    if (_loginPromptStopped) {
      return; // ✅ NEW — user login screen pe ja chuka hai
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _LoginPromptDialog(
        onLoginTap: () {
          // ✅ NEW — login button dabate hi future reminders band
          _loginPromptStopped = true;
          _loginPromptTimer?.cancel();
        },
      ),
    ).then((_) {
      // Dialog close hone ke baad — 10 sec mein dobara
      if (!mounted) return;
      if (_loginPromptStopped) return; // ✅ NEW
      final stillLoggedOut = Supabase.instance.client.auth.currentUser == null;
      if (!stillLoggedOut) return;
      _loginPromptTimer?.cancel();
      _loginPromptTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        if (_loginPromptStopped) return; // ✅ NEW
        if (Supabase.instance.client.auth.currentUser == null) {
          _showLoginPrompt();
        }
      });
    });
  }

  Future<void> _loadAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _HomeCache.banners != null) {
      _applyCache();
      return;
    }
    await Future.wait([
      _loadBanners(),
      _loadCategories(),
      _loadRecommended(),
      _loadVendors(),
      _loadRecommendedRestaurants(),
      _loadTiming(),
      _loadMenuItemsGrouped(),
      _loadUserArea(),
      _loadHomeCombos(), // ✅ NEW
      _loadHomeOffers(), // ✅ NEW OFFERS
    ]);
    _HomeCache.lastFetched = DateTime.now();
    if (mounted) _checkAndShowPopup();
  }

  void _syncVendorModelShiftTimes(Map<String, dynamic>? data) {
    if (data == null) return;
    try {
      final slotsRaw = data['time_slots'];
      if (slotsRaw == null || (slotsRaw as List).isEmpty) return;
      final enabledSlots = (slotsRaw)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .where((s) => s['enabled'] == true)
          .toList();

      if (enabledSlots.length == 1) {
        // ✅ Single global slot — morning aur evening dono isi se set honge
        final s = enabledSlots.first;
        final openHour =
            int.tryParse((s['open'] as String? ?? '').split(':')[0]) ?? 0;
        final closeHour =
            int.tryParse((s['close'] as String? ?? '').split(':')[0]) ?? 0;
        VendorModel.morningStartHour = openHour;
        VendorModel.morningEndHour = closeHour;
        VendorModel.eveningStartHour = openHour;
        VendorModel.eveningEndHour = closeHour;
        return;
      }

      // Multiple slots — purani classification (hour < 14 = morning)
      for (final slot in enabledSlots) {
        final open = slot['open'] as String? ?? '';
        final close = slot['close'] as String? ?? '';
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
    } catch (_) {}
  }

  void _applyCache() {
    if (!mounted) return;
    setState(() {
      _banners = _HomeCache.banners ?? _kFallbackBanners;
      _bannerColor = _banners.isNotEmpty ? _banners[0].themeColor : _LC.accent;
      _loadingBanners = false;
      _categories = _HomeCache.categories ?? [];
      _loadingCats = false;
      _recommendedItems = _HomeCache.recommendedItems ?? [];
      _loadingRec = false;
      _allVendors = _HomeCache.allVendors ?? [];
      _recommendedRestaurants = _HomeCache.recommendedRestaurants ?? [];
      _loadingRecRest = false;
      _isAppActive = _HomeCache.isAppActive ?? true;
      _openTime = _HomeCache.openTime;
      _closeTime = _HomeCache.closeTime;
      _isInDeliveryZone = _HomeCache.isInDeliveryZone;
      _homeCombos = _HomeCache.homeCombos ?? []; // ✅ NEW
      _loadingCombos = false; // ✅ NEW
      _homeOffers = _HomeCache.homeOffers ?? []; // ✅ NEW OFFERS
      _loadingOffers = false; // ✅ NEW OFFERS
    });
    _startAutoplay();
    _checkAndShowPopup();
  }

  Future<void> _loadBanners() async {
    try {
      final rows = await _supabase
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      final list = (rows as List).map((r) => _BannerData.fromMap(r)).toList();
      _HomeCache.banners = list.isEmpty ? _kFallbackBanners : list;
    } catch (_) {
      _HomeCache.banners = _kFallbackBanners;
    }
    if (!mounted) return;
    setState(() {
      _banners = _HomeCache.banners!;
      _bannerColor = _banners[0].themeColor;
      _loadingBanners = false;
    });
    _startAutoplay();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _supabase
          .from('vendors')
          .select('category')
          .eq('city', 'Haldwani');

      final Set<String> catSet = {};
      for (final row in (rows as List)) {
        (row['category'] as String? ?? '')
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .forEach(catSet.add);
      }

      Map<String, String?> catImages = {};
      Set<String> homeOnCategories = {};

      try {
        final imgRows = await _supabase
            .from('food_categories')
            .select('name, image_url, is_show_on_home');

        for (final r in (imgRows as List)) {
          final name = r['name'] as String? ?? '';
          catImages[name] = r['image_url'] as String?;
          final showOnHome = r['is_show_on_home'] as bool? ?? true;
          if (showOnHome) homeOnCategories.add(name);
        }
      } catch (_) {}

      // sort_order ke hisaab se sort karo
      final catImagesList = catImages.entries.toList();

      // food_categories se sort_order fetch karo
      Map<String, int> sortOrders = {};
      try {
        final sortRows = await _supabase
            .from('food_categories')
            .select('name, sort_order')
            .order('sort_order', ascending: true);
        for (final r in (sortRows as List)) {
          sortOrders[r['name'] as String] = (r['sort_order'] as int?) ?? 999;
        }
      } catch (_) {}

      final sorted = catSet.toList()
        ..sort((a, b) {
          final orderA = sortOrders[a] ?? 999;
          final orderB = sortOrders[b] ?? 999;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return a.compareTo(b); // same order pe alphabetically
        });

      final filteredSorted = sorted.where((c) {
        if (!catImages.containsKey(c)) return true;
        return homeOnCategories.contains(c);
      }).toList();

      _HomeCache.categories = [
        {'name': 'All', 'emoji': '✦', 'image_url': catImages['All']},
        ...filteredSorted.map(
          (c) => {'name': c, 'emoji': _catEmoji(c), 'image_url': catImages[c]},
        ),
      ];
    } catch (_) {
      _HomeCache.categories = [
        {'name': 'All', 'emoji': '✦', 'image_url': null},
        {'name': 'Momos', 'emoji': '🥟', 'image_url': null},
        {'name': 'Burger', 'emoji': '🍔', 'image_url': null},
        {'name': 'Chowmein', 'emoji': '🍜', 'image_url': null},
        {'name': 'Pizza', 'emoji': '🍕', 'image_url': null},
        {'name': 'Chaat', 'emoji': '🍛', 'image_url': null},
        {'name': 'Maggi', 'emoji': '🍝', 'image_url': null},
        {'name': 'Sandwich', 'emoji': '🥪', 'image_url': null},
        {'name': 'Shake', 'emoji': '🥤', 'image_url': null},
      ];
    }
    if (!mounted) return;
    setState(() {
      _categories = _HomeCache.categories!;
      _loadingCats = false;
    });
  }

  Future<void> _loadRecommended() async {
    try {
      final items = await MenuService().getRecommendedItems();
      _HomeCache.recommendedItems = items;
    } catch (_) {
      _HomeCache.recommendedItems = [];
    }
    if (!mounted) return;
    setState(() {
      _recommendedItems = _HomeCache.recommendedItems!;
      _loadingRec = false;
    });
  }

  Future<void> _loadVendors() async {
    try {
      final vendors = await _vendorService.getVendors();
      final userLat = _HomeCache.userLat;
      final userLng = _HomeCache.userLng;
      if (userLat != null && userLng != null) {
        for (final v in vendors) {
          if (v.distanceKm == null) {
            final distMeters = _locationService.distanceBetween(
              userLat,
              userLng,
              v.latitude,
              v.longitude,
            );
            v.distanceKm = distMeters / 1000;
          }
        }
      }
      vendors.sort((a, b) {
        final da = a.distanceKm ?? 999.0;
        final db = b.distanceKm ?? 999.0;
        return da.compareTo(db);
      });
      _HomeCache.allVendors = vendors;
      for (final v in vendors) {
        _vendorCache[v.id] = v;
      }
    } catch (_) {
      _HomeCache.allVendors = [];
    }
    if (!mounted) return;
    setState(() => _allVendors = _HomeCache.allVendors!);
  }

  Future<void> _loadRecommendedRestaurants() async {
    try {
      // NAYA — day_off filter add kiya
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final data = await _supabase
          .from('vendors')
          .select()
          .eq('is_recommended_home', true)
          .eq('is_active', true)
          .eq('city', 'Haldwani')
          .or('day_off_date.is.null,day_off_date.neq.$today')
          .order('created_at', ascending: false)
          .limit(6);
      _HomeCache.recommendedRestaurants = (data as List)
          .map((e) => VendorModel.fromMap(e))
          .toList();
    } catch (_) {
      _HomeCache.recommendedRestaurants = [];
    }
    if (!mounted) return;
    setState(() {
      _recommendedRestaurants = _HomeCache.recommendedRestaurants!;
      _loadingRecRest = false;
    });
  }

  Future<void> _loadHomeCombos() async {
    try {
      final combos = await ComboService().getHomeCombos();
      _HomeCache.homeCombos = combos;
      if (!mounted) return;
      setState(() {
        _homeCombos = combos;
        _loadingCombos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCombos = false);
    }
  }

  Future<void> _loadHomeOffers() async {
    try {
      final offers = await OfferService().getHomeOffers();
      _HomeCache.homeOffers = offers;
      if (!mounted) return;
      setState(() {
        _homeOffers = offers;
        _loadingOffers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOffers = false);
    }
  }

  Future<void> _loadMenuItemsGrouped() async {
    try {
      final grouped = await MenuService().fetchAllMenuItemsGrouped();
      if (mounted) setState(() => _menuItemsGrouped = grouped);
    } catch (_) {}
  }

  Future<void> _loadTiming() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('is_timing_enabled, open_time, close_time, time_slots')
          .limit(1)
          .maybeSingle();
      if (data == null) {
        _HomeCache.isAppActive = true;
        _HomeCache.isTimingEnabled = true;
      } else {
        final timingEnabled = data['is_timing_enabled'] as bool? ?? true;
        _HomeCache.isTimingEnabled = timingEnabled;
        if (!timingEnabled) {
          _HomeCache.isAppActive = true;
          _HomeCache.openTime = data['open_time'] as String? ?? '17:00';
          _HomeCache.closeTime = data['close_time'] as String? ?? '21:00';
          _HomeCache.nextOpenTime = _HomeCache.openTime;
        } else {
          _syncVendorModelShiftTimes(data); // ✅ VendorModel hours set honge
          _HomeCache.isAppActive = await OrderService().isAppOpen();
          _HomeCache.nextOpenTime = await OrderService().getNextOpenTime();
          // ✅ openTime/closeTime ab sirf reference ke liye — _checkTiming use nahi karega
          _HomeCache.openTime = data['open_time'] as String? ?? '17:00';
          _HomeCache.closeTime = data['close_time'] as String? ?? '21:00';
        }
      }
    } catch (_) {
      _HomeCache.isAppActive = true;
      _HomeCache.isTimingEnabled = true;
    }
    if (!mounted) return;
    setState(() {
      _isAppActive = _HomeCache.isAppActive ?? true;
      _openTime =
          _HomeCache.nextOpenTime; // ✅ closed banner ke liye next open time
      _closeTime = _HomeCache.closeTime;
    });
    if (mounted) await context.read<CartProvider>().reloadSettings();
    _checkDeliveryZone();
  }

  Future<void> _checkDeliveryZone() async {
    if (_checkingZone) return;
    setState(() => _checkingZone = true);
    try {
      final inZone = await _locationService.isWithinDeliveryZone();
      _HomeCache.isInDeliveryZone = inZone;
      if (!mounted) return;
      setState(() {
        _isInDeliveryZone = inZone;
        _checkingZone = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInDeliveryZone = true;
          _checkingZone = false;
        });
      }
    }
  }

  bool _isWithinTime(String open, String close) {
    try {
      final now = TimeOfDay.now();
      final op = open.split(':');
      final cl = close.split(':');
      final openMin = int.parse(op[0]) * 60 + int.parse(op[1]);
      final closeMin = int.parse(cl[0]) * 60 + int.parse(cl[1]);
      final nowMin = now.hour * 60 + now.minute;
      return nowMin >= openMin && nowMin < closeMin;
    } catch (_) {
      return true;
    }
  }

  void _checkTiming() {
    if (!_HomeCache.isTimingEnabled) return;
    // ✅ KEY FIX: OrderService directly call karo
    // Ye dono slots check karta hai — 10:00-13:00 AND 17:00-21:00
    // Pehle ka code sirf "17:00" se compare karta tha — isliye morning mein false aata tha
    OrderService().isAppOpen().then((active) {
      if (!mounted) return;
      if (active != (_HomeCache.isAppActive ?? true)) {
        _HomeCache.isAppActive = active;
        // Next open time bhi update karo
        OrderService().getNextOpenTime().then((t) {
          if (!mounted) return;
          _HomeCache.nextOpenTime = t;
          setState(() {
            _isAppActive = active;
            _openTime = t;
          });
        });
        context.read<CartProvider>().reloadSettings();
      } else if (mounted) {
        setState(() => _isAppActive = active);
      }
    });
  }

  // NAYA — bounce autoplay (1→2→3→4→3→2→1→2...)
  bool _bannerForward = true;

  void _startAutoplay() {
    _bannerTimer?.cancel();
    if (_banners.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerCtrl.hasClients) return;

      int nextPage;
      if (_bannerForward) {
        if (_activePage >= _banners.length - 1) {
          _bannerForward = false;
          nextPage = _activePage - 1;
        } else {
          nextPage = _activePage + 1;
        }
      } else {
        if (_activePage <= 0) {
          _bannerForward = true;
          nextPage = _activePage + 1;
        } else {
          nextPage = _activePage - 1;
        }
      }

      _bannerCtrl.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  String _catEmoji(String cat) {
    const map = {
      'All': '🍽️',
      'Momos': '🥟',
      'Burger': '🍔',
      'Chowmein': '🍜',
      'Pizza': '🍕',
      'Chaat': '🍛',
      'Maggi': '🍝',
      'Sandwich': '🥪',
      'Shake': '🥤',
      'Samosa': '🥘',
      'Noodles': '🍜',
      'Rolls': '🌯',
    };
    return map[cat] ?? '🍴';
  }

  Future<void> _checkAndShowPopup() async {
    // Popup removed
  }

  void _showBannerPopup({
    required String title,
    required String subtitle,
    required String buttonText,
  }) {
    // Popup removed
  }

  Future<void> _onCategoryTap(String catName) async {
    HapticFeedback.selectionClick();
    if (catName == 'All') {
      setState(() {
        _selectedCategory = 'All';
        _filteredItems = [];
      });
      return;
    }
    setState(() {
      _selectedCategory = catName;
      _loadingFiltered = true;
      _filteredItems = [];
    });
    try {
      final data = await _supabase
          .from('menu_items')
          .select('*, vendors!inner(city, is_active)')
          .eq('category', catName)
          .eq('is_available', true)
          .eq('vendors.city', 'Haldwani')
          .eq('vendors.is_active', true)
          .order('created_at', ascending: false);

      final items = (data as List)
          .map((e) => MenuItemModel.fromMap(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _filteredItems = items;
        _loadingFiltered = false;
      });
    } catch (e) {
      try {
        final allItems = await MenuService().getAllMenuItems();
        final filtered = allItems
            .where(
              (item) => item.category.toLowerCase() == catName.toLowerCase(),
            )
            .toList();
        if (!mounted) return;
        setState(() {
          _filteredItems = filtered;
          _loadingFiltered = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _loadingFiltered = false);
      }
    }
  }

  Future<void> _openLocationSheet() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<PickedLocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSelectionScreen(
          currentLat: _HomeCache.userLat,
          currentLng: _HomeCache.userLng,
        ),
      ),
    );
    if (result == null || !mounted) return;

    _manualLocationActive =
        true; // ✅ ab GPS auto-refresh isse overwrite nahi karega
    _HomeCache.userLat = result.lat;
    _HomeCache.userLng = result.lng;

    // Header mein short label dikhao — full address ka pehla part
    final shortLabel = result.address.split(',').first.trim();
    setState(
      () => _userArea = shortLabel.isNotEmpty ? shortLabel : result.address,
    );

    _updateVendorDistances();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('users')
            .update({
              'area': _userArea,
              'last_lat': result.lat,
              'last_lng': result.lng,
            })
            .eq('id', userId);
      }
    } catch (_) {}

    _checkDeliveryZone();
  }

  void _onSearchTap() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => SearchScreen(
          vendors: _allVendors.where((v) => v.isStreetFood).toList(),
          restaurants: const [],
          sweetVendors: _allVendors
              .where((v) => v.businessType == 'sweets')
              .toList(),
          vendorMenuItems: _menuItemsGrouped,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _onVendorTap(VendorModel v) async {
    HapticFeedback.lightImpact();
    // Distance ke hisaab se delivery charge set karo
    if (v.distanceKm != null && v.distanceKm! > 0) {
      context.read<CartProvider>().setDeliveryChargeForDistance(v.distanceKm!);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: v)),
    );
  }

  Future<VendorModel?> _getVendorWithDistance(String vendorId) async {
    if (_vendorCache.containsKey(vendorId) &&
        _vendorCache[vendorId]!.distanceKm != null) {
      return _vendorCache[vendorId];
    }
    final vendor = await _vendorService.getVendorById(vendorId);
    if (vendor == null) return null;
    final userLat = _HomeCache.userLat;
    final userLng = _HomeCache.userLng;
    if (userLat != null && userLng != null) {
      final distMeters = _locationService.distanceBetween(
        userLat,
        userLng,
        vendor.latitude,
        vendor.longitude,
      );
      vendor.distanceKm = distMeters / 1000;
    }
    _vendorCache[vendorId] = vendor;
    return vendor;
  }

  Future<void> _onRecommendedTap(MenuItemModel item) async {
    HapticFeedback.lightImpact();
    try {
      final vendor = await _getVendorWithDistance(item.vendorId);
      if (!mounted || vendor == null) return;

      final userLat = _HomeCache.userLat;
      final userLng = _HomeCache.userLng;

      if (userLat != null && userLng != null && vendor.distanceKm == null) {
        final distMeters = _locationService.distanceBetween(
          userLat,
          userLng,
          vendor.latitude,
          vendor.longitude,
        );
        vendor.distanceKm = distMeters / 1000;
      }

      if (vendor.distanceKm != null && vendor.distanceKm! > 0) {
        context.read<CartProvider>().setDeliveryChargeForDistance(
          vendor.distanceKm!,
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuItemDetailScreen(item: item, vendor: vendor),
        ),
      );
    } catch (_) {}
  }

  Future<void> _onFilteredItemTap(MenuItemModel item) async {
    HapticFeedback.lightImpact();
    try {
      final vendor = await _getVendorWithDistance(item.vendorId);
      if (!mounted || vendor == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuItemDetailScreen(item: item, vendor: vendor),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final streetFoodVendors =
        _allVendors.where((v) => v.isStreetFood && v.rating != null).toList()
          ..sort((a, b) {
            final ratingDiff = (b.rating ?? 0).compareTo(a.rating ?? 0);
            if (ratingDiff != 0) return ratingDiff;
            return (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999);
          });

    final showFiltered = _selectedCategory != 'All';

    return RefreshIndicator(
      onRefresh: () async {
        _HomeCache.invalidate();
        setState(() {
          _selectedCategory = 'All';
          _filteredItems = [];
          _popupShown = false;
          _loadingCombos = true; // ✅ NEW
          _homeCombos = []; // ✅ NEW
          _loadingOffers = true; // ✅ NEW OFFERS
          _homeOffers = []; // ✅ NEW OFFERS
        });
        await _loadAll(forceRefresh: true);
        _fetchUserLocation();
      },
      color: _LC.accent,
      displacement: 80,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              topPad: _topPad,
              bannerColor: _bannerColor,
              banners: _banners,
              loadingBanners: _loadingBanners,
              activePage: _activePage,
              bannerCtrl: _bannerCtrl,
              isAppActive: _isAppActive,
              headerTotalH: _headerTotalH,
              onPageChanged: (i) => setState(() {
                final idx = i % _banners.length;
                _activePage = idx; // ← idx store karo, i nahi!
                if (!_banners[idx].isImageBanner) {
                  _bannerColor = _banners[idx].themeColor;
                }
              }),
              onBannerTap: (b) {
                if (b.actionRoute == 'street_food') widget.onSwitchTab(1);
                if (b.actionRoute == 'restaurants') widget.onSwitchTab(2);
              },
              onProfileTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              userArea: _userArea,
              onLocationTap: _openLocationSheet,
              onSearchTap: _onSearchTap,
            ),
          ),
          SliverToBoxAdapter(
            child: _CategoryChips(
              categories: _categories,
              loading: _loadingCats,
              selectedCategory: _selectedCategory,
              onCatTap: _onCategoryTap,
            ),
          ),
          if (!showFiltered) SliverToBoxAdapter(child: _QuickFiltersRow()),
          if (_locationGranted == true && !_isInDeliveryZone)
            SliverToBoxAdapter(child: const _OutOfZoneWidget()),
          if (_isInDeliveryZone && !_isAppActive)
            SliverToBoxAdapter(child: _HomeClosedTimer(openTime: _openTime)),
          if (_isInDeliveryZone && _isAppActive && showFiltered)
            SliverToBoxAdapter(
              child: _CategoryFilterSection(
                category: _selectedCategory,
                items: _filteredItems,
                loading: _loadingFiltered,
                onItemTap: _onFilteredItemTap,
                onClear: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCategory = 'All';
                    _filteredItems = [];
                  });
                },
                catEmoji: _catEmoji(_selectedCategory),
              ),
            ),
          if (_isInDeliveryZone && _isAppActive && !showFiltered) ...[
            // ✅ Offers section — sirf tab show ho jab admin se enabled offers hon
            if (_homeOffers.isNotEmpty)
              SliverToBoxAdapter(
                child: _OffersHomeSection(offers: _homeOffers),
              ),
            // ✅ Combos section — sirf tab show ho jab combos available hon
            if (_homeCombos.isNotEmpty)
              SliverToBoxAdapter(
                child: _CombosHomeSection(
                  combos: _homeCombos,
                  onViewAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CombosListScreen()),
                  ),
                  onComboTap: (combo) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ComboDetailScreen(combo: combo),
                    ),
                  ),
                ),
              ),
            if (_loadingRec || _recommendedItems.isNotEmpty)
              SliverToBoxAdapter(
                child: _RecommendedItemsSection(
                  items: _recommendedItems,
                  loading: _loadingRec,
                  onItemTap: _onRecommendedTap,
                ),
              ),
            SliverToBoxAdapter(
              child: _SecHeader(
                title: 'Nearby Stalls 🏪',
                subtitle: 'Best vendors closest to you',
                onViewAll: () => widget.onSwitchTab(1),
              ),
            ),
            SliverToBoxAdapter(
              child: _TopVendorsFeed(
                vendors: streetFoodVendors.take(5).toList(),
                onTap: _onVendorTap,
                onViewAll: () => widget.onSwitchTab(1),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Location Sheets — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _LocationRequestSheet extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  const _LocationRequestSheet({required this.onAllow, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EB),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text('📍', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Share Your Location 📍',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'To show nearby vendors,\nwe need your location.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontFamily: 'Poppins',
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _benefitRow('⚡', 'Nearest vendors shown first'),
          const SizedBox(height: 10),
          _benefitRow('🚀', 'Accurate delivery time estimates'),
          const SizedBox(height: 10),
          _benefitRow('🛡️', 'Only trusted vendors in your area'),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onAllow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Allow Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onSkip,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Not now, maybe later',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(String emoji, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF3D3D3D),
              fontSize: 13,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationInfoSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFFF6B35),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'Currently delivering in Haldwani only',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF6B7280),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _tile(
            Icons.my_location_rounded,
            'Use Current Location',
            'Tap to detect your location',
            const Color(0xFFFF6B35),
            () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _tile(
            Icons.location_city_rounded,
            'Haldwani',
            'Currently active — delivering now',
            const Color(0xFF16A34A),
            () => Navigator.pop(context),
            isActive: true,
          ),
          const SizedBox(height: 10),
          _tile(
            Icons.access_time_rounded,
            'Rudrapur',
            'Coming soon!',
            const Color(0xFF6B7280),
            null,
            isComingSoon: true,
          ),
          const SizedBox(height: 6),
          _tile(
            Icons.access_time_rounded,
            'Nainital',
            'Coming soon!',
            const Color(0xFF6B7280),
            null,
            isComingSoon: true,
          ),
          const SizedBox(height: 6),
          _tile(
            Icons.access_time_rounded,
            'Ramnagar',
            'Coming soon!',
            const Color(0xFF6B7280),
            null,
            isComingSoon: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback? onTap, {
    bool isActive = false,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF16A34A).withOpacity(0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFF16A34A).withOpacity(0.3)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isComingSoon
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF1A1A1A),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 18,
              ),
            if (isComingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B7280).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Popup Dialog — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _BannerPopupDialog extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onDonate;

  const _BannerPopupDialog({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onDonate,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 200,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B2B), Color(0xFFFFD700)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: const Center(
                          child: Text('🐾', style: TextStyle(fontSize: 64)),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 200,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B2B), Color(0xFFFFAA00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: const Center(
                          child: Text('🐶', style: TextStyle(fontSize: 72)),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF6B2B), Color(0xFFFFAA00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: const Center(
                      child: Text('🐶', style: TextStyle(fontSize: 72)),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _LC.textPrimary,
                      fontFamily: 'Poppins',
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _LC.textSecondary,
                      fontFamily: 'Poppins',
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onDonate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _LC.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Maybe later',
                      style: TextStyle(
                        color: _LC.textMuted,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════
// Category Filter — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _CategoryFilterSection extends StatelessWidget {
  final String category;
  final List<MenuItemModel> items;
  final bool loading;
  final void Function(MenuItemModel) onItemTap;
  final VoidCallback onClear;
  final String catEmoji;

  const _CategoryFilterSection({
    required this.category,
    required this.items,
    required this.loading,
    required this.onItemTap,
    required this.onClear,
    required this.catEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _LC.accentLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _LC.accentBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(catEmoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: const TextStyle(
                        color: _LC.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!loading)
                Text(
                  '${items.length} items',
                  style: const TextStyle(
                    color: _LC.textMuted,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _LC.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _LC.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 14, color: _LC.textMuted),
                      SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: _LC.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(
                4,
                (_) => Shimmer.fromColors(
                  baseColor: const Color(0xFFEAE8E4),
                  highlightColor: const Color(0xFFF7F5F2),
                  child: Container(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!loading && items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
            child: Center(
              child: Column(
                children: [
                  Text(catEmoji, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    '$category is not available right now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _LC.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No vendors found for this category.\nCheck back soon! 🙏',
                    style: TextStyle(
                      fontSize: 13,
                      color: _LC.textMuted,
                      fontFamily: 'Poppins',
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        if (!loading && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: items
                  .map(
                    (item) => _FilteredItemCard(
                      item: item,
                      onTap: () => onItemTap(item),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _FilteredItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onTap;
  const _FilteredItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _LC.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(13),
              ),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _imgPh(),
                    )
                  : _imgPh(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _LC.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _LC.textMuted,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${item.appPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _LC.accent,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _LC.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Order Now',
                            style: TextStyle(
                              color: _LC.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _imgPh() => Container(
    width: 90,
    height: 90,
    color: const Color(0xFFF0EDE8),
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 28))),
  );
}

// ═══════════════════════════════════════════════════════════
// Out of Zone — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _OutOfZoneWidget extends StatelessWidget {
  const _OutOfZoneWidget();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _LC.border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _LC.accentLight,
                shape: BoxShape.circle,
                border: Border.all(color: _LC.accentBorder, width: 2),
              ),
              child: const Center(
                child: Text('📍', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Coming Soon to Your Area!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _LC.textPrimary,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Streat Eats is currently available only in Haldwani and nearby areas.\nWe are expanding soon!',
              style: TextStyle(
                fontSize: 13,
                color: _LC.textMuted,
                fontFamily: 'Poppins',
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _LC.accentLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _LC.accentBorder),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_city_rounded,
                        color: _LC.accent,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Currently Serving',
                        style: TextStyle(
                          color: _LC.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Haldwani & nearby areas\n(within 15 km radius)',
                    style: TextStyle(
                      color: _LC.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Active order shortcut — visible even when app is closed
            _ActiveOrderShortcut(),
            const SizedBox(height: 12),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _LC.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _LC.border),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📱', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stay updated — follow us',
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
                          fontSize: 13,
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

// ═══════════════════════════════════════════════════════════
// Pinned Header — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPad;
  final Color bannerColor;
  final List<_BannerData> banners;
  final bool loadingBanners;
  final int activePage;
  final PageController bannerCtrl;
  final bool isAppActive;
  final double headerTotalH;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_BannerData> onBannerTap;
  final VoidCallback onProfileTap;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final String userArea;

  static const double _locationH = 52.0;
  static const double _searchH = 50.0;
  static const double _bannerH = 200.0;

  const _PinnedHeaderDelegate({
    required this.topPad,
    required this.bannerColor,
    required this.banners,
    required this.loadingBanners,
    required this.activePage,
    required this.bannerCtrl,
    required this.isAppActive,
    required this.headerTotalH,
    required this.onPageChanged,
    required this.onBannerTap,
    required this.onProfileTap,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.userArea,
  });

  @override
  double get minExtent => topPad + _locationH + _searchH;
  @override
  double get maxExtent => headerTotalH;

  @override
  bool shouldRebuild(_PinnedHeaderDelegate old) =>
      old.bannerColor != bannerColor ||
      old.activePage != activePage ||
      old.loadingBanners != loadingBanners ||
      old.isAppActive != isAppActive ||
      old.banners.length != banners.length ||
      old.userArea != userArea;

  bool get _currentIsImage =>
      banners.isNotEmpty && banners[activePage % banners.length].isImageBanner;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final shrinkFactor = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );
    final bannerOpacity = (1.0 - shrinkFactor * 1.5).clamp(0.0, 1.0);

    return SizedBox(
      height: maxExtent,
      child: Stack(
        children: [
          Positioned.fill(
            child: _currentIsImage
                ? Container(color: const Color(0xFFFF6B35))
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bannerColor,
                          bannerColor.withOpacity(0.85),
                          bannerColor.withOpacity(0.40),
                          _LC.background.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.30, 0.65, 1.0],
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: topPad + _locationH + _searchH,
            left: 0,
            right: 0,
            height: _bannerH + 24,
            child: Opacity(
              opacity: bannerOpacity,
              child: loadingBanners
                  ? const SizedBox.shrink()
                  : PageView.builder(
                      controller: bannerCtrl,
                      onPageChanged: onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      itemCount:
                          banners.length, // ← SAHI (constructor param hai)
                      itemBuilder: (_, i) {
                        final b = banners[i % banners.length];
                        return GestureDetector(
                          onTap: () => onBannerTap(b),
                          child: b.isImageBanner
                              ? _ImageBannerSlide(banner: b)
                              : _TextBannerSlide(banner: b),
                        );
                      },
                    ),
            ),
          ),
          if (!_currentIsImage)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Opacity(
                opacity: bannerOpacity,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, _LC.background],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(height: topPad),
                SizedBox(
                  height: _locationH,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: onLocationTap,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                userArea,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Open/Closed badge — rightmost
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                            ),
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
                                isAppActive ? 'Open Now' : 'Closed',
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
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: GestureDetector(
                    onTap: onSearchTap,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.search_rounded,
                            color: _LC.textMuted.withOpacity(0.7),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Search for dishes, restaurants...',
                              style: TextStyle(
                                color: _LC.textMuted,
                                fontSize: 13,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          Icon(
                            Icons.mic_rounded,
                            color: _LC.accent.withOpacity(0.6),
                            size: 17,
                          ),
                          const SizedBox(width: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!loadingBanners && banners.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: bannerOpacity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(banners.length, (i) {
                    final active = i == activePage % banners.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageBannerSlide extends StatelessWidget {
  final _BannerData banner;
  const _ImageBannerSlide({required this.banner});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: banner.imageUrl!,
    width: double.infinity,
    height: double.infinity,
    fit: BoxFit.cover,
    placeholder: (_, __) => Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: CircularProgressIndicator(color: _LC.accent, strokeWidth: 2),
      ),
    ),
    errorWidget: (_, __, ___) => Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 40,
        ),
      ),
    ),
  );
}

class _TextBannerSlide extends StatelessWidget {
  final _BannerData banner;
  const _TextBannerSlide({required this.banner});

  @override
  Widget build(BuildContext context) {
    final hasEmojiImg = banner.emojiImageUrl?.isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (banner.subtitle.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      banner.subtitle.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  banner.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (banner.actionRoute != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Order Now',
                          style: TextStyle(
                            color: banner.themeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: banner.themeColor,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          hasEmojiImg
              ? CachedNetworkImage(
                  imageUrl: banner.emojiImageUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => Text(
                    banner.emoji ?? '🥟',
                    style: const TextStyle(fontSize: 64),
                  ),
                )
              : Text(
                  banner.emoji ?? '🥟',
                  style: const TextStyle(fontSize: 72),
                ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Category Chips — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _CategoryChips extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final bool loading;
  final String selectedCategory;
  final void Function(String) onCatTap;
  const _CategoryChips({
    required this.categories,
    required this.loading,
    required this.selectedCategory,
    required this.onCatTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 6,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: const Color(0xFFEAE8E4),
            highlightColor: const Color(0xFFF7F5F2),
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final name = cat['name'] as String? ?? '';
          final emoji = cat['emoji'] as String? ?? '🍽️';
          final imgUrl = cat['image_url'] as String?;
          final isSelected = name == selectedCategory;
          return GestureDetector(
            onTap: () => onCatTap(name),
            child: Container(
              width: 68,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: isSelected ? _LC.accentLight : _LC.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _LC.accent : _LC.border,
                        width: isSelected ? 2.5 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _LC.accent.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
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
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 28),
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
                          ? FontWeight.w800
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
    );
  }
}

class _QuickFiltersRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      physics: const BouncingScrollPhysics(),
      itemCount: _kQuickFilters.length,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _LC.border),
          color: _LC.surface,
        ),
        child: Center(
          child: Text(
            _kQuickFilters[i],
            style: const TextStyle(
              color: _LC.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// ✅ CHANGE 1: _RecommendedItemsSection — NEW DESIGN
// Featured big card (pehla item) + small horizontal cards (baaki items)
// Sab data database se hi aata hai — kuch hardcode nahi
// ═══════════════════════════════════════════════════════════
class _RecommendedItemsSection extends StatelessWidget {
  final List<MenuItemModel> items;
  final bool loading;
  final void Function(MenuItemModel) onItemTap;

  const _RecommendedItemsSection({
    required this.items,
    required this.loading,
    required this.onItemTap,
  });

  // Gradient backgrounds for small cards — index based, no hardcode
  static const List<List<Color>> _gradients = [
    [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
    [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
    [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
    [Color(0xFFFFF1F2), Color(0xFFFECDD3)],
    [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: _LC.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended For You ✨',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _LC.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hand-picked by our team',
                      style: TextStyle(
                        fontSize: 12,
                        color: _LC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _LC.accentLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _LC.accentBorder),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: _LC.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading shimmer
        if (loading) ...[
          // Featured shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFEAE8E4),
              highlightColor: const Color(0xFFF7F5F2),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Small cards shimmer
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              itemCount: 4,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: const Color(0xFFEAE8E4),
                highlightColor: const Color(0xFFF7F5F2),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],

        // Loaded content
        if (!loading && items.isNotEmpty) ...[
          // ── FEATURED CARD (pehla item — database se) ──
          GestureDetector(
            onTap: () => onItemTap(items[0]),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              decoration: BoxDecoration(
                color: _LC.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _LC.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image / Gradient banner
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                    child: Stack(
                      children: [
                        // Image or gradient fallback
                        items[0].imageUrl != null &&
                                items[0].imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: items[0].imageUrl!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorWidget: (_, __, ___) =>
                                    _featuredGradientPh(items[0].category),
                              )
                            : _featuredGradientPh(items[0].category),
                        // Top-left: BESTSELLER badge
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _LC.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '⭐ BESTSELLER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                        // Top-right: Rating (from database if available)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: _LC.gold,
                                  size: 11,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '4.9',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bottom: Vendor name overlay (from database via vendorId)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.55),
                                ],
                              ),
                            ),
                            child: Text(
                              items[0].vendorName.isNotEmpty
                                  ? '${items[0].vendorName} · ${items[0].category}'
                                  : items[0].category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[0].name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _LC.textPrimary,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (items[0].description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  items[0].description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _LC.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${items[0].appPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _LC.accent,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _LC.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 20,
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

          // ── SMALL CARDS ROW (baaki items — database se) ──
          if (items.length > 1)
            SizedBox(
              height: 175,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length - 1,
                itemBuilder: (_, i) {
                  final item = items[i + 1];
                  final gradColors = _gradients[i % _gradients.length];
                  final hasImage =
                      item.imageUrl != null && item.imageUrl!.isNotEmpty;

                  // Badge based on index
                  String? badge;
                  Color? badgeColor;
                  if (i == 0) {
                    badge = '🔥 HOT';
                    badgeColor = _LC.gold;
                  } else if (i == 1) {
                    badge = 'NEW';
                    badgeColor = _LC.green;
                  } else if (i == 2) {
                    badge = 'TOP';
                    badgeColor = _LC.blue;
                  }

                  return GestureDetector(
                    onTap: () => onItemTap(item),
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _LC.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _LC.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image or gradient
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(13),
                            ),
                            child: Stack(
                              children: [
                                hasImage
                                    ? CachedNetworkImage(
                                        imageUrl: item.imageUrl!,
                                        height: 80,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                        errorWidget: (_, __, ___) => Container(
                                          height: 80,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: gradColors,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _catEmoji(item.category),
                                              style: const TextStyle(
                                                fontSize: 36,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 80,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: gradColors,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _catEmoji(item.category),
                                            style: const TextStyle(
                                              fontSize: 36,
                                            ),
                                          ),
                                        ),
                                      ),
                                if (badge != null)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        badge,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Body
                          Padding(
                            padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _LC.textPrimary,
                                    fontFamily: 'Poppins',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.vendorName.isNotEmpty
                                      ? item.vendorName
                                      : item.category,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: _LC.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    Text(
                                      '₹${item.appPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _LC.accent,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _LC.accent,
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 14,
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
                },
              ),
            ),
        ],

        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          height: 1,
          color: _LC.border,
        ),
      ],
    );
  }

  // Gradient placeholder for featured card — based on category name
  Widget _featuredGradientPh(String category) {
    const gradMap = {
      'Momos': [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
      'Burger': [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
      'Chowmein': [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
      'Pizza': [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
      'Chaat': [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
      'Shake': [Color(0xFFFFF1F2), Color(0xFFFECDD3)],
    };
    final colors =
        gradMap[category] ?? [const Color(0xFFFFF1EB), const Color(0xFFFFD4BC)];
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(_catEmoji(category), style: const TextStyle(fontSize: 64)),
      ),
    );
  }

  String _catEmoji(String cat) {
    const map = {
      'Momos': '🥟',
      'Burger': '🍔',
      'Chowmein': '🍜',
      'Pizza': '🍕',
      'Chaat': '🍛',
      'Maggi': '🍝',
      'Sandwich': '🥪',
      'Shake': '🥤',
      'Samosa': '🥘',
    };
    return map[cat] ?? '🍴';
  }
}

// ═══════════════════════════════════════════════════════════
// ✅ CHANGE 2: _RecommendedRestaurantsSection — VERTICAL LIST
// Horizontal scroll hata ke vertical list card style laga diya
// Data same — database se, kuch hardcode nahi
// ═══════════════════════════════════════════════════════════
class _RecommendedRestaurantsSection extends StatelessWidget {
  final List<VendorModel> restaurants;
  final bool loading;
  final void Function(VendorModel) onTap;
  final VoidCallback onViewAll;

  const _RecommendedRestaurantsSection({
    required this.restaurants,
    required this.loading,
    required this.onTap,
    required this.onViewAll,
  });

  // Gradient bands for left color strip — index based
  static const List<List<Color>> _bandGradients = [
    [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
    [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
    [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
    [Color(0xFFFFF1F2), Color(0xFFFECDD3)],
    [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: _LC.blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Restaurants 🍽️',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _LC.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Top picks from our partners',
                      style: TextStyle(
                        fontSize: 12,
                        color: _LC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _LC.blueLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _LC.blue.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: _LC.blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading shimmer — vertical
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: List.generate(
                3,
                (_) => Shimmer.fromColors(
                  baseColor: const Color(0xFFEAE8E4),
                  highlightColor: const Color(0xFFF7F5F2),
                  child: Container(
                    height: 90,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Vertical list cards — VendorCard style (same as street food)
        if (!loading)
          ...restaurants.map(
            (r) => VendorCard(vendor: r, onTap: () => onTap(r), layout: 'list'),
          ),

        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          height: 1,
          color: _LC.border,
        ),
      ],
    );
  }

  String _vendorEmoji(String cat) {
    const map = {
      'Momos': '🥟',
      'Burger': '🍔',
      'Chowmein': '🍜',
      'Pizza': '🍕',
      'Chaat': '🍛',
      'Maggi': '🍝',
      'Sandwich': '🥪',
      'Shake': '🥤',
      'North Indian': '🍱',
      'Punjabi': '🍛',
      'Chinese': '🥢',
      'South Indian': '🥘',
    };
    return map[cat] ?? '🍽️';
  }
}

// ═══════════════════════════════════════════════════════════
// Closed Timer — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _HomeClosedTimer extends StatefulWidget {
  final String openTime;
  const _HomeClosedTimer({required this.openTime});
  @override
  State<_HomeClosedTimer> createState() => _HomeClosedTimerState();
}

class _HomeClosedTimerState extends State<_HomeClosedTimer> {
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
    final openH = int.tryParse(parts[0]) ?? 17;
    final openM = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    var nextOpen = DateTime(now.year, now.month, now.day, openH, openM);
    // Only add a day if this specific slot time has already fully passed today
    // AND it's not within the next 5 minutes (to avoid flicker at boundaries)
    if (nextOpen.isBefore(now)) {
      nextOpen = nextOpen.add(const Duration(days: 1));
    }
    _timeUntilOpen = nextOpen.difference(now);
    if (_timeUntilOpen.isNegative) {
      _timeUntilOpen = Duration.zero;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _two(_timeUntilOpen.inHours);
    final m = _two(_timeUntilOpen.inMinutes.remainder(60));
    final s = _two(_timeUntilOpen.inSeconds.remainder(60));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
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
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We Are Closed',
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
                        'Follow us on Instagram',
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
  Widget build(BuildContext context) => Column(
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

class _TimerDivider extends StatelessWidget {
  const _TimerDivider();
  @override
  Widget build(BuildContext context) => const Padding(
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

class _ActiveOrderShortcut extends StatefulWidget {
  const _ActiveOrderShortcut();

  @override
  State<_ActiveOrderShortcut> createState() => _ActiveOrderShortcutState();
}

class _ActiveOrderShortcutState extends State<_ActiveOrderShortcut> {
  bool _hasActiveOrder = false;
  String? _activeOrderId;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkActiveOrder();
  }

  Future<void> _checkActiveOrder() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _checked = true);
        return;
      }
      final data = await Supabase.instance.client
          .from('orders')
          .select('id, status')
          .eq('user_id', userId)
          .inFilter('status', [
            'placed',
            'preparing',
            'picked_up',
            'on_the_way',
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _hasActiveOrder = data != null;
          _activeOrderId = data?['id'] as String?;
          _checked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_hasActiveOrder || _activeOrderId == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderStatusScreen(orderId: _activeOrderId!),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _LC.accentLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _LC.accentBorder, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛵', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have an active order!',
                  style: TextStyle(
                    color: _LC.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  'Tap to track your order',
                  style: TextStyle(
                    color: _LC.textSecondary,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: _LC.accent, size: 14),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SecHeader — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _SecHeader extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback onViewAll;
  const _SecHeader({
    required this.title,
    required this.subtitle,
    required this.onViewAll,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _LC.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _LC.accentLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _LC.accentBorder),
            ),
            child: const Text(
              'View All',
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
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// Exclusive Row — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _ExclusiveRow extends StatelessWidget {
  final List<VendorModel> vendors;
  final void Function(VendorModel) onTap;
  final VoidCallback onViewAll;
  const _ExclusiveRow({
    required this.vendors,
    required this.onTap,
    required this.onViewAll,
  });

  // Per-vendor colored gradient backgrounds — index based
  static const List<List<Color>> _circleGrads = [
    [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
    [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
    [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
    [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
    [Color(0xFFFFF1F2), Color(0xFFFECDD3)],
    [Color(0xFFF5F3FF), Color(0xFFDDD6FE)],
    [Color(0xFFFEFCE8), Color(0xFFFEF08A)],
    [Color(0xFFECFEFF), Color(0xFFA5F3FC)],
  ];

  static const List<Color> _circleBorders = [
    Color(0xFFFFD4BC),
    Color(0xFFBFDBFE),
    Color(0xFFBBF7D0),
    Color(0xFFFED7AA),
    Color(0xFFFECDD3),
    Color(0xFFDDD6FE),
    Color(0xFFFEF08A),
    Color(0xFFA5F3FC),
  ];

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: 5,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: const Color(0xFFEAE8E4),
            highlightColor: const Color(0xFFF7F5F2),
            child: Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        physics: const BouncingScrollPhysics(),
        itemCount: vendors.length + 1,
        itemBuilder: (_, i) {
          if (i == vendors.length) {
            return GestureDetector(
              onTap: onViewAll,
              child: Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _LC.accentLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _LC.accentBorder, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: _LC.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'See All',
                      style: TextStyle(
                        color: _LC.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final v = vendors[i];
          final gradColors = _circleGrads[i % _circleGrads.length];
          final borderColor = _circleBorders[i % _circleBorders.length];

          return GestureDetector(
            onTap: () => onTap(v),
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Colored gradient box with image or emoji
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradColors,
                            ),
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: v.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: v.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(
                                    child: Text(
                                      '🥟',
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _vendorEmoji(v.category),
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                        ),
                      ),
                      // Rating badge — bottom right
                      if (v.rating != null)
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _LC.gold,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _LC.background,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              v.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    v.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _LC.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _vendorEmoji(String cat) {
    const map = {
      'Momos': '🥟',
      'Burger': '🍔',
      'Chowmein': '🍜',
      'Pizza': '🍕',
      'Chaat': '🍛',
      'Maggi': '🍝',
      'Sandwich': '🥪',
      'Shake': '🥤',
    };
    return map[cat] ?? '🥟';
  }
}

// ═══════════════════════════════════════════════════════════
// Street Food Circles — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _StreetFoodCircles extends StatelessWidget {
  final void Function(String) onTap;
  final VoidCallback onViewAll;
  final List<Map<String, dynamic>> categories;
  const _StreetFoodCircles({
    required this.onTap,
    required this.onViewAll,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final items = categories.where((c) => c['name'] != 'All').toList();
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length + 1,
        itemBuilder: (_, i) {
          if (i == items.length) {
            return GestureDetector(
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _LC.accentLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: _LC.accentBorder, width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: _LC.accent,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'More',
                      style: TextStyle(
                        color: _LC.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final cat = items[i];
          final name = cat['name'] as String? ?? '';
          final emoji = cat['emoji'] as String? ?? '🍴';
          final imgUrl = cat['image_url'] as String?;
          return GestureDetector(
            onTap: () => onTap(name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _LC.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _LC.border, width: 1.5),
                    ),
                    child: ClipOval(
                      child: imgUrl != null && imgUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
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
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      color: _LC.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Restaurant Promo — IDENTICAL to v22.0
// ═══════════════════════════════════════════════════════════
class _RestaurantPromo extends StatelessWidget {
  final VoidCallback onTap;
  const _RestaurantPromo({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NOW ON Streat Eats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Local Restaurants\nAt Lower Prices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Same food, ₹50–100 cheaper than\nZomato & Swiggy',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore Restaurants',
                        style: TextStyle(
                          color: _LC.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _LC.blue,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('🍽️', style: TextStyle(fontSize: 52)),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// ✅ CHANGE 5: _VendorCard — New banner-top design
// Top image banner (full width, 110px) with category tag + open/closed badge
// Item chips row from vendor category
// Bottom: delivery + min order + Order Now button
// Data from database — VendorModel fields use kiye
// ═══════════════════════════════════════════════════════════
class _TopVendorsFeed extends StatelessWidget {
  final List<VendorModel> vendors;
  final void Function(VendorModel) onTap;
  final VoidCallback onViewAll;
  const _TopVendorsFeed({
    required this.vendors,
    required this.onTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return GestureDetector(
        onTap: onViewAll,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _LC.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _LC.border),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🏪', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Text(
                'Browse all street food vendors →',
                style: TextStyle(
                  color: _LC.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ...vendors.map(
          (v) => VendorCard(vendor: v, onTap: () => onTap(v), layout: 'list'),
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _LC.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _LC.accentBorder),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View All Street Food Vendors',
                  style: TextStyle(
                    color: _LC.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: _LC.accent, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// _ExclusiveVendorsList — "Only on Streat Eats" vendors
// Recommended restaurants wali vertical list style
// ═══════════════════════════════════════════════════════
class _ExclusiveVendorsList extends StatelessWidget {
  final List<VendorModel> vendors;
  final void Function(VendorModel) onTap;
  final VoidCallback onViewAll;

  const _ExclusiveVendorsList({
    required this.vendors,
    required this.onTap,
    required this.onViewAll,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
    [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
    [Color(0xFFF0FDF4), Color(0xFFBBF7D0)],
    [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
    [Color(0xFFFFF1F2), Color(0xFFFECDD3)],
    [Color(0xFFF5F3FF), Color(0xFFDDD6FE)],
  ];

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...vendors
            .take(5)
            .toList()
            .map(
              (v) =>
                  VendorCard(vendor: v, onTap: () => onTap(v), layout: 'list'),
            ),
        GestureDetector(
          onTap: onViewAll,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _LC.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _LC.accentBorder),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View All Street Food Vendors',
                  style: TextStyle(
                    color: _LC.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: _LC.accent, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Sweets Preview Section — Home screen pe
// ═══════════════════════════════════════════════════════════
class _SweetsSection extends StatefulWidget {
  final VoidCallback onViewAll;
  const _SweetsSection({required this.onViewAll});

  @override
  State<_SweetsSection> createState() => _SweetsSectionState();
}

class _SweetsSectionState extends State<_SweetsSection> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('sweets')
          .select()
          .eq('is_available', true)
          .order('sort_order')
          .limit(6);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mithai & Sweets 🍬',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _LC.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fresh mithai, ghar pe delivered',
                      style: TextStyle(
                        fontSize: 12,
                        color: _LC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onViewAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_loading)
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: 4,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: const Color(0xFFEAE8E4),
                highlightColor: const Color(0xFFF7F5F2),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        if (!_loading && _items.isNotEmpty)
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              physics: const BouncingScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                final hasImg =
                    (item['image_url'] as String?)?.isNotEmpty == true;
                final name = item['name'] as String? ?? '';
                final price = item['price'] as int? ?? 0;

                return GestureDetector(
                  onTap: widget.onViewAll,
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _LC.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(13),
                          ),
                          child: hasImg
                              ? CachedNetworkImage(
                                  imageUrl: item['image_url']!,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _ph(),
                                )
                              : _ph(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _LC.textPrimary,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  Text(
                                    '₹$price',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFD97706),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _LC.accent,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 14,
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
              },
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          height: 1,
          color: _LC.border,
        ),
      ],
    );
  }

  Widget _ph() => Container(
    height: 90,
    color: const Color(0xFFFFF1EB),
    child: const Center(child: Text('🍬', style: TextStyle(fontSize: 32))),
  );
}

// ═══════════════════════════════════════════════════════════
// Offers Home Section — HTML "Today's Offers" ocard design
// ═══════════════════════════════════════════════════════════
class _OffersHomeSection extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  const _OffersHomeSection({required this.offers});

  Color _hex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            '🏷️ Today\'s Offers',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _LC.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            physics: const BouncingScrollPhysics(),
            itemCount: offers.length,
            itemBuilder: (_, i) {
              final o = offers[i];
              final c1 = _hex(
                o['bg_color_1'] as String?,
                const Color(0xFFE8F5E9),
              );
              final c2 = _hex(
                o['bg_color_2'] as String?,
                const Color(0xFFC8E6C9),
              );
              final textColor = _hex(
                o['text_color'] as String?,
                const Color(0xFF1B5E20),
              );
              final title = (o['title'] as String?)?.trim().isNotEmpty == true
                  ? o['title'] as String
                  : (o['description'] as String? ?? 'Offer');
              final code = o['coupon_code'] as String? ?? '';
              final emoji = (o['emoji'] as String?)?.trim().isNotEmpty == true
                  ? o['emoji'] as String
                  : '🏷️';

              return Container(
                width: 132,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c1, c2],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        fontFamily: 'Poppins',
                        height: 1.15,
                      ),
                    ),
                    const Spacer(),
                    if (code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Combos Home Section
// ═══════════════════════════════════════════════════════════
class _CombosHomeSection extends StatelessWidget {
  final List<ComboModel> combos;
  final VoidCallback onViewAll;
  final void Function(ComboModel) onComboTap;

  const _CombosHomeSection({
    required this.combos,
    required this.onViewAll,
    required this.onComboTap,
  });

  @override
  Widget build(BuildContext context) {
    if (combos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special Combos 🎁',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _LC.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Best value bundles for you',
                      style: TextStyle(
                        fontSize: 12,
                        color: _LC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            physics: const BouncingScrollPhysics(),
            itemCount: combos.length,
            itemBuilder: (_, i) {
              final combo = combos[i];
              final hasImage =
                  combo.imageUrl != null && combo.imageUrl!.isNotEmpty;
              final hasDiscount =
                  combo.isDiscounted && combo.discountPercent > 0;

              return GestureDetector(
                onTap: () => onComboTap(combo),
                child: Container(
                  width: 155,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: _LC.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _LC.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(13),
                        ),
                        child: Stack(
                          children: [
                            hasImage
                                ? CachedNetworkImage(
                                    imageUrl: combo.imageUrl!,
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _comboPh(),
                                  )
                                : _comboPh(),
                            if (hasDiscount)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _LC.red,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _LC.red.withOpacity(0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '₹${(combo.originalPrice! - combo.appPrice).toStringAsFixed(0)} OFF',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Info
                      Padding(
                        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              combo.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _LC.textPrimary,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (combo.itemsIncluded.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                combo.itemsIncluded,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: _LC.textMuted,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 7),
                            if (hasDiscount) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '₹${combo.originalPrice!.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _LC.textMuted,
                                      fontFamily: 'Poppins',
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '₹${combo.appPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _LC.accent,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                            ],
                            Row(
                              children: [
                                if (hasDiscount)
                                  Expanded(
                                    child: Text(
                                      'Save ₹${(combo.originalPrice! - combo.appPrice).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _LC.green,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '₹${combo.appPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _LC.accent,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                if (!hasDiscount) const Spacer(),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: _LC.accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 15,
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
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          height: 1,
          color: _LC.border,
        ),
      ],
    );
  }

  Widget _comboPh() => Container(
    height: 100,
    width: double.infinity,
    color: const Color(0xFFFFF1EB),
    child: const Center(child: Text('🎁', style: TextStyle(fontSize: 36))),
  );
}

// ═══════════════════════════════════════════════════════════
// Login Prompt Dialog
// ═══════════════════════════════════════════════════════════
class _LoginPromptDialog extends StatelessWidget {
  final VoidCallback? onLoginTap;
  const _LoginPromptDialog({this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top accent bar
            Container(
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B35),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  // Icon
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EB),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF6B35).withOpacity(0.25),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text('👋', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  const Text(
                    'Login to Order Food',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  const Text(
                    'Create a free account to order your\nfavorite street food at your door.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontFamily: 'Poppins',
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        onLoginTap?.call(); // ✅ NEW — flag set + timer cancel
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Login / Sign Up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dismiss
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Maybe later',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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

class _ProfileAvatar extends StatefulWidget {
  final VoidCallback onTap;
  const _ProfileAvatar({required this.onTap});

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('users')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      final url = data?['avatar_url'] as String?;
      if (url != null && url.trim().isNotEmpty && mounted) {
        setState(() => _avatarUrl = url.trim());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        ),
        child: ClipOval(
          child: _avatarUrl != null
              ? CachedNetworkImage(
                  imageUrl: _avatarUrl!,
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _defaultIcon(),
                )
              : _defaultIcon(),
        ),
      ),
    );
  }

  Widget _defaultIcon() => Container(
    color: Colors.white.withOpacity(0.20),
    child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
  );
}
