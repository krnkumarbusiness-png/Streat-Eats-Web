// lib/screens/sweets_screen.dart
// v4.0 — FINAL FIXED
// ✅ Vendors from 'vendors' table where business_type = 'sweets'
// ✅ Categories auto-generated from vendors' specialty_category field
// ✅ _TimerDivider class added (was missing — caused compile errors)
// ✅ All other features preserved

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../models/vendor_model.dart';
import 'vendor_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/vendor_card.dart';
import '../widgets/disclaimer_widget.dart';

// ── Local color palette ──────────────────────────────────────
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
  static const red = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
}

class SweetsScreen extends StatefulWidget {
  const SweetsScreen({super.key});

  @override
  State<SweetsScreen> createState() => _SweetsScreenState();
}

class _SweetsScreenState extends State<SweetsScreen>
    with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  final _locationService = LocationService();

  List<Map<String, dynamic>> _allVendors = [];
  List<Map<String, dynamic>> _filteredVendors = [];
  List<Map<String, dynamic>> _sweetCategories = [];

  bool _isLoading = true;
  String _selectedCategory = 'All';

  bool? _locationGranted;
  bool _locationServiceEnabled = true;

  bool _isWithinTime = true;
  bool _isTimingEnabled = false;
  bool get _isAppActive => !_isTimingEnabled || _isWithinTime;
  String _openTime = '17:00';
  Timer? _timingCheckTimer;

  // location
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppTiming();
    _init();
    _timingCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _checkAppTiming();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timingCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLocation();
  }

  // ── App Timing ────────────────────────────────────────────
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
      if (mounted) setState(() => _isWithinTime = true);
    }
  }

  // ── Location ──────────────────────────────────────────────
  Future<void> _checkLocation() async {
    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      final granted = await _locationService.hasPermission();
      if (!mounted) return;
      setState(() {
        _locationServiceEnabled = serviceEnabled;
        _locationGranted = granted;
      });
      if (granted && _userLat == null) _fetchLocationAndUpdate();
    } catch (_) {}
  }

  Future<void> _fetchLocationAndUpdate() async {
    final pos = await _locationService.getCurrentLocation();
    if (!mounted || pos == null) return;
    _userLat = pos.latitude;
    _userLng = pos.longitude;
    if (_allVendors.isNotEmpty) {
      for (var v in _allVendors) {
        if (v['latitude'] != null && v['longitude'] != null) {
          v['_distanceKm'] = _locationService.getDistanceKm(
            pos.latitude,
            pos.longitude,
            (v['latitude'] as num).toDouble(),
            (v['longitude'] as num).toDouble(),
          );
        }
      }
      _allVendors.sort(
        (a, b) => ((a['_distanceKm'] ?? 99.0) as double).compareTo(
          (b['_distanceKm'] ?? 99.0) as double,
        ),
      );
      if (mounted) setState(() => _applyFilter());
    }
  }

  Future<void> _init() async {
    await _checkLocation();
    if (_locationGranted == true) {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
    }
    await _loadData();
  }

  // ── Load Data ─────────────────────────────────────────────
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final vendorsRaw = await _supabase
          .from('vendors')
          .select()
          .eq('is_active', true)
          .eq('business_type', 'sweets');

      final vendors = List<Map<String, dynamic>>.from(
        vendorsRaw,
      ).map((v) => Map<String, dynamic>.from(v)).toList();

      if (_userLat != null && _userLng != null) {
        for (var v in vendors) {
          if (v['latitude'] != null && v['longitude'] != null) {
            v['_distanceKm'] = _locationService.getDistanceKm(
              _userLat!,
              _userLng!,
              (v['latitude'] as num).toDouble(),
              (v['longitude'] as num).toDouble(),
            );
          }
        }
        vendors.sort(
          (a, b) => ((a['_distanceKm'] ?? 99.0) as double).compareTo(
            (b['_distanceKm'] ?? 99.0) as double,
          ),
        );
      }

      final savedCatsMap = <String, String?>{};
      final catList = <String>[];
      try {
        final allSaved = await _supabase
            .from('food_categories')
            .select('name, image_url')
            .eq('category_type', 'sweets')
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        for (final r in (allSaved as List)) {
          final name = r['name'] as String? ?? '';
          final img = r['image_url'] as String?;
          if (name.isNotEmpty) {
            catList.add(name);
            savedCatsMap[name] = img;
          }
        }
      } catch (_) {}

      final cats = <Map<String, dynamic>>[
        {'name': 'All', 'emoji': '🍬', 'image_url': null},
        ...catList.map(
          (name) => <String, dynamic>{
            'name': name,
            'emoji': _catEmoji(name),
            'image_url': savedCatsMap[name],
          },
        ),
      ];

      if (!mounted) return;
      setState(() {
        _allVendors = vendors;
        _sweetCategories = cats;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Category emoji auto-assign ────────────────────────────
  String _catEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('mithai') || n.contains('sweet')) return '🍮';
    if (n.contains('barfi') || n.contains('burfi')) return '🍬';
    if (n.contains('halwa')) return '🍯';
    if (n.contains('ice') || n.contains('cream')) return '🍦';
    if (n.contains('cake')) return '🎂';
    if (n.contains('gulab') || n.contains('jamun')) return '🔴';
    if (n.contains('ladoo') || n.contains('laddoo')) return '🟡';
    if (n.contains('chocolate')) return '🍫';
    if (n.contains('rasgulla') || n.contains('rasgulle')) return '⚪';
    if (n.contains('jalebi')) return '🟠';
    if (n.contains('kheer')) return '🥛';
    if (n.contains('peda')) return '🟤';
    return '🍬';
  }

  // ── Filter ────────────────────────────────────────────────
  void _applyFilter() {
    if (_selectedCategory == 'All') {
      _filteredVendors = List.from(_allVendors);
    } else {
      _filteredVendors = _allVendors.where((v) {
        final specialty = (v['specialty_category'] as String? ?? '')
            .toLowerCase();
        final category = (v['category'] as String? ?? '').toLowerCase();
        final selected = _selectedCategory.toLowerCase();
        return specialty.contains(selected) || category.contains(selected);
      }).toList();
    }
  }

  void _onCategoryTap(String cat) {
    setState(() {
      _selectedCategory = cat;
      _applyFilter();
    });
  }

  // ── Location Banner Tap ───────────────────────────────────
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
      _fetchLocationAndUpdate();
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final showBanner = _locationGranted == false || !_locationServiceEnabled;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await _checkLocation();
          await _loadData();
        },
        color: _LC.accent,
        backgroundColor: _LC.surface,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Sticky Header
            SliverPersistentHeader(
              pinned: true,
              delegate: _SweetsHeaderDelegate(
                topPadding: topPadding,
                vendorCount: _allVendors.length,
              ),
            ),

            // Location banner
            if (showBanner)
              SliverToBoxAdapter(
                child: _LocationBanner(
                  serviceEnabled: _locationServiceEnabled,
                  onTap: _onLocationBannerTap,
                ),
              ),

            // Categories
            SliverToBoxAdapter(child: _buildCategories()),

            // Section header
            SliverToBoxAdapter(child: _buildSectionHeader()),

            // Content
            if (_isLoading)
              const SliverToBoxAdapter(child: _ShimmerGrid())
            else if (!_isAppActive)
              SliverToBoxAdapter(
                child: _SweetsClosedWidget(openTime: _openTime),
              )
            else if (_filteredVendors.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final vMap = _filteredVendors[i];
                    final distKm = vMap['_distanceKm'] as double?;
                    final vendor = VendorModel.fromMap(
                      Map<String, dynamic>.from(vMap),
                    );
                    if (distKm != null) vendor.distanceKm = distKm;
                    return VendorCard(
                      vendor: vendor,
                      onTap: () {
                        if (distKm != null && distKm > 0) {
                          context
                              .read<CartProvider>()
                              .setDeliveryChargeForDistance(distKm);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VendorDetailScreen(vendor: vendor),
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

  // ── Categories Widget ─────────────────────────────────────
  Widget _buildCategories() {
    if (_sweetCategories.isEmpty && !_isLoading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Categories 🍬',
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
          child: _sweetCategories.isEmpty
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _LC.accent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _sweetCategories.length,
                  itemBuilder: (_, i) {
                    final cat = _sweetCategories[i];
                    final name = cat['name'] as String? ?? '';
                    final emoji = cat['emoji'] as String? ?? '🍬';
                    final imgUrl = cat['image_url'] as String?;
                    final isSelected = _selectedCategory == name;

                    return GestureDetector(
                      onTap: () => _onCategoryTap(name),
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
                                color: isSelected
                                    ? _LC.accentLight
                                    : _LC.surface,
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
                                            style: const TextStyle(
                                              fontSize: 24,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 24),
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
                                color: isSelected
                                    ? _LC.accent
                                    : _LC.textSecondary,
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
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sweet Shops Near You 🍮',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userLat != null ? 'Sorted by distance' : 'Haldwani area',
                style: const TextStyle(
                  fontSize: 12,
                  color: _LC.textMuted,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          if (_filteredVendors.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _LC.accentLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _LC.accentBorder),
              ),
              child: Text(
                '${_filteredVendors.length} shops',
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
                child: Text('🍬', style: TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == 'All'
                  ? 'No sweet vendors found'
                  : 'No "$_selectedCategory" vendors found',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _LC.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedCategory == 'All'
                  ? 'Vendors will be added soon. Check back later!'
                  : 'Try another category or check back later',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _LC.textMuted,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedCategory != 'All') {
                  setState(() {
                    _selectedCategory = 'All';
                    _applyFilter();
                  });
                } else {
                  _loadData();
                }
              },
              icon: Icon(
                _selectedCategory != 'All'
                    ? Icons.clear_rounded
                    : Icons.refresh_rounded,
                size: 16,
              ),
              label: Text(
                _selectedCategory != 'All' ? 'Show All' : 'Try Again',
                style: const TextStyle(
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

// ── Header Delegate ──────────────────────────────────────────
class _SweetsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final int vendorCount;

  const _SweetsHeaderDelegate({
    required this.topPadding,
    required this.vendorCount,
  });

  static const double _h = 72.0;

  @override
  double get minExtent => topPadding + _h;
  @override
  double get maxExtent => topPadding + _h;

  @override
  bool shouldRebuild(_SweetsHeaderDelegate old) =>
      old.topPadding != topPadding || old.vendorCount != vendorCount;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: topPadding + _h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 14),
        child: Row(
          children: [
            const Text('🍬', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Sweets & Desserts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            if (vendorCount > 0)
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
                child: Text(
                  '$vendorCount shops',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
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
}

// ── Tag Pill ──────────────────────────────────────────────────
class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

// ── Location Banner ──────────────────────────────────────────
class _LocationBanner extends StatelessWidget {
  final bool serviceEnabled;
  final VoidCallback onTap;

  const _LocationBanner({required this.serviceEnabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                    serviceEnabled
                        ? 'Location permission not granted'
                        : 'Location service is off',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _LC.textPrimary,
                    ),
                  ),
                  Text(
                    serviceEnabled
                        ? 'Tap to allow location access'
                        : 'Turn on location in settings',
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

// ── Shimmer Grid ─────────────────────────────────────────────
class _ShimmerGrid extends StatefulWidget {
  const _ShimmerGrid();

  @override
  State<_ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<_ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
          animation: _anim,
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
                transform: GradientRotation(_anim.value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sweets Closed Widget ─────────────────────────────────────
class _SweetsClosedWidget extends StatefulWidget {
  final String openTime;
  const _SweetsClosedWidget({required this.openTime});

  @override
  State<_SweetsClosedWidget> createState() => _SweetsClosedWidgetState();
}

class _SweetsClosedWidgetState extends State<_SweetsClosedWidget> {
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ NAYA — proper illustration with fallback
              // ✅ NAYA — asset image, same style as restaurant
              Container(
                width: 90,
                height: 90,
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
                    'assets/images/illus_sleeping_chef.png', // 👈 same image as restaurant (ya sweets wali agar hai)
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Closed Right Now 🍬',
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
                textAlign: TextAlign.center,
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
                  const _TimerDivider(), // ✅ Fixed — class exists now
                  _TimerBox(value: m, label: 'MIN'),
                  const _TimerDivider(),
                  _TimerBox(value: s, label: 'SEC'),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _LC.accentLight,
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

// ── Timer Widgets ─────────────────────────────────────────────
class _TimerBox extends StatelessWidget {
  final String value;
  final String label;
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
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

// ✅ MISSING CLASS — Ye pehle cut off thi, isliye error tha
class _TimerDivider extends StatelessWidget {
  const _TimerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16, left: 6, right: 6),
      child: Text(
        ':',
        style: TextStyle(
          color: _LC.accent,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
