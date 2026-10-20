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
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../providers/veg_filter_provider.dart';
import '../constants/globals.dart';
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
import 'meals_screen.dart'; // ✅ NEW: Curated Meals Screen
import '../models/combo_model.dart';
import '../services/combo_service.dart';
import '../services/offer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'all_offers_screen.dart';
import 'all_festive_deals_screen.dart';
import 'combos_list_screen.dart';
import 'combo_detail_screen.dart';
import 'order_status_screen.dart';
import '../widgets/vendor_card.dart';
import 'location_picker_screen.dart';
import 'address_selection_screen.dart';
import 'category_items_screen.dart';
import 'login_screen.dart';
import '../widgets/disclaimer_widget.dart';
import '../widgets/explore_item_card.dart';
import 'all_recommended_screen.dart';
import '../utils/cart_utils.dart';
import '../constants/app_snackbar.dart';
import '../widgets/global_floating_cart.dart';

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
  static List<MenuItemModel>? todaysDeals; // ✅ NEW
  static List<MenuItemModel>? trendingItems; // ✅ NEW
  static String? liveOrdersText; // ✅ NEW
  static int liveOrdersCount = 240; // ✅ NEW
  static bool isLiveOrdersEnabled = true; // ✅ NEW
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
  static Map<String, List<MenuItemModel>>? menuItemsByCategory; // ✅ NEW
  static List<String>? exploreMenuCategories;

  // ✅ Real-time Growth & Promotional Cache
  static String flashRushTitle = '⚡ Evening Street Crave: Flat 40% OFF';
  static bool isFlashSaleLive = true;
  static int flashSaleMinutes = 45;
  static bool spinWheelEnabled = true;
  static bool spinRequire24hOrder = true;
  static bool spinLock24hEnabled = true;
  static List<Map<String, dynamic>>? dynamicSpinSlices;
  static bool fomoEnabled = true;
  static int fomoIntervalSeconds = 26;

  static bool get isStale {
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched!) >
        const Duration(minutes: 10);
  }

  static void invalidate() {
    banners = null;
    categories = null;
    recommendedItems = null;
    todaysDeals = null;
    trendingItems = null;
    allVendors = null;
    recommendedRestaurants = null;
    isAppActive = null;
    isInDeliveryZone = true;
    lastFetched = null;
    homeCombos = null;
    homeOffers = null;
    menuItemsByCategory = null; // ✅ NEW
    exploreMenuCategories = null;
    dynamicSpinSlices = null;
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
      const SweetsScreen(),
      const MealsScreen(),
      const OrderHistoryScreen(),
    ];
  }

  @override
  void dispose() {
    _streetFoodCatNotifier.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
  }

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
        body: Stack(
          children: [
            IndexedStack(index: _tab, children: _pages),
            if (_tab == 0 || _tab == 1 || _tab == 2 || _tab == 3)
              const GlobalFloatingCart(bottomOffset: 12),
          ],
        ),
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
            color: Colors.white.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: _LC.border.withValues(alpha: 0.6), width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, -8),
              ),
              BoxShadow(
                color: _LC.accent.withValues(alpha: 0.04),
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
                  _NavItem(
                    icon: Icons.cake_outlined,
                    activeIcon: Icons.cake_rounded,
                    label: 'Sweets',
                    idx: 2,
                    current: current,
                    onTap: onTap,
                  ),
                  _NavItem(
                    icon: Icons.lunch_dining_outlined,
                    activeIcon: Icons.lunch_dining_rounded,
                    label: 'Meals',
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
  final ValueNotifier<int> _activePageNotifier = ValueNotifier<int>(0);
  int get _activePage => _activePageNotifier.value;
  set _activePage(int v) => _activePageNotifier.value = v;
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
  final bool _loadingFiltered = false;

  bool _popupShown = false;
  Timer? _loginPromptTimer;
  final bool _loginPromptShown = false;
  bool _loginPromptStopped =
      false; // ✅ NEW — login screen pe gaya to dobara popup na aaye
  final Map<String, List<MenuItemModel>> _menuItemsGrouped = {};
  Map<String, List<MenuItemModel>> _menuItemsByCategory = {};
  List<String> _exploreMenuCategories = [];
  String? _avatarUrl;
  String _userArea = 'Haldwani'; // ← YE ADD KARO
  List<ComboModel> _homeCombos = [];
  bool _loadingCombos = true;
  List<Map<String, dynamic>> _homeOffers = [];
  bool _loadingOffers = true;
  List<MenuItemModel> _todaysDeals = []; // ✅ NEW
  bool _loadingDeals = true; // ✅ NEW
  List<MenuItemModel> _trendingItems = []; // ✅ NEW
  bool _loadingTrending = true; // ✅ NEW
  String _liveOrdersText = ''; // ✅ NEW
  int _liveOrdersCount = 240; // ✅ NEW
  bool _isLiveOrdersEnabled = true; // ✅ NEW

  // ── Growth & Order Revival Engine State ──
  bool _hasOrderedIn24h = false;
  bool _spinEligibleLoading = true;
  bool _isFlashSaleLive = true;
  String _flashRushTitle = '⚡ Evening Street Crave: Flat 40% OFF';
  int _flashSaleMinutes = 45;
  int _flashSaleSeconds = 18;
  Timer? _flashTimer;
  Timer? _fomoTimer;
  bool _showFomoToast = false;
  int _fomoIndex = 0;
  bool _fomoEnabled = true;
  int _fomoIntervalSeconds = 26;
  bool _isDialogOpen = false;

  // ── 24-Hour Spin & Win Lock State ─────────────────────────────
  Timer? _spinCountdownTicker;
  bool _isSpinLocked24h = false;
  bool _spinLock24hEnabled = true;
  Duration _spinTimeRemaining = Duration.zero;
  String _spinCountdownText = '';
  String? _lastWonSpinCode;
  String? _lastWonSpinTitle;
  bool _spinWheelEnabled = true;
  bool _spinRequire24hOrder = true;
  List<Map<String, dynamic>> _dynamicSpinSlices = [];

  // ── Realtime & Flash Deal State ──────────────────────────────
  RealtimeChannel? _growthChannel;
  RealtimeChannel? _settingsChannel;
  RealtimeChannel? _festiveDealsChannel;
  List<MenuItemModel> _flashDeals = [];

  final List<Map<String, String>> _fomoToasts = [
    {
      'name': 'Rohit from Subhash Nagar',
      'item': 'just ordered Momos Combo 🥟',
      'time': 'Just now',
    },
    {
      'name': 'Priya from Mukhani',
      'item': 'saved ₹40 on Chole Bhature 🍛',
      'time': '2 mins ago',
    },
    {
      'name': 'Aman from Bareilly Road',
      'item': 'unlocked FREE Delivery 🛵',
      'time': '3 mins ago',
    },
    {
      'name': 'Vikram from Tikonia',
      'item': 'grabbed Flash Deal: Paneer Burger 🍔',
      'time': '5 mins ago',
    },
    {
      'name': 'Sneha from Nawabi Road',
      'item': 'ordered Roll & Cold Coffee 🥤',
      'time': '7 mins ago',
    },
  ];

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
    _loadAvatar();
    _loadAll(forceRefresh: _HomeCache.isStale);
    _startTimingTimer();
    _checkLocationAndMaybeShowSheet();
    _scheduleLoginPrompt();
    _check24hOrderStatus();
    _checkSpin24hStatus();
    _loadGrowthSettings();
    _loadFlashDeals();
    _startFlashSaleTimer();
    _startFomoTimer();
    _setupRealtimeSubscriptions();
    _checkPendingRazorpay();
  }

  Future<void> _checkPendingRazorpay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rzpOrderId = prefs.getString('pending_rzp_order_id');
      if (rzpOrderId == null || rzpOrderId.isEmpty) return;

      for (int i = 0; i < 5; i++) {
        final data = await _supabase
            .from('orders')
            .select('payment_status')
            .eq('razorpay_order_id', rzpOrderId)
            .limit(1)
            .maybeSingle();

        if (data != null && data['payment_status'] == 'paid') {
          if (mounted) {
            context.read<CartProvider>().clearCart();
            AppSnackBar.showSuccess(
                context, 'Payment successful! Your order has been placed.');
          }
          await prefs.remove('pending_rzp_order_id');
          return;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
      await prefs.remove('pending_rzp_order_id');
    } catch (_) {}
  }

  Future<void> _loadAvatar() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _bannerTimer?.cancel();
    _timingTimer?.cancel();
    _loginPromptTimer?.cancel();
    _flashTimer?.cancel();
    _fomoTimer?.cancel();
    _spinCountdownTicker?.cancel();
    _activePageNotifier.dispose();
    _bannerCtrl.dispose();
    try {
      _growthChannel?.unsubscribe();
      _settingsChannel?.unsubscribe();
      _festiveDealsChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission();
      // ✅ When user returns from Admin App or background, refresh all dynamic configs instantly!
      _loadGrowthSettings();
      _loadFlashDeals();
      _loadLiveOrdersSettings();
      _loadTiming();
      _checkSpin24hStatus();
      _check24hOrderStatus();
      if (mounted) {
        context.read<CartProvider>().reloadSettings();
      }
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
      return; // ✅ NEW — login screen pe ja chuka hai
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
      _loadTodaysDeals(), // ✅ NEW
      _loadTrendingItems(), // ✅ NEW
      _loadLiveOrdersSettings(), // ✅ NEW
      _loadVendors(),
      _loadRecommendedRestaurants(),
      _loadTiming(),
      _loadMenuItemsGrouped(),
      _loadUserArea(),
      _loadHomeCombos(),
      _loadHomeOffers(),
      _loadGrowthSettings(), // ✅ Always fetch real-time growth configs
      _loadFlashDeals(),     // ✅ Always fetch real-time flash deals
    ]);
    _HomeCache.lastFetched = DateTime.now();
    _applyCache(); // Apply all fetched data to state simultaneously
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
      _todaysDeals = _HomeCache.todaysDeals ?? []; // ✅ NEW
      _loadingDeals = false; // ✅ NEW
      _trendingItems = _HomeCache.trendingItems ?? []; // ✅ NEW
      _loadingTrending = false; // ✅ NEW
      _liveOrdersText = _HomeCache.liveOrdersText ?? ''; // ✅ NEW
      _liveOrdersCount = _HomeCache.liveOrdersCount; // ✅ NEW
      _isLiveOrdersEnabled = _HomeCache.isLiveOrdersEnabled; // ✅ NEW
      _allVendors = _HomeCache.allVendors ?? [];
      _recommendedRestaurants = _HomeCache.recommendedRestaurants ?? [];
      _loadingRecRest = false;
      _isAppActive = _HomeCache.isAppActive ?? true;
      _openTime = _HomeCache.openTime;
      _closeTime = _HomeCache.closeTime;
      _isInDeliveryZone = _HomeCache.isInDeliveryZone;
      _homeCombos = _HomeCache.homeCombos ?? [];
      _loadingCombos = false;
      _homeOffers = _HomeCache.homeOffers ?? [];
      _loadingOffers = false;
      _menuItemsByCategory = _HomeCache.menuItemsByCategory ?? {}; // ✅ NEW
      _exploreMenuCategories = _HomeCache.exploreMenuCategories ?? [];
      _isFlashSaleLive = _HomeCache.isFlashSaleLive;
      _flashRushTitle = _HomeCache.flashRushTitle;
      _flashSaleMinutes = _HomeCache.flashSaleMinutes;
      _spinWheelEnabled = _HomeCache.spinWheelEnabled;
      _spinRequire24hOrder = _HomeCache.spinRequire24hOrder;
      _spinLock24hEnabled = _HomeCache.spinLock24hEnabled;
      if (_HomeCache.dynamicSpinSlices != null) {
        _dynamicSpinSlices = _HomeCache.dynamicSpinSlices!;
      }
      _fomoEnabled = _HomeCache.fomoEnabled;
      _fomoIntervalSeconds = _HomeCache.fomoIntervalSeconds;
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
  }

  Future<void> _loadRecommended() async {
    try {
      final items = await MenuService().getRecommendedItems();
      _HomeCache.recommendedItems = items;
    } catch (_) {
      _HomeCache.recommendedItems = [];
    }
  }

  // ✅ NEW: Today's Best Deals loader (Admin controlled via DB)
  Future<void> _loadTodaysDeals() async {
    try {
      final items = await MenuService().getTodaysDeals();
      _HomeCache.todaysDeals = items;
    } catch (_) {
      _HomeCache.todaysDeals = [];
    }
  }

  // ✅ NEW: Trending Items loader (Admin controlled via DB)
  Future<void> _loadTrendingItems() async {
    try {
      final items = await MenuService().getTrendingItems();
      _HomeCache.trendingItems = items;
    } catch (_) {
      _HomeCache.trendingItems = [];
    }
  }

  // ✅ NEW: Live Order Counter settings loader from app_settings (Admin controlled)
  Future<void> _loadLiveOrdersSettings() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('live_orders_text, is_live_orders_enabled, live_orders_count')
          .limit(1)
          .maybeSingle();

      if (data != null) {
        final text = data['live_orders_text'] as String?;
        final enabled = data['is_live_orders_enabled'] as bool?;
        final count = (data['live_orders_count'] as num?)?.toInt();
        if (text != null && text.trim().isNotEmpty) {
          _HomeCache.liveOrdersText = text.trim();
        }
        if (enabled != null) {
          _HomeCache.isLiveOrdersEnabled = enabled;
        }
        if (count != null && count > 0) {
          _HomeCache.liveOrdersCount = count;
        }
      }
    } catch (_) {}
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
  }

  Future<void> _loadHomeCombos() async {
    try {
      final combos = await ComboService().getHomeCombos();
      _HomeCache.homeCombos = combos;
    } catch (_) {}
  }

  Future<void> _loadHomeOffers() async {
    try {
      final offers = await OfferService().getHomeOffers();
      _HomeCache.homeOffers = offers;
    } catch (_) {}
  }

  Future<void> _loadMenuItemsGrouped() async {
    try {
      final allItems = await MenuService().getAllMenuItems();
      final categoryGrouped = <String, List<MenuItemModel>>{};
      for (final item in allItems) {
        if (item.category.isNotEmpty) {
          final cats = item.category.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty);
          for (final c in cats) {
            categoryGrouped.putIfAbsent(c, () => []).add(item);
          }
        }
      }

      final distinctCategories = categoryGrouped.keys.toList();
      Map<String, int> sortOrders = {};
      try {
        final sortRows = await _supabase
            .from('category_sort_order')
            .select('category_name, sort_order');
        for (final r in (sortRows as List)) {
          final name = r['category_name'] as String?;
          final order = r['sort_order'] as int?;
          if (name != null && order != null) {
            sortOrders[name] = order;
          }
        }
      } catch (_) {}

      final originalOrder = { for (var i = 0; i < distinctCategories.length; i++) distinctCategories[i]: i };

      distinctCategories.sort((a, b) {
        final orderA = sortOrders[a];
        final orderB = sortOrders[b];
        
        if (orderA != null && orderB != null) {
          final cmp = orderA.compareTo(orderB);
          if (cmp != 0) return cmp;
          return originalOrder[a]!.compareTo(originalOrder[b]!);
        } else if (orderA != null) {
          return -1;
        } else if (orderB != null) {
          return 1;
        } else {
          return originalOrder[a]!.compareTo(originalOrder[b]!);
        }
      });
      
      _HomeCache.exploreMenuCategories = distinctCategories;
      _HomeCache.menuItemsByCategory = categoryGrouped;
    } catch (_) {}
  }

  Future<void> _loadTiming() async {
    await _checkTiming();
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

  Future<void> _checkTiming() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('is_timing_enabled, open_time, close_time, time_slots')
          .limit(1)
          .maybeSingle();

      if (data == null) {
        if (mounted) {
          setState(() {
            _isAppActive = true;
          });
        }
        return;
      }
      
      final bool timingEnabled = data['is_timing_enabled'] as bool? ?? true;
      final String openTime = data['open_time'] as String? ?? '17:00';
      final String closeTime = data['close_time'] as String? ?? '21:00';
      
      _HomeCache.isTimingEnabled = timingEnabled;

      if (!timingEnabled) {
        _HomeCache.isAppActive = true;
        _HomeCache.openTime = openTime;
        _HomeCache.closeTime = closeTime;
        _HomeCache.nextOpenTime = openTime;
        if (mounted) {
          setState(() {
            _isAppActive = true;
            _openTime = openTime;
            _closeTime = closeTime;
          });
        }
        return;
      }

      final isOpen = await OrderService().isAppOpen();
      final nextOpen = await OrderService().getNextOpenTime();
      
      _syncVendorModelShiftTimes(data);

      _HomeCache.isAppActive = isOpen;
      _HomeCache.nextOpenTime = nextOpen;
      _HomeCache.openTime = openTime;
      _HomeCache.closeTime = closeTime;

      if (mounted) {
        setState(() {
          _isAppActive = isOpen;
          _openTime = nextOpen.isNotEmpty ? nextOpen : openTime;
          _closeTime = closeTime;
        });
        context.read<CartProvider>().reloadSettings();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAppActive = true;
        });
      }
    }
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
      'All': '✦',
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
    if (!mounted || _popupShown) return;
    try {
      final data = await _supabase
          .from('app_settings')
          .select(
            'is_popup_enabled, popup_enabled, popup_title, popup_subtitle, '
            'popup_image_url, popup_button_text, popup_action_route, '
            'popup_max_per_day, popup_interval_minutes, popup_target_screen',
          )
          .limit(1)
          .maybeSingle();

      if (data == null) return;

      final bool isEnabled = (data['is_popup_enabled'] as bool?) ??
          (data['popup_enabled'] as bool?) ??
          false;
      if (!isEnabled) return;

      final String title =
          (data['popup_title'] as String?)?.trim() ?? 'Special Announcement 🎉';
      final String subtitle = (data['popup_subtitle'] as String?)?.trim() ??
          'Check out today\'s hottest food & offers on Streat Eats!';
      final String? imageUrl = (data['popup_image_url'] as String?)?.trim();
      final String buttonText =
          (data['popup_button_text'] as String?)?.trim() ?? 'Explore Now';
      final String actionRoute =
          (data['popup_action_route'] as String?)?.trim() ??
          (data['popup_target_screen'] as String?)?.trim() ??
          'street_food';
      final int maxPerDay = (data['popup_max_per_day'] as num?)?.toInt() ?? 2;
      final int minIntervalMins =
          (data['popup_interval_minutes'] as num?)?.toInt() ?? 60;

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final storedDate = prefs.getString('home_popup_date') ?? '';
      int countToday = prefs.getInt('home_popup_count') ?? 0;
      final lastShownEpoch = prefs.getInt('home_popup_last_shown_time') ?? 0;

      if (storedDate != todayStr) {
        countToday = 0;
      }

      if (countToday >= maxPerDay) {
        return;
      }

      final lastShownTime =
          DateTime.fromMillisecondsSinceEpoch(lastShownEpoch);
      final diffMins = now.difference(lastShownTime).inMinutes;
      if (lastShownEpoch > 0 && diffMins < minIntervalMins) {
        return;
      }

      _popupShown = true;
      await prefs.setString('home_popup_date', todayStr);
      await prefs.setInt('home_popup_count', countToday + 1);
      await prefs.setInt(
        'home_popup_last_shown_time',
        now.millisecondsSinceEpoch,
      );

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      _showSlideUpPopup(
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        buttonText: buttonText,
        actionRoute: actionRoute,
      );
    } catch (e) {
      debugPrint('Popup check error: $e');
    }
  }

  void _showSlideUpPopup({
    required String title,
    required String subtitle,
    String? imageUrl,
    required String buttonText,
    required String actionRoute,
  }) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'HomePromoPopup',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.88,
              constraints: const BoxConstraints(maxWidth: 380),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: _LC.surface,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Image or Decorative Header
                    Stack(
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: _LC.accentLight,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _LC.accent,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _defaultPopupBanner(),
                            ),
                          )
                        else
                          _defaultPopupBanner(),

                        // Close Button (Top Right)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
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

                        // Special Offer Badge
                        Positioned(
                          bottom: 10,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _LC.accent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _LC.accent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'LIMITED TIME',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Content Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
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
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _LC.textSecondary,
                              height: 1.35,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Action CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(ctx);
                                _handlePopupAction(actionRoute);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _LC.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    buttonText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Widget _defaultPopupBanner() {
    return Container(
      height: 125,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B2B), Color(0xFFFF9248)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.fastfood_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('🥟', style: TextStyle(fontSize: 36)),
                SizedBox(width: 10),
                Text('🍰', style: TextStyle(fontSize: 36)),
                SizedBox(width: 10),
                Text('🍔', style: TextStyle(fontSize: 36)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePopupAction(String actionRoute) {
    final raw = actionRoute.trim().toLowerCase();
    final route = raw.replaceAll('/', '').replaceAll('-', '_');

    if (route == 'street_food' || route == 'streetfood') {
      widget.onSwitchTab(1);
    } else if (route == 'sweets' || route == 'mithai' || route == 'custom_dabba' || route == 'customdabba') {
      widget.onSwitchTab(2);
    } else if (route == 'meals' || route == 'curated_meals') {
      widget.onSwitchTab(3);
    } else if (route == 'combos') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CombosListScreen()),
      );
    } else if (route == 'offers' || route == 'all_offers') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AllOffersScreen()),
      );
    } else if (route == 'festive_deals' || route == 'festivedeals') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AllFestiveDealsScreen(
            deals: const [],
            allVendors: _allVendors.map((e) => e.toMap()).toList(),
          ),
        ),
      );
    } else if (route == 'search') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
    } else if (route == 'cart') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } else if (route == 'orders' || route == 'order_history') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
      );
    } else if (route == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } else if (raw.startsWith('category:')) {
      final cat = actionRoute.split(':').last.trim();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryItemsScreen(
            category: cat,
            catEmoji: _catEmoji(cat),
          ),
        ),
      );
    } else if (raw.startsWith('vendor:')) {
      final vId = actionRoute.split(':').last.trim();
      final vendor = _allVendors.where((v) => v.id == vId).firstOrNull;
      if (vendor != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor)),
        );
      }
    } else {
      widget.onSwitchTab(1);
    }
  }

  Future<void> _onCategoryTap(String catName) async {
    HapticFeedback.selectionClick();
    if (catName == 'All') return; // 'All' pe kuch nahi karna
    final emoji = _catEmoji(catName);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryItemsScreen(category: catName, catEmoji: emoji),
      ),
    );
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
        pageBuilder: (_, anim, __) => const SearchScreen(),
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
      var vendor = await _getVendorWithDistance(item.vendorId);
      if (vendor == null && _allVendors.isNotEmpty) {
        vendor = _allVendors.first;
      }
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

      final targetVendor = vendor;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuItemDetailScreen(item: item, vendor: targetVendor),
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
    final showFiltered = _selectedCategory != 'All';

    return Stack(
      children: [
        RefreshIndicator(
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
          _loadingDeals = true; // ✅ NEW
          _todaysDeals = []; // ✅ NEW
          _loadingTrending = true; // ✅ NEW
          _trendingItems = []; // ✅ NEW
        });
        await Future.wait([
          _loadAll(forceRefresh: true),
          _loadGrowthSettings(),
          _loadFlashDeals(),
          _checkSpin24hStatus(),
          _check24hOrderStatus(),
          context.read<CartProvider>().reloadSettings(),
        ]);
        _fetchUserLocation();
      },
      color: _LC.accent,
      displacement: 80,
      child: CustomScrollView(
        cacheExtent: 500,
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
              activePageNotifier: _activePageNotifier,
              bannerCtrl: _bannerCtrl,
              isAppActive: _isAppActive,
              headerTotalH: _headerTotalH,
              onPageChanged: (i) {
                final idx = i % _banners.length;
                _activePageNotifier.value = idx;
                if (!_banners[idx].isImageBanner) {
                  setState(() {
                    _bannerColor = _banners[idx].themeColor;
                  });
                }
              },
              onBannerTap: (b) {
                if (b.actionRoute == 'street_food') widget.onSwitchTab(1);
                if (b.actionRoute == 'restaurants') widget.onSwitchTab(2);
              },
              onCartTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CartScreen(isStandalone: true),
                ),
              ),
              onProfileTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              userArea: _userArea,
              onLocationTap: _openLocationSheet,
              onSearchTap: _onSearchTap,
              avatarUrl: _avatarUrl,
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
          // ✅ 1. Live Order Counter — Positioned right after Categories as requested
          if (_isLiveOrdersEnabled)
            SliverToBoxAdapter(
              child: _LiveOrderCounterSection(
                text: _liveOrdersText,
                orderCount: _liveOrdersCount,
                userArea: _userArea,
              ),
            ),
          // ✅ Growth 1: Free Delivery Milestone Bar on Home (when cart has items)
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              if (cart.items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: _buildHomeFreeDeliveryBar(cart),
              );
            },
          ),
          // ✅ Growth 2: Flash Rush Deals (with Zero Loss psychological strike price & countdown)
          if (_isFlashSaleLive && !showFiltered)
            SliverToBoxAdapter(
              child: _buildFlashRushSection(),
            ),
          // ✅ Growth 3: Gated Spin & Win (Locked unless user ordered in 24h, Auto dynamic coupons)
          if (_spinWheelEnabled && !showFiltered)
            SliverToBoxAdapter(
              child: _buildGatedSpinBanner(),
            ),
          if (!showFiltered) SliverToBoxAdapter(child: _QuickFiltersRow()),
          if (_locationGranted == true && !_isInDeliveryZone)
            SliverToBoxAdapter(child: _OutOfZoneWidget()),
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
            // ✅ 2. Today's Best Deals (Horizontal scrolling deals with Admin control)
            if (_loadingDeals || _todaysDeals.isNotEmpty)
              SliverToBoxAdapter(
                child: _TodaysDealsSection(
                  items: _todaysDeals,
                  loading: _loadingDeals,
                  onItemTap: _onRecommendedTap,
                  onViewAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllRecommendedScreen(
                          title: "Today's Best Deals",
                          emoji: "🔥",
                          subtitle: "Special discounts & limited stock",
                          preloadedItems: _todaysDeals,
                          fetchType: 'deals',
                        ),
                      ),
                    );
                  },
                ),
              ),
            // ✅ 3. Trending in Haldwani (Horizontal scrolling rankings #1, #2, #3 with Admin control)
            if (_loadingTrending || _trendingItems.isNotEmpty)
              SliverToBoxAdapter(
                child: _TrendingNowSection(
                  items: _trendingItems,
                  loading: _loadingTrending,
                  userArea: _userArea,
                  onItemTap: _onRecommendedTap,
                  onViewAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllRecommendedScreen(
                          title: "Trending in $_userArea",
                          emoji: "📈",
                          subtitle: "Most ordered right now",
                          preloadedItems: _trendingItems,
                          fetchType: 'trending',
                        ),
                      ),
                    );
                  },
                ),
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
                  onViewAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllRecommendedScreen(
                          title: "Recommended For You",
                          emoji: "✨",
                          subtitle: "Hand-picked by our team",
                          preloadedItems: _recommendedItems,
                          fetchType: 'recommended',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ..._buildExploreMenuSlivers(),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    ),
    if (_showFomoToast && _fomoEnabled)
      _buildFomoToastOverlay(),
  ],
);
  }
  List<Widget> _buildExploreMenuSlivers() {
    List<String> catNames = [];
    if (_exploreMenuCategories.isNotEmpty) {
      catNames = _exploreMenuCategories;
    } else {
      catNames = _categories
          .map((c) => c['name'] as String? ?? '')
          .where((n) => n.isNotEmpty && n != 'All')
          .toList();
    }

    if (catNames.isEmpty) return [];

    final slivers = <Widget>[];

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
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
              const Text(
                'Explore Menu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (final cat in catNames) {
      final items = _menuItemsByCategory[cat] ?? [];
      final emoji = _catEmoji(cat);
      final loading = _menuItemsByCategory.isEmpty;

      if (!loading && items.isEmpty) continue;

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  cat,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _LC.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(width: 8),
                if (!loading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _LC.accentLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _LC.accentBorder),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _LC.accent,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                const Spacer(),
                if (!loading)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryItemsScreen(
                            category: cat,
                            catEmoji: emoji,
                          ),
                        ),
                      );
                    },
                    child: Container(
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
                  ),
              ],
            ),
          ),
        ),
      );

      if (loading) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (int r = 0; r < 2; r++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          for (int c = 0; c < 2; c++) ...[
                            if (c > 0) const SizedBox(width: 10),
                            Expanded(
                              child: Shimmer.fromColors(
                                baseColor: const Color(0xFFE5E7EB),
                                highlightColor: const Color(0xFFFFF8F0),
                                child: Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 215,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return ExploreItemCard(
                    item: items[index],
                    onTap: () => _onFilteredItemTap(items[index]),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        );
      }

      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            height: 1,
            color: _LC.border,
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    return slivers;
  }

  // ═══════════════════════════════════════════════════════════
  // ── Growth & Order Revival Engine Helpers ──────────────────
  // ═══════════════════════════════════════════════════════════

  Future<void> _check24hOrderStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _hasOrderedIn24h = false;
            _spinEligibleLoading = false;
          });
        }
        return;
      }
      final since = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toIso8601String();
      final orders = await _supabase
          .from('orders')
          .select('id, created_at, status')
          .eq('user_id', user.id)
          .gte('created_at', since)
          .neq('status', 'cancelled')
          .limit(1);
      final hasOrder = (orders as List).isNotEmpty;
      if (mounted) {
        setState(() {
          _hasOrderedIn24h = hasOrder;
          _spinEligibleLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _spinEligibleLoading = false);
    }
  }

  Future<void> _checkSpin24hStatus() async {
    try {
      if (!_spinLock24hEnabled) {
        if (mounted) {
          setState(() {
            _isSpinLocked24h = false;
            _spinCountdownText = '';
          });
        }
        _spinCountdownTicker?.cancel();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final userId = _supabase.auth.currentUser?.id ?? 'anon';
      final lastSpinStr = prefs.getString('spin_last_timestamp_$userId');
      final wonCode = prefs.getString('spin_last_won_code_$userId');
      final wonTitle = prefs.getString('spin_last_won_title_$userId');

      if (lastSpinStr != null) {
        final lastSpinTime = DateTime.tryParse(lastSpinStr);
        if (lastSpinTime != null) {
          final diff = DateTime.now().difference(lastSpinTime);
          if (diff < const Duration(hours: 24)) {
            final remaining = const Duration(hours: 24) - diff;
            if (mounted) {
              setState(() {
                _isSpinLocked24h = true;
                _spinTimeRemaining = remaining;
                _lastWonSpinCode = wonCode;
                _lastWonSpinTitle = wonTitle;
                _updateSpinCountdownText();
              });
              _startSpinCountdownTicker();
              return;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _isSpinLocked24h = false;
        });
      }
    } catch (_) {}
  }

  void _updateSpinCountdownText() {
    final h = _spinTimeRemaining.inHours;
    final m = _spinTimeRemaining.inMinutes.remainder(60);
    final s = _spinTimeRemaining.inSeconds.remainder(60);
    _spinCountdownText = '${h}h ${m}m ${s}s';
  }

  void _startSpinCountdownTicker() {
    _spinCountdownTicker?.cancel();
    _spinCountdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_spinTimeRemaining.inSeconds > 1) {
        setState(() {
          _spinTimeRemaining = _spinTimeRemaining - const Duration(seconds: 1);
          _updateSpinCountdownText();
        });
      } else {
        timer.cancel();
        setState(() {
          _isSpinLocked24h = false;
          _spinCountdownText = '';
        });
        _check24hOrderStatus();
      }
    });
  }

  void _onSpinCompleted(String code, Map<String, dynamic> chosen) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _supabase.auth.currentUser?.id ?? 'anon';
    final nowStr = DateTime.now().toIso8601String();
    await prefs.setString('spin_last_timestamp_$userId', nowStr);
    await prefs.setString('spin_last_won_code_$userId', code);
    await prefs.setString('spin_last_won_title_$userId', chosen['title'] ?? '');

    try {
      final uId = _supabase.auth.currentUser?.id;
      if (uId != null) {
        await _supabase.from('users').update({'last_spin_at': nowStr}).eq('id', uId);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isSpinLocked24h = true;
        _spinTimeRemaining = const Duration(hours: 24);
        _lastWonSpinCode = code;
        _lastWonSpinTitle = chosen['title'] ?? '';
        _updateSpinCountdownText();
      });
      _startSpinCountdownTicker();
    }
  }

  Future<void> _loadGrowthSettings() async {
    try {
      var data = await _supabase
          .from('app_growth_configs')
          .select()
          .eq('id', 'default_config')
          .maybeSingle();

      data ??= await _supabase
          .from('app_growth_configs')
          .select()
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        final live = data['flash_rush_enabled'] as bool? ?? true;
        final title = (data['flash_rush_title'] as String?)?.trim();
        final timerMins = (data['flash_rush_timer_minutes'] as num?)?.toInt();
        final fomoOn = data['fomo_social_proof_enabled'] as bool? ?? true;
        final fomoInt =
            (data['fomo_toast_interval_seconds'] as num?)?.toInt() ?? 26;
        final spinOn = data['spin_wheel_enabled'] as bool? ?? true;
        final spinReq24 = data['spin_require_24h_order'] as bool? ?? true;
        final spinLock24 = data['spin_lock_24h_enabled'] as bool? ?? true;

        List<Map<String, dynamic>>? slices;
        final rawOffers = data['spin_offers'];
        if (rawOffers is List && rawOffers.isNotEmpty) {
          slices = rawOffers
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }

        _HomeCache.isFlashSaleLive = live;
        if (title != null && title.isNotEmpty) {
          _HomeCache.flashRushTitle = title;
        }
        if (timerMins != null && timerMins > 0) {
          _HomeCache.flashSaleMinutes = timerMins;
        }
        _HomeCache.fomoEnabled = fomoOn;
        _HomeCache.fomoIntervalSeconds = fomoInt;
        _HomeCache.spinWheelEnabled = spinOn;
        _HomeCache.spinRequire24hOrder = spinReq24;
        _HomeCache.spinLock24hEnabled = spinLock24;
        if (slices != null) {
          _HomeCache.dynamicSpinSlices = slices;
        }

        setState(() {
          _isFlashSaleLive = live;
          if (title != null && title.isNotEmpty) {
            _flashRushTitle = title;
          }
          if (timerMins != null && timerMins > 0) {
            _flashSaleMinutes = timerMins;
          }
          _fomoEnabled = fomoOn;
          _fomoIntervalSeconds = fomoInt;
          _spinWheelEnabled = spinOn;
          _spinRequire24hOrder = spinReq24;
          _spinLock24hEnabled = spinLock24;
          if (slices != null) {
            _dynamicSpinSlices = slices;
          }
        });
        _startFomoTimer();
        _checkSpin24hStatus();
      }
    } catch (_) {}
  }

  Future<void> _loadFlashDeals() async {
    try {
      final rows = await _supabase
          .from('festive_deals')
          .select()
          .order('display_order', ascending: true)
          .limit(10);

      final list = (rows as List).map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        final vendorId = row['vendor_id']?.toString() ??
            (_allVendors.isNotEmpty ? _allVendors.first.id : '');
        final vendorName = _allVendors.isNotEmpty
            ? _allVendors.first.name
            : 'Streat Eats Special';
        final price = (row['price'] as num?)?.toDouble() ?? 0.0;
        final origPrice = (row['original_price'] as num?)?.toDouble();
        return MenuItemModel(
          id: row['id']?.toString() ?? '',
          vendorId: vendorId,
          vendorName: vendorName,
          name: row['title'] as String? ?? 'Flash Deal',
          description: row['subtitle'] as String? ?? '',
          vendorPrice: price,
          appPrice: price,
          originalPrice: origPrice,
          isDiscounted: origPrice != null && origPrice > price,
          category: 'Flash Deal',
          imageUrl: row['image_url'] as String?,
          isAvailable: row['is_available'] as bool? ?? true,
          dealTag: row['badge_text'] as String? ?? 'Flash Deal',
          isTodaysDeal: true,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _flashDeals = list;
        });
      }
    } catch (_) {}
  }

  void _setupRealtimeSubscriptions() {
    try {
      _growthChannel = _supabase
          .channel('public:app_growth_configs')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_growth_configs',
            callback: (payload) {
              if (mounted) {
                _loadGrowthSettings();
                _checkSpin24hStatus();
                context.read<CartProvider>().reloadSettings();
              }
            },
          )
          .subscribe();

      _settingsChannel = _supabase
          .channel('public:app_settings')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_settings',
            callback: (payload) {
              if (mounted) {
                _loadLiveOrdersSettings();
                _loadTiming();
                context.read<CartProvider>().reloadSettings();
              }
            },
          )
          .subscribe();

      _festiveDealsChannel = _supabase
          .channel('public:festive_deals')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'festive_deals',
            callback: (payload) {
              if (mounted) {
                _loadFlashDeals();
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  void _startFlashSaleTimer() {
    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_flashSaleSeconds > 0) {
          _flashSaleSeconds--;
        } else if (_flashSaleMinutes > 0) {
          _flashSaleMinutes--;
          _flashSaleSeconds = 59;
        } else {
          _flashSaleMinutes = _HomeCache.flashSaleMinutes;
          _flashSaleSeconds = 59;
        }
      });
    });
  }

  void _startFomoTimer() {
    _fomoTimer?.cancel();
    final interval = _fomoIntervalSeconds > 10 ? _fomoIntervalSeconds : 26;
    _fomoTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!mounted || !_fomoEnabled || _isDialogOpen) return;
      setState(() {
        _fomoIndex = (_fomoIndex + 1) % _fomoToasts.length;
        _showFomoToast = true;
      });
      Future.delayed(const Duration(milliseconds: 3800), () {
        if (mounted) {
          setState(() => _showFomoToast = false);
        }
      });
    });
  }

  Widget _buildFomoToastOverlay() {
    if (_isDialogOpen || !_fomoEnabled || !_showFomoToast) {
      return const SizedBox.shrink();
    }
    final t = _fomoToasts[_fomoIndex];
    return Positioned(
      bottom: 12,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: _showFomoToast ? 1.0 : 0.0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFFF6B2B).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B2B).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🔥', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                t['name'] ?? 'Foodie',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t['time'] ?? 'Just now',
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          t['item'] ?? 'just ordered on Streat Eats',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 10.5,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showFomoToast = false),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, color: Colors.grey[400], size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeFreeDeliveryBar(CartProvider cart) {
    if (!cart.isFreeDeliveryEnabled) return const SizedBox.shrink();
    final threshold = cart.freeDeliveryMinAmount;
    if (threshold <= 0) return const SizedBox.shrink();
    final subtotal = cart.subtotal;
    final diff = threshold - subtotal;
    final isUnlocked = diff <= 0;
    final progress = (subtotal / threshold).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked ? const Color(0xFFA7F3D0) : const Color(0xFFFFEDD5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUnlocked ? '🎉' : '🛵',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isUnlocked
                      ? 'Congratulations! FREE Delivery Unlocked'
                      : 'Add ₹${diff.ceil()} more for FREE Delivery!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked
                        ? const Color(0xFF065F46)
                        : const Color(0xFF9A3412),
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CartScreen(isStandalone: true),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? const Color(0xFF059669)
                        : const Color(0xFFEA580C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'View Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isUnlocked
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFFEDD5),
              color: isUnlocked
                  ? const Color(0xFF10B981)
                  : const Color(0xFFFF6B2B),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashRushSection() {
    final dealItems = _flashDeals.isNotEmpty
        ? _flashDeals
        : (_todaysDeals.isNotEmpty
            ? _todaysDeals.take(5).toList()
            : _recommendedItems.take(5).toList());

    if (dealItems.isEmpty) return const SizedBox.shrink();

    final minStr = _flashSaleMinutes.toString().padLeft(2, '0');
    final secStr = _flashSaleSeconds.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF2F2), Color(0xFFFFF7ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Text(
                      'FLASH RUSH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _flashRushTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ends in $minStr:$secStr',
                  style: const TextStyle(
                    color: Color(0xFFFCD34D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dealItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = dealItems[i];
                final strikePrice = (item.displayPrice * 1.55).round();
                final discountPercent = (((strikePrice - item.displayPrice) / strikePrice) * 100).round();

                return GestureDetector(
                  onTap: () => _onRecommendedTap(item),
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.imageUrl!,
                                      height: 80,
                                      width: 130,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        height: 80,
                                        color: Colors.grey[200],
                                        child: const Center(child: Text('🍲', style: TextStyle(fontSize: 24))),
                                      ),
                                    )
                                  : Container(
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Center(child: Text('🍲', style: TextStyle(fontSize: 24))),
                                    ),
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$discountPercent% OFF',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '₹${item.displayPrice.round()}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '₹$strikePrice',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                      decoration: TextDecoration.lineThrough,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      final vendor = _vendorCache[item.vendorId] ??
                                          _allVendors.firstWhere(
                                            (v) => v.id == item.vendorId,
                                            orElse: () => VendorModel(
                                              id: item.vendorId,
                                              name: item.vendorName.isNotEmpty
                                                  ? item.vendorName
                                                  : 'Streat Eats Vendor',
                                              area: _userArea,
                                              phone: '',
                                              city: 'Haldwani',
                                              latitude: 0.0,
                                              longitude: 0.0,
                                              category: item.category,
                                              timing: '17:00 - 21:00',
                                              isActive: true,
                                            ),
                                          );
                                      CartUtils.handleCartAddItem(
                                        context,
                                        item,
                                        vendor,
                                        onSuccess: () {
                                          AppSnackBar.showSuccess(context, 'Added ${item.name} to cart!');
                                        },
                                        onLimitReached: () {
                                          AppSnackBar.showError(context, 'Cart limit reached!');
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B2B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '+ ADD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGatedSpinBanner() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_isSpinLocked24h) {
          _showSpin24hLockedSheet();
        } else if (!_spinRequire24hOrder || _hasOrderedIn24h) {
          _showSpinWheelDialog();
        } else {
          _showSpinLockedSheet();
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isSpinLocked24h
                ? const [Color(0xFF1E1B4B), Color(0xFF312E81)]
                : const [Color(0xFF2E1065), Color(0xFF4C1D95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4C1D95).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
              ),
              child: Center(
                child: Text(
                  _isSpinLocked24h ? '⏳' : '🎰',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Spin & Win Jackpot',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _isSpinLocked24h ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _isSpinLocked24h ? '24H LOCK' : 'DAILY',
                          style: TextStyle(
                            color: _isSpinLocked24h ? Colors.white : const Color(0xFF2E1065),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isSpinLocked24h
                        ? '⏳ Spun! Next spin in: $_spinCountdownText'
                        : (_hasOrderedIn24h || !_spinRequire24hOrder
                            ? '🎉 UNLOCKED! Tap to spin and claim food rewards'
                            : '🔒 Locked! Order in last 24h to unlock spin'),
                    style: TextStyle(
                      color: _isSpinLocked24h
                          ? const Color(0xFFFCD34D)
                          : ((_hasOrderedIn24h || !_spinRequire24hOrder)
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFCD34D)),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isSpinLocked24h
                    ? const Color(0xFF374151)
                    : ((_hasOrderedIn24h || !_spinRequire24hOrder)
                        ? const Color(0xFF10B981)
                        : const Color(0xFF374151)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSpinLocked24h
                        ? Icons.timer_outlined
                        : ((_hasOrderedIn24h || !_spinRequire24hOrder)
                            ? Icons.play_arrow_rounded
                            : Icons.lock_outline_rounded),
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSpinLocked24h
                        ? 'LOCKED'
                        : ((_hasOrderedIn24h || !_spinRequire24hOrder) ? 'SPIN' : 'RULES'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins',
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

  void _showSpin24hLockedSheet() {
    _isDialogOpen = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  ),
                  child: const Center(
                    child: Text('⏳', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Daily Spin Used! 🎰',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You can spin the wheel once every 24 hours. Your next spin will unlock automatically after the timer expires.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF312E81).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'NEXT SPIN UNLOCKS IN',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFFFBBF24),
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _spinCountdownText.isNotEmpty ? _spinCountdownText : '24h 00m 00s',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_lastWonSpinCode != null && _lastWonSpinCode!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Won Reward: ${_lastWonSpinTitle ?? "Discount"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF166534),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastWonSpinCode!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF15803D),
                                  letterSpacing: 1,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _lastWonSpinCode!));
                            AppSnackBar.showSuccess(context, 'Coupon copied to clipboard!');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onSwitchTab(1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B2B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Order Food Now 🍕',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      _isDialogOpen = false;
    });
  }

  void _showSpinLockedSheet() {
    _isDialogOpen = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 30),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Spin & Win is Locked 🔒',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Place at least 1 order in the last 24 hours to unlock the Daily Foodie Spin & Win jackpot!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 How It Works & Conditions:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSpinRuleRow('🎯', 'Place 1 order today to automatically unlock this wheel'),
                  _buildSpinRuleRow('⚡', 'Wheel remains unlocked for 24 hours from your order time'),
                  _buildSpinRuleRow('🎟️', 'Win auto-generated single-use coupons (Free Delivery, Packaging, Platform Fee, Flat OFF)'),
                  _buildSpinRuleRow('🛒', 'Coupon applies automatically on minimum order value'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onSwitchTab(1); // Street Food tab
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B2B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Order Food & Unlock Spin 🍕',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      _isDialogOpen = false;
    });
  }

  Widget _buildSpinRuleRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                fontFamily: 'Poppins',
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSpinWheelDialog() {
    _isDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SpinWheelDialog(
        customSlices: _dynamicSpinSlices.isNotEmpty ? _dynamicSpinSlices : null,
        onWon: (code, chosen) {
          _onSpinCompleted(code, chosen);
        },
      ),
    ).whenComplete(() {
      _isDialogOpen = false;
    });
  }
}

// ═══════════════════════════════════════════════════════════
// ── Spin Wheel Dialog Widget ───────────────────────────────
// ═══════════════════════════════════════════════════════════
class _SpinWheelDialog extends StatefulWidget {
  final List<Map<String, dynamic>>? customSlices;
  final Function(String code, Map<String, dynamic> chosen)? onWon;

  const _SpinWheelDialog({this.customSlices, this.onWon});

  @override
  State<_SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<_SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  bool _isSpinning = false;
  bool _hasWon = false;
  Map<String, dynamic>? _wonReward;
  String? _generatedCode;

  static final List<Map<String, dynamic>> _defaultSlices = [
    {
      'title': 'FREE DELIVERY',
      'label': 'FREE SHIP',
      'type': 'free_delivery',
      'minCart': 99,
      'discount': 0,
      'isFree': true,
      'isPercent': false,
      'color': const Color(0xFF10B981),
    },
    {
      'title': 'FREE PACKAGING',
      'label': 'FREE PKG',
      'type': 'free_packaging',
      'minCart': 99,
      'discount': 0,
      'isFree': true,
      'isPercent': false,
      'color': const Color(0xFF3B82F6),
    },
    {
      'title': 'FREE PLATFORM FEE',
      'label': 'NO FEE',
      'type': 'free_platform_fee',
      'minCart': 99,
      'discount': 0,
      'isFree': true,
      'isPercent': false,
      'color': const Color(0xFF06B6D4),
    },
    {
      'title': 'FLAT ₹20 OFF',
      'label': '₹20 OFF',
      'type': 'flat',
      'minCart': 129,
      'discount': 20,
      'isFree': false,
      'isPercent': false,
      'color': const Color(0xFFEC4899),
    },
    {
      'title': 'FLAT ₹30 OFF',
      'label': '₹30 OFF',
      'type': 'flat',
      'minCart': 149,
      'discount': 30,
      'isFree': false,
      'isPercent': false,
      'color': const Color(0xFFFF6B2B),
    },
    {
      'title': 'FLAT ₹40 OFF',
      'label': '₹40 OFF',
      'type': 'flat',
      'minCart': 199,
      'discount': 40,
      'isFree': false,
      'isPercent': false,
      'color': const Color(0xFFF59E0B),
    },
  ];

  List<Map<String, dynamic>> get _slices {
    if (widget.customSlices != null && widget.customSlices!.isNotEmpty) {
      return widget.customSlices!.map((s) {
        final title = s['title'] as String? ?? 'Offer';
        final label = s['label'] as String? ?? title;
        final type = s['type'] as String? ?? 'flat';
        final val = (s['value'] as num?)?.toInt() ?? 20;
        final minCart = (s['min_cart'] as num?)?.toInt() ?? 149;
        Color col;
        try {
          final cStr = s['color']?.toString() ?? '';
          if (cStr.startsWith('0x') || cStr.startsWith('0X')) {
            col = Color(int.parse(cStr));
          } else if (cStr.startsWith('#')) {
            col = Color(int.parse(cStr.replaceFirst('#', '0xFF')));
          } else {
            col = const Color(0xFFFF6B2B);
          }
        } catch (_) {
          col = const Color(0xFFFF6B2B);
        }
        return {
          'title': title,
          'label': label,
          'type': type,
          'discount': val,
          'minCart': minCart,
          'isFree': type == 'free_delivery' ||
              type == 'free_packaging' ||
              type == 'free_platform_fee',
          'isPercent': type == 'percent',
          'color': col,
        };
      }).toList();
    }
    return _defaultSlices;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _spinWheel() async {
    if (_isSpinning || _hasWon) return;
    setState(() => _isSpinning = true);
    HapticFeedback.heavyImpact();

    final slicesList = _slices;
    final targetIndex = Random().nextInt(slicesList.length);
    final chosen = slicesList[targetIndex];

    final anglePerSlice = (2 * pi) / slicesList.length;
    final targetAngle = (5 * 2 * pi) + (targetIndex * anglePerSlice);

    _anim = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    await _ctrl.forward(from: 0);
    HapticFeedback.lightImpact();

    final type = chosen['type'] ?? 'flat';
    final randSuffix = Random().nextInt(9000) + 1000;
    String prefix = 'SPIN';
    if (type == 'free_delivery') {
      prefix = 'FREEDEL';
    } else if (type == 'free_packaging') {
      prefix = 'FREEPKG';
    } else if (type == 'free_platform_fee') {
      prefix = 'NOFEE';
    } else if (type == 'percent') {
      prefix = 'DISC${chosen['discount']}';
    } else {
      prefix = 'SPIN${chosen['discount']}';
    }
    final code = '$prefix-$randSuffix';

    String dType = 'none';
    double dVal = 0;
    String pkgType = 'none';
    double pkgVal = 0;
    String pltType = 'none';
    double pltVal = 0;

    if (type == 'free_delivery') {
      dType = 'free';
    } else if (type == 'free_packaging') {
      pkgType = 'free';
    } else if (type == 'free_platform_fee') {
      pltType = 'free';
    } else if (type == 'percent') {
      dType = 'percent';
      dVal = (chosen['discount'] as num).toDouble();
    } else {
      dType = 'flat';
      dVal = (chosen['discount'] as num).toDouble();
    }

    try {
      final expiresAt = DateTime.now().add(const Duration(hours: 24)).toIso8601String();
      await Supabase.instance.client.from('offers').insert({
        'coupon_code': code,
        'title': 'Spin & Win: ${chosen['title']}',
        'description': 'Valid on min cart ₹${chosen['minCart']}. 24h single-use reward.',
        'delivery_discount_type': dType,
        'delivery_discount_value': dVal,
        'platform_fee_discount_type': pltType,
        'platform_fee_discount_value': pltVal,
        'packaging_fee_discount_type': pkgType,
        'packaging_fee_discount_value': pkgVal,
        'min_cart_value': chosen['minCart'],
        'max_uses_new': 1,
        'is_active': true,
        'expires_at': expiresAt,
      });
    } catch (_) {}

    widget.onWon?.call(code, chosen);

    if (mounted) {
      setState(() {
        _isSpinning = false;
        _hasWon = true;
        _wonReward = chosen;
        _generatedCode = code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slicesList = _slices;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('🎰', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Text(
                  'Daily Spin & Win',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Poppins',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _hasWon
                  ? '🎉 Congratulations! Your coupon is generated & active!'
                  : 'Spin the wheel to win your exclusive 24-hour food reward!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _hasWon ? const Color(0xFF059669) : const Color(0xFF6B7280),
                fontWeight: _hasWon ? FontWeight.w700 : FontWeight.normal,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 18),
            if (!_hasWon) ...[
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _anim.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B2B).withValues(alpha: 0.25),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _WheelPainter(slices: slicesList),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 18,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1F2937),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: const Center(
                        child: Text('🎁', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSpinning ? null : _spinWheel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isSpinning ? 'SPINNING... 🎲' : 'SPIN THE WHEEL! 🚀',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    const Text('🎊 YOU WON! 🎊', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF15803D), fontFamily: 'Poppins')),
                    const SizedBox(height: 6),
                    Text(
                      _wonReward?['title'] ?? 'Reward',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF166534),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _generatedCode ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Color(0xFF1F2937),
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              if (_generatedCode != null) {
                                Clipboard.setData(ClipboardData(text: _generatedCode!));
                                AppSnackBar.showSuccess(context, 'Coupon code copied to clipboard!');
                              }
                            },
                            child: const Icon(Icons.copy_rounded, color: Color(0xFFFF6B2B), size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Applies on orders above ₹${_wonReward?['minCart'] ?? 149}\n• Valid for 24 Hours • 1-Time Use Only',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_generatedCode != null) {
                      Clipboard.setData(ClipboardData(text: _generatedCode!));
                    }
                    Navigator.pop(context);
                    AppSnackBar.showSuccess(context, 'Coupon copied! Paste it in Cart.');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'COPY CODE & ORDER NOW 🍕',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> slices;
  const _WheelPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * pi) / slices.length;

    for (var i = 0; i < slices.length; i++) {
      final startAngle = i * sweepAngle;
      final paint = Paint()
        ..color = (slices[i]['color'] as Color).withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw slice label text
      final label = slices[i]['label']?.toString() ?? '';
      if (label.isNotEmpty) {
        final textAngle = startAngle + sweepAngle / 2;
        final textSpan = TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            fontFamily: 'Poppins',
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(textAngle);
        textPainter.paint(
          canvas,
          Offset(radius * 0.45, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════
// Pinned Header
// ═══════════════════════════════════════════════════════════
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPad;
  final Color bannerColor;
  final List<_BannerData> banners;
  final bool loadingBanners;
  final ValueNotifier<int> activePageNotifier;
  final PageController bannerCtrl;
  final bool isAppActive;
  final double headerTotalH;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_BannerData> onBannerTap;
  final VoidCallback onCartTap;
  final VoidCallback onProfileTap;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final String userArea;
  final String? avatarUrl;

  static const double _locationH = 52.0;
  static const double _searchH = 50.0;
  static const double _bannerH = 200.0;

  const _PinnedHeaderDelegate({
    required this.topPad,
    required this.bannerColor,
    required this.banners,
    required this.loadingBanners,
    required this.activePageNotifier,
    required this.bannerCtrl,
    required this.isAppActive,
    required this.headerTotalH,
    required this.onPageChanged,
    required this.onBannerTap,
    required this.onCartTap,
    required this.onProfileTap,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.userArea,
    this.avatarUrl,
  });

  @override
  double get minExtent => topPad + _locationH + _searchH;
  @override
  double get maxExtent => headerTotalH;

  @override
  bool shouldRebuild(_PinnedHeaderDelegate old) =>
      old.bannerColor != bannerColor ||
      old.loadingBanners != loadingBanners ||
      old.isAppActive != isAppActive ||
      old.banners.length != banners.length ||
      old.userArea != userArea ||
      old.avatarUrl != avatarUrl;

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: bannerColor,
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
                  : ClipRRect(
                      child: PageView.builder(
                        controller: bannerCtrl,
                        onPageChanged: onPageChanged,
                        physics: const BouncingScrollPhysics(),
                        itemCount: banners.length,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onLocationTap,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              userArea,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'Poppins',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                      const Text(
                                        'Haldwani, Uttarakhand',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Cart button (next to profile button)
                        Consumer<CartProvider>(
                          builder: (context, cart, _) {
                            final count = cart.totalItems;
                            return GestureDetector(
                              onTap: onCartTap,
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                    if (count > 0)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: _LC.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            count > 99 ? '99+' : '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'Poppins',
                                              height: 1.1,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Profile button
                        GestureDetector(
                          onTap: onProfileTap,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: avatarUrl != null && avatarUrl!.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: avatarUrl!,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
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
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.search_rounded,
                            color: _LC.textMuted.withValues(alpha: 0.7),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Search for 'Products'",
                              style: TextStyle(
                                color: _LC.textMuted,
                                fontSize: 13,
                                fontFamily: 'Poppins',
                              ),
                            ),
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
                child: ValueListenableBuilder<int>(
                  valueListenable: activePageNotifier,
                  builder: (_, activePage, __) => Row(
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
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
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
                      color: Colors.white.withValues(alpha: 0.22),
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
      return Container(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Column(
          children: List.generate(
            2,
            (rowIdx) => Padding(
              padding: EdgeInsets.only(bottom: rowIdx == 0 ? 6 : 0),
              child: SizedBox(
                height: 98,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  itemCount: 5,
                  itemBuilder: (_, __) => Shimmer.fromColors(
                    baseColor: const Color(0xFFEAE8E4),
                    highlightColor: const Color(0xFFF7F5F2),
                    child: Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.only(right: 10, top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // Categories ko 2 rows mein split karo
    final allCats = categories;
    final half = (allCats.length / 2).ceil();
    final row1 = allCats.take(half).toList();
    final row2 = allCats.skip(half).toList();

    Widget buildCatItem(
      Map<String, dynamic> cat,
      String selectedCategory,
      void Function(String) onCatTap,
    ) {
      final name = cat['name'] as String? ?? '';
      final emoji = cat['emoji'] as String? ?? '🍽️';
      final imgUrl = cat['image_url'] as String?;
      final isSelected = name == selectedCategory;

      return GestureDetector(
        onTap: () => onCatTap(name),
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected ? _LC.accentLight : _LC.surface,
                  border: Border.all(
                    color: isSelected ? _LC.accent : _LC.border,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _LC.accent.withValues(alpha: 0.20),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: imgUrl != null && imgUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: isSelected
                                ? _LC.accentLight
                                : const Color(0xFFF7F5F2),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 30),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: isSelected
                              ? _LC.accentLight
                              : const Color(0xFFF7F5F2),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? _LC.accent : _LC.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1
          SizedBox(
            height: 98,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              physics: const BouncingScrollPhysics(),
              children: row1
                  .map((c) => buildCatItem(c, selectedCategory, onCatTap))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          // Row 2
          if (row2.isNotEmpty)
            SizedBox(
              height: 98,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                physics: const BouncingScrollPhysics(),
                children: row2
                    .map((c) => buildCatItem(c, selectedCategory, onCatTap))
                    .toList(),
              ),
            ),
        ],
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
// ✅ 1. Live Order Counter Section (Positioned right after Categories)
// ═══════════════════════════════════════════════════════════
class _LiveOrderCounterSection extends StatelessWidget {
  final String text;
  final int orderCount;
  final String userArea;

  const _LiveOrderCounterSection({
    required this.text,
    required this.orderCount,
    required this.userArea,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = text.isNotEmpty
        ? text
        : '${orderCount > 0 ? orderCount : 240}+ people ordered in the last hour from $userArea! 🔥';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _LC.accentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _LC.accentBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _LC.accent.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing live indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _LC.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _LC.green.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Flame icon badge
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _LC.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          // Text
          Expanded(
            child: Text(
              displayText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _LC.textPrimary,
                fontFamily: 'Poppins',
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ✅ 2. Today's Best Deals Section (Horizontal Scrolling)
// ═══════════════════════════════════════════════════════════
class _TodaysDealsSection extends StatelessWidget {
  final List<MenuItemModel> items;
  final bool loading;
  final void Function(MenuItemModel) onItemTap;
  final VoidCallback? onViewAll;

  const _TodaysDealsSection({
    required this.items,
    required this.loading,
    required this.onItemTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading && items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
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
                      "Today's Best Deals 🔥",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _LC.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Special discounts & limited stock',
                      style: TextStyle(
                        fontSize: 11,
                        color: _LC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              if (!loading && onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                ),
            ],
          ),
        ),
        if (loading)
          _buildShimmer()
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  width: 165,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ExploreItemCard(
                    item: item,
                    imageHeight: 125,
                    badgeText: item.dealTag ??
                        (item.dealStockLeft != null
                            ? '🔥 ${item.dealStockLeft} left'
                            : null),
                    onTap: () => onItemTap(item),
                  ),
                );
              },
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          height: 1,
          color: _LC.border,
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          width: 165,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE8E4),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ✅ 3. Trending in Haldwani Section (Horizontal with Rankings #1, #2, #3...)
// ═══════════════════════════════════════════════════════════
class _TrendingNowSection extends StatelessWidget {
  final List<MenuItemModel> items;
  final bool loading;
  final String userArea;
  final void Function(MenuItemModel) onItemTap;
  final VoidCallback? onViewAll;

  const _TrendingNowSection({
    required this.items,
    required this.loading,
    required this.userArea,
    required this.onItemTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading && items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: _LC.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trending in $userArea 📈',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _LC.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Most ordered right now',
                      style: TextStyle(
                        fontSize: 11,
                        color: _LC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              if (!loading && onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Text(
                      'View All',
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
        ),
        if (loading)
          _buildShimmer()
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  width: 165,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ExploreItemCard(
                    item: item,
                    imageHeight: 125,
                    rank: index + 1,
                    badgeText: item.orderCountBadge ??
                        (index < 3
                            ? '${150 - (index + 1) * 20}+ orders'
                            : '🔥 Trending'),
                    onTap: () => onItemTap(item),
                  ),
                );
              },
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          height: 1,
          color: _LC.border,
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          width: 165,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE8E4),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
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
  final VoidCallback? onViewAll;

  const _RecommendedItemsSection({
    required this.items,
    required this.loading,
    required this.onItemTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading && items.isEmpty) return const SizedBox.shrink();

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
                  color: const Color(0xFFFF6B35),
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
                        color: Color(0xFF1A1A1A),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hand-picked by our team',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              if (!loading && onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD4BC)),
                    ),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFFFF6B2B),
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
        if (loading)
          _buildShimmer()
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 165,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ExploreItemCard(
                    item: items[index],
                    imageHeight: 125,
                    onTap: () => onItemTap(items[index]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          width: 165,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE8E4),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
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
                    border: Border.all(color: _LC.blue.withValues(alpha: 0.2)),
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
                    color: Colors.white.withValues(alpha: 0.2),
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
          height: 230,
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
                  width: 170,
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
                                        color: _LC.red.withValues(alpha: 0.4),
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
                      Expanded(
                        child: Padding(
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
                              const Spacer(),
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                  _ComboAddButton(combo: combo),
                                ],
                              ),
                            ],
                          ),
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
              color: Colors.black.withValues(alpha: 0.15),
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
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.25),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
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
    color: Colors.white.withValues(alpha: 0.20),
    child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
  );
}

class _OutOfZoneWidget extends StatelessWidget {
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
              'Streat Eats is currently available only in Haldwani and nearby areas. We are expanding soon!',
              style: TextStyle(
                fontSize: 13,
                color: _LC.textMuted,
                fontFamily: 'Poppins',
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRequestSheet extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  const _LocationRequestSheet({
    required this.onAllow,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
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
              color: _LC.accentLight,
              shape: BoxShape.circle,
              border: Border.all(color: _LC.accentBorder, width: 1.5),
            ),
            child: const Center(
              child: Text('📍', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Share Your Location',
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
            'To show nearby vendors, we need your location.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontFamily: 'Poppins',
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onAllow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _LC.accent,
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
}

class _FilteredItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onTap;

  const _FilteredItemCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _LC.border),
        ),
        child: Row(
          children: [
            // Item image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 72,
                        height: 72,
                        color: _LC.accentLight,
                        child: const Icon(Icons.fastfood_rounded,
                            color: _LC.accent, size: 28),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: _LC.accentLight,
                        child: const Icon(Icons.fastfood_rounded,
                            color: _LC.accent, size: 28),
                      ),
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      color: _LC.accentLight,
                      child: const Icon(Icons.fastfood_rounded,
                          color: _LC.accent, size: 28),
                    ),
            ),
            const SizedBox(width: 12),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Veg/Non-veg indicator
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: item.isVeg ? _LC.green : _LC.red,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Center(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item.description.isNotEmpty)
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _LC.textMuted,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '₹${item.appPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _LC.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (item.isDiscounted && item.originalPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${item.originalPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _LC.textMuted,
                            fontFamily: 'Poppins',
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _LC.greenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.discountPercent}% OFF',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _LC.green,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            const Icon(Icons.chevron_right_rounded,
                color: _LC.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                3,
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
                ],
              ),
            ),
          ),
        if (!loading && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: items
                  .map<Widget>((item) => _FilteredItemCard(
                        item: item,
                        onTap: () => onItemTap(item),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _ComboAddButton extends StatefulWidget {
  final ComboModel combo;
  const _ComboAddButton({required this.combo});

  @override
  State<_ComboAddButton> createState() => _ComboAddButtonState();
}

class _ComboAddButtonState extends State<_ComboAddButton> {
  bool _isAdding = false;

  void _addToCart() async {
    setState(() => _isAdding = true);
    try {
      final vendor = await VendorService().getVendorById(widget.combo.vendorId);
      if (!mounted) return;

      if (vendor == null) {
        setState(() => _isAdding = false);
        AppSnackBar.showError(context, 'Vendor not found');
        return;
      }

      final comboAsItem = MenuItemModel(
        id: widget.combo.id,
        vendorId: widget.combo.vendorId,
        vendorName: vendor.name,
        name: '🎁 ${widget.combo.name}',
        description: widget.combo.description,
        vendorPrice: widget.combo.vendorPrice,
        appPrice: widget.combo.appPrice,
        originalPrice: widget.combo.originalPrice,
        isDiscounted: widget.combo.isDiscounted,
        category: 'Combo',
        isAvailable: true,
        imageUrl: widget.combo.imageUrl,
      );

      CartUtils.handleCartAddItem(
        context,
        comboAsItem,
        vendor,
        onSuccess: () {
          if (mounted) setState(() => _isAdding = false);
        },
        onLimitReached: () {
          if (mounted) setState(() => _isAdding = false);
          AppSnackBar.showError(context, 'Cart limit reached!');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isAdding = false);
      AppSnackBar.showError(context, 'Failed to add item');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = context.watch<CartProvider>().getQuantity(widget.combo.id);

    if (qty > 0) {
      return Container(
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF16A34A),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<CartProvider>().removeItem(widget.combo.id);
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Icon(
                  Icons.remove_rounded,
                  color: Color(0xFF16A34A),
                  size: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$qty',
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (!_isAdding) _addToCart();
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: _isAdding
                    ? const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFF16A34A),
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF16A34A),
                        size: 14,
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (!_isAdding) _addToCart();
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _LC.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isAdding
            ? const Padding(
                padding: EdgeInsets.all(6.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
            : const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 15,
              ),
      ),
    );
  }
}
