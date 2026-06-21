// lib/screens/restaurant_list_screen.dart
// v3.0 — Streat Eats UI Enhancement
// ✅ Full UI upgrade: gradient overlay, emoji chips, pricing, animations
// ✅ Brand name updated: Streat Eats
// ✅ All previous logic preserved exactly

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_model.dart';
import '../services/vendor_service.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import 'restaurant_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

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
  static const chipUnselected = Color(0xFFF5F5F5);
}

// Cuisine emoji map
const Map<String, String> _cuisineEmoji = {
  'All': '🍽️',
  'North Indian': '🫕',
  'South Indian': '🍛',
  'Biryani': '🍚',
  'Chinese': '🥡',
  'Mughlai': '🍖',
  'Beverages': '🥤',
  'Fast Food': '🍔',
  'Street Food': '🌮',
  'Sweets': '🍬',
  'Desserts': '🍨',
  'Pizza': '🍕',
  'Rolls': '🌯',
  'Momos': '🥟',
};

String _emojiForCuisine(String cuisine) => _cuisineEmoji[cuisine] ?? '🍴';

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  final _vendorService = VendorService();
  final _locationService = LocationService();
  final _supabase = Supabase.instance.client;

  List<VendorModel> _restaurants = [];
  List<VendorModel> _filtered = [];
  bool _isLoading = true;
  String _selectedCuisine = 'All';
  List<String> _cuisines = ['All'];

  bool _isWithinTime = true;
  bool _isTimingEnabled = false;
  bool get _isAppActive => !_isTimingEnabled || _isWithinTime;
  String _openTime = '17:00';
  Timer? _timingCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkAppTiming();
    _loadRestaurants();
    _timingCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _checkAppTiming();
    });
  }

  @override
  void dispose() {
    _timingCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAppTiming() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('is_timing_enabled, open_time, close_time')
          .limit(1)
          .maybeSingle();

      if (data == null) {
        if (mounted) setState(() => _isWithinTime = true);
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
      if (mounted) {
        setState(() {
          _isTimingEnabled = true;
          _isWithinTime = isOpen;
          _openTime = nextOpen.isNotEmpty ? nextOpen : openTime;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isWithinTime = true);
    }
  }

  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);
    try {
      final restaurants = await _vendorService.getRestaurants();

      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        for (var r in restaurants) {
          r.distanceKm = _locationService.getDistanceKm(
            position.latitude,
            position.longitude,
            r.latitude,
            r.longitude,
          );
          r.deliveryMinutes = _locationService.getDeliveryMinutes(
            r.distanceKm!,
          );
        }
        restaurants.sort(
          (a, b) => (a.distanceKm ?? 99).compareTo(b.distanceKm ?? 99),
        );
      }

      final Set<String> cuisineSet = {};
      for (final r in restaurants) {
        if (r.cuisineType != null && r.cuisineType!.isNotEmpty) {
          r.cuisineType!
              .split(',')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .forEach(cuisineSet.add);
        }
      }

      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _filtered = restaurants;
        _cuisines = ['All', ...cuisineSet.toList()..sort()];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Restaurant load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterByCuisine(String cuisine) {
    setState(() {
      _selectedCuisine = cuisine;
      _filtered = cuisine == 'All'
          ? _restaurants
          : _restaurants
                .where(
                  (r) =>
                      r.cuisineType != null &&
                      r.cuisineType!
                          .split(',')
                          .map((c) => c.trim())
                          .contains(cuisine),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _LC.background,
        body: Column(
          children: [
            // ── Enhanced Header ──────────────────────────────
            Container(
              color: _LC.surface,
              padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Animated logo container
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B2B), Color(0xFFFF8C42)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _LC.accent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🍽️', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Restaurants',
                              style: TextStyle(
                                color: _LC.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            // Dynamic count
                            Row(
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 11,
                                  color: _LC.accent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _isLoading
                                      ? 'Loading...'
                                      : '${_filtered.length} restaurants nearby',
                                  style: const TextStyle(
                                    color: _LC.textMuted,
                                    fontSize: 11,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Open/Closed badge with pulsing dot
                      _PulsingBadge(isOpen: _isAppActive),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Enhanced Cuisine Chips ──────────────────
                  if (_cuisines.length > 1)
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cuisines.length,
                        itemBuilder: (_, i) {
                          final c = _cuisines[i];
                          final isSelected = _selectedCuisine == c;
                          final emoji = _emojiForCuisine(c);
                          return GestureDetector(
                            onTap: () => _filterByCuisine(c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _LC.accent
                                    : _LC.chipUnselected,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? _LC.accent : _LC.border,
                                  width: isSelected ? 0 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _LC.accent.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    c,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : _LC.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 12,
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
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Orange accent line below header
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF6B2B),
                    Color(0xFFFFD4BC),
                    Color(0xFFF7F5F2),
                  ],
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _LC.accent,
                        strokeWidth: 2.5,
                      ),
                    )
                  : !_isAppActive
                  ? _RestaurantClosedWidget(openTime: _openTime)
                  : _filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _checkAppTiming();
                        await _loadRestaurants();
                      },
                      color: _LC.accent,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, i) => _RestaurantCard(
                          restaurant: _filtered[i],
                          onTap: () {
                            final r = _filtered[i];
                            if (r.distanceKm != null && r.distanceKm! > 0) {
                              context
                                  .read<CartProvider>()
                                  .setDeliveryChargeForDistance(r.distanceKm!);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RestaurantDetailScreen(vendor: r),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1EB), Color(0xFFEFF6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: _LC.accentBorder, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _LC.accent.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('😕', style: TextStyle(fontSize: 38)),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No Restaurants Found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _LC.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'We\'re adding restaurants soon!\nPlease check back later.',
            style: TextStyle(
              color: _LC.textMuted,
              fontSize: 13,
              height: 1.5,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _loadRestaurants,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Refresh',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _LC.accent,
              side: const BorderSide(color: _LC.accent),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing Open/Closed Badge ─────────────────────────────────
class _PulsingBadge extends StatefulWidget {
  final bool isOpen;
  const _PulsingBadge({required this.isOpen});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOpen ? _LC.green : _LC.red;
    final bgColor = widget.isOpen ? _LC.greenLight : _LC.redLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Opacity(
              opacity: widget.isOpen ? _anim.value : 1.0,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            widget.isOpen ? 'Open' : 'Closed',
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
}

// ── Restaurant Closed Widget ──────────────────────────────────
class _RestaurantClosedWidget extends StatefulWidget {
  final String openTime;
  const _RestaurantClosedWidget({required this.openTime});

  @override
  State<_RestaurantClosedWidget> createState() =>
      _RestaurantClosedWidgetState();
}

class _RestaurantClosedWidgetState extends State<_RestaurantClosedWidget> {
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: _LC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _LC.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF1EB), Color(0xFFFFD4BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                'Closed Right Now',
                style: TextStyle(
                  color: _LC.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'We open at ${widget.openTime} daily!',
                style: const TextStyle(
                  color: _LC.textMuted,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 22),
              // Instagram follow box — Streat Eats handle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF1EB), Color(0xFFFFF7F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _LC.accentBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📱', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Follow us on Instagram!',
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
                            fontWeight: FontWeight.w800,
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
          width: 64,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1EB), Color(0xFFFFE4D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _LC.accentBorder),
            boxShadow: [
              BoxShadow(
                color: _LC.accent.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: _LC.accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
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
          fontSize: 24,
          fontWeight: FontWeight.w800,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

// ── Restaurant Card — Enhanced ────────────────────────────────
class _RestaurantCard extends StatelessWidget {
  final VendorModel restaurant;
  final VoidCallback onTap;
  const _RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOpen = restaurant.isActive;
    final hasImage =
        restaurant.imageUrl != null && restaurant.imageUrl!.isNotEmpty;
    final savings = restaurant.savingsPercent;
    final hasDistance = restaurant.distanceKm != null;
    final hasPricing =
        restaurant.priceForTwo != null &&
        restaurant.otherPlatformAvg != null &&
        restaurant.otherPlatformAvg! > 0;

    // Up to 2 cuisines
    final cuisines =
        restaurant.cuisineType
            ?.split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .take(2)
            .toList() ??
        [];

    // Savings amount in rupees
    final savingsAmount = hasPricing
        ? (restaurant.otherPlatformAvg! - restaurant.priceForTwo!)
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _LC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _LC.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Image with gradient overlay ──────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                  child: Stack(
                    children: [
                      // Food image
                      hasImage
                          ? CachedNetworkImage(
                              imageUrl: restaurant.imageUrl!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _imagePlaceholder(),
                              errorWidget: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),

                      // Bottom gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 70,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xCC000000), Colors.transparent],
                            ),
                          ),
                        ),
                      ),

                      // Delivery time on image (bottom left)
                      if (restaurant.deliveryMinutes != null)
                        Positioned(
                          bottom: 10,
                          left: 12,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${restaurant.deliveryMinutes} min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Open/Closed badge (top right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen ? _LC.green : _LC.red,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (isOpen ? _LC.green : _LC.red).withOpacity(
                            0.4,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                          isOpen ? 'Open' : 'Closed',
                          style: const TextStyle(
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

                // Savings badge (top left) — gradient
                if (savings > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _LC.green.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '⚡ $savings% Cheaper',
                        style: const TextStyle(
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

            // ── Card Body ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Cuisine tags row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _LC.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Up to 2 cuisine tags
                      if (cuisines.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: cuisines
                              .map(
                                (c) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _LC.accentLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _LC.accentBorder),
                                  ),
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      color: _LC.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),

                  // Location + Distance row
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 12,
                        color: _LC.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        restaurant.area,
                        style: const TextStyle(
                          color: _LC.textMuted,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (hasDistance) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _LC.accentLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: _LC.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Pricing box
                  if (hasPricing) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _LC.blueLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _LC.blueBorder),
                      ),
                      child: Row(
                        children: [
                          const Text('💰', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'On Our Platform',
                                  style: TextStyle(
                                    color: _LC.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  '₹${restaurant.priceForTwo}/person',
                                  style: const TextStyle(
                                    color: _LC.blue,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                // You save line
                                if (savingsAmount > 0)
                                  Text(
                                    'You save ₹$savingsAmount/person 🎉',
                                    style: const TextStyle(
                                      color: _LC.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Other Platforms',
                                style: TextStyle(
                                  color: _LC.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '₹${restaurant.otherPlatformAvg}/person',
                                style: const TextStyle(
                                  color: _LC.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Min order pill + View Menu CTA
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (restaurant.minOrder > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _LC.border),
                          ),
                          child: Text(
                            'Min ₹${restaurant.minOrder}',
                            style: const TextStyle(
                              color: _LC.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      const Spacer(),
                      // View Menu CTA
                      Row(
                        children: const [
                          Text(
                            'View Menu',
                            style: TextStyle(
                              color: _LC.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: _LC.accent,
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

  Widget _imagePlaceholder() => Container(
    width: double.infinity,
    height: 180,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF0EDE8), Color(0xFFE8E4DF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(Icons.restaurant_rounded, color: Color(0xFFD0C9C0), size: 44),
    ),
  );
}
