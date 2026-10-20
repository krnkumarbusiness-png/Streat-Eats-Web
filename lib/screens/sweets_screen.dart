// lib/screens/sweets_screen.dart
// v5.0 — Rakhi Festive Dynamic Supercharger
// ✅ Dynamic Festive Hero Banner (Admin controlled via app_settings)
// ✅ Interactive Custom Dabba Builder (Add & Remove item steppers + slot delete button)
// ✅ Dynamic Festive Best-Sellers horizontal carousel
// ✅ Vendors from 'vendors' table where business_type = 'sweets' (100% PRESERVED)
// ✅ Categories auto-generated from food_categories & vendors' specialty_category

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../services/menu_service.dart';
import '../models/vendor_model.dart';
import '../models/menu_item_model.dart';
import '../models/custom_box_item_model.dart';
import '../models/festive_deal_model.dart';
import 'vendor_detail_screen.dart';
import 'menu_item_detail_screen.dart';
import 'all_festive_deals_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../utils/cart_utils.dart';
import '../constants/app_snackbar.dart';
import '../widgets/vendor_card.dart';
import '../widgets/disclaimer_widget.dart';
import '../widgets/explore_item_card.dart';

// ── Local color palette ──────────────────────────────────────
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
  final _menuService = MenuService();

  List<Map<String, dynamic>> _allVendors = [];
  List<Map<String, dynamic>> _filteredVendors = [];
  List<Map<String, dynamic>> _sweetCategories = [];

  // ✅ Menu items map for Explore Menu style display
  Map<String, List<MenuItemModel>> _sweetMenuItemsMap = {};

  // ✅ Today's Trending Sweets (Admin controlled)
  List<MenuItemModel> _trendingSweets = [];
  bool _loadingTrendingSweets = true;
  bool _isTrendingSweetsEnabled = true;
  Map<String, int> _adminSweetsSortOrders = {};

  // Dynamic Festive Controls (Admin Managed via app_settings)
  bool _isFestiveBannerEnabled = true;
  String _festiveBannerTitle = 'Bhai-Behen Ka Meetha Pyar ❤️';
  String _festiveBannerSubtitle =
      'Custom Mithai Boxes + Free Designer Rakhi & Roli Chawal!';
  String _festiveCountdownText = 'Rakhi in 4 Days';
  bool _isCustomDabbaEnabled = true;
  bool _isFestiveBestsellersEnabled = true;

  List<FestiveDealModel> _festiveDeals = [];
  List<CustomBoxItemModel> _customBoxItems = [];

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

  static final VendorModel _centralSweetsVendor = VendorModel(
    id: 'streateats_sweets_central',
    name: 'StreatEats Festive Sweets',
    area: 'Central Sweets Kitchen',
    city: 'Haldwani',
    phone: '',
    latitude: 29.2183,
    longitude: 79.5130,
    category: 'Sweets & Hampers',
    timing: 'Open 8:00 AM - 10:00 PM',
    isActive: true,
    vendorType: 'both',
    businessType: 'sweets',
  );

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
            final open = enabledSlots[0]['open'] as String;
            final close = enabledSlots[0]['close'] as String;
            final openHour = int.tryParse(open.split(':')[0]) ?? 0;
            final closeHour = int.tryParse(close.split(':')[0]) ?? 0;
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
      // 1. Fetch Dynamic Festive Settings & Admin Sort Orders
      try {
        final settings = await _supabase
            .from('app_settings')
            .select(
              'is_festive_banner_enabled, festive_banner_title, '
              'festive_banner_subtitle, festive_countdown_text, '
              'is_custom_dabba_enabled, is_festive_bestsellers_enabled, '
              'is_sweets_trending_enabled, sweets_vendor_order, sweets_sort_orders',
            )
            .limit(1)
            .maybeSingle();

        if (settings != null) {
          _isFestiveBannerEnabled =
              settings['is_festive_banner_enabled'] as bool? ?? true;
          _festiveBannerTitle =
              settings['festive_banner_title'] as String? ??
              'Bhai-Behen Ka Meetha Pyar ❤️';
          _festiveBannerSubtitle =
              settings['festive_banner_subtitle'] as String? ??
              'Custom Mithai Boxes + Free Designer Rakhi & Roli Chawal!';
          _festiveCountdownText =
              settings['festive_countdown_text'] as String? ??
              'Rakhi in 4 Days';
          _isCustomDabbaEnabled =
              settings['is_custom_dabba_enabled'] as bool? ?? true;
          _isFestiveBestsellersEnabled =
              settings['is_festive_bestsellers_enabled'] as bool? ?? true;
          _isTrendingSweetsEnabled =
              settings['is_sweets_trending_enabled'] as bool? ?? true;

          final orderList = settings['sweets_vendor_order'];
          if (orderList is List) {
            final Map<String, int> sortOrders = {};
            for (int idx = 0; idx < orderList.length; idx++) {
              sortOrders[orderList[idx].toString()] = idx;
            }
            _adminSweetsSortOrders = sortOrders;
          }
        }
      } catch (_) {}

      // 2. Fetch Festive Deals
      try {
        final dealsData = await _supabase
            .from('festive_deals')
            .select()
            .eq('is_available', true)
            .order('display_order', ascending: true);
        final List<FestiveDealModel> deals = [];
        for (final r in dealsData) {
          deals.add(FestiveDealModel.fromMap(r));
        }
        _festiveDeals = deals;
      } catch (_) {
        _festiveDeals = _getFallbackFestiveDeals();
      }

      // 3. Fetch Custom Dabba Items
      try {
        final boxData = await _supabase
            .from('custom_box_items')
            .select()
            .eq('is_available', true)
            .order('display_order', ascending: true);
        final List<CustomBoxItemModel> items = [];
        for (final r in boxData) {
          items.add(CustomBoxItemModel.fromMap(r));
        }
        _customBoxItems = items;
      } catch (_) {
        _customBoxItems = _getFallbackCustomBoxItems();
      }

      // 4. Fetch Trending Sweets
      try {
        _trendingSweets = await _menuService.getTrendingSweetsItems();
        _loadingTrendingSweets = false;
      } catch (_) {
        _loadingTrendingSweets = false;
      }

      // 5. Fetch Sweet Menu Items Grouped by Vendor
      try {
        _sweetMenuItemsMap = await _menuService.fetchAllMenuItemsGrouped();
      } catch (_) {}

      // 6. Fetch Vendors (Preserved Intact)
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
      }

      // Sort with Admin Priority first, then distance
      vendors.sort((a, b) {
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        final nameA = a['name']?.toString() ?? '';
        final nameB = b['name']?.toString() ?? '';
        final orderA = _adminSweetsSortOrders[idA] ?? _adminSweetsSortOrders[nameA];
        final orderB = _adminSweetsSortOrders[idB] ?? _adminSweetsSortOrders[nameB];
        if (orderA != null && orderB != null) {
          return orderA.compareTo(orderB);
        } else if (orderA != null) {
          return -1;
        } else if (orderB != null) {
          return 1;
        }
        return ((a['_distanceKm'] ?? 99.0) as double).compareTo(
          (b['_distanceKm'] ?? 99.0) as double,
        );
      });

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

  List<FestiveDealModel> _getFallbackFestiveDeals() {
    return [
      FestiveDealModel(
        id: 'deal_1',
        title: 'Diamond Kaju Katli (Royal Box)',
        subtitle: '400g • Pure Cashew',
        price: 420,
        originalPrice: 499,
        badgeText: '⭐ Best Seller',
        imageUrl:
            'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80',
      ),
      FestiveDealModel(
        id: 'deal_2',
        title: 'Desi Ghee Motichoor Ladoo Box',
        subtitle: '500g • Kesar Infused',
        price: 280,
        originalPrice: 320,
        badgeText: '🎁 Rakhi Kit Free',
        imageUrl:
            'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=400&q=80',
      ),
      FestiveDealModel(
        id: 'deal_3',
        title: 'Royal Mawa Gulab Jamun Tin',
        subtitle: '1 kg • 16 Pcs',
        price: 340,
        originalPrice: 399,
        badgeText: '🔥 Hot Demand',
        imageUrl:
            'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=400&q=80',
      ),
      FestiveDealModel(
        id: 'deal_4',
        title: 'Sugar-Free Anjeer Dryfruit Roll',
        subtitle: '400g • Zero Added Sugar',
        price: 499,
        originalPrice: 599,
        badgeText: '✨ Sugar Free',
        imageUrl:
            'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400&q=80',
      ),
    ];
  }

  List<CustomBoxItemModel> _getFallbackCustomBoxItems() {
    return [
      CustomBoxItemModel(
        id: 'dabba_1',
        name: 'Diamond Kaju Katli',
        weightLabel: '125g',
        pricePerSlot: 110,
      ),
      CustomBoxItemModel(
        id: 'dabba_2',
        name: 'Desi Ghee Motichoor Ladoo',
        weightLabel: '125g',
        pricePerSlot: 75,
      ),
      CustomBoxItemModel(
        id: 'dabba_3',
        name: 'Dry Mawa Gulab Jamun',
        weightLabel: '125g',
        pricePerSlot: 85,
      ),
      CustomBoxItemModel(
        id: 'dabba_4',
        name: 'Besan Ladoo (Pure Ghee)',
        weightLabel: '125g',
        pricePerSlot: 80,
      ),
      CustomBoxItemModel(
        id: 'dabba_5',
        name: 'Kesar Peda',
        weightLabel: '125g',
        pricePerSlot: 90,
      ),
    ];
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
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = cat;
      _applyFilter();
    });
  }

  // ── Open Custom Dabba Modal Sheet ─────────────────────────
  void _openCustomDabbaSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CustomDabbaBottomSheet(
          availableSweets: _customBoxItems.isNotEmpty
              ? _customBoxItems
              : _getFallbackCustomBoxItems(),
          onPackAndAddToCart: (selectedItems, totalPrice) {
            _addCustomDabbaToCart(selectedItems, totalPrice);
          },
        );
      },
    );
  }

  void _addCustomDabbaToCart(
    List<CustomBoxItemModel> selectedItems,
    double totalPrice,
  ) {
    final names = selectedItems.map((e) => e.name).join(', ');

    // Use selected sweet image if available, else curated luxury assorted mithai box
    String dabbaImg = 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80';
    for (final item in selectedItems) {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        dabbaImg = item.imageUrl!;
        break;
      }
    }

    final dabbaItem = MenuItemModel(
      id: 'custom_dabba_${DateTime.now().millisecondsSinceEpoch}',
      vendorId: _centralSweetsVendor.id,
      vendorName: 'StreatEats Festive Sweets',
      name: '🎁 4-in-1 Custom Mithai Dabba (500g)',
      description: 'Assorted Box: $names',
      vendorPrice: totalPrice,
      appPrice: totalPrice,
      category: 'Custom Box',
      isAvailable: true,
      imageUrl: dabbaImg,
      isVeg: true,
    );

    CartUtils.handleCartAddItem(
      context,
      dabbaItem,
      _centralSweetsVendor,
      onSuccess: () {
        AppSnackBar.showSuccess(
          context,
          'Custom Mithai Dabba added to cart! 🎉',
        );
      },
      onLimitReached: () {
        AppSnackBar.showError(context, 'Cart limit reached!');
      },
    );
  }

  void _openFestiveDealDetail(FestiveDealModel deal) {
    HapticFeedback.lightImpact();
    VendorModel vendorToUse = _centralSweetsVendor;
    if (deal.vendorId != null) {
      final match =
          _allVendors.where((v) => v['id'] == deal.vendorId).firstOrNull;
      if (match != null) {
        vendorToUse = VendorModel.fromMap(Map<String, dynamic>.from(match));
      }
    }

    final dealItem = MenuItemModel(
      id: 'festive_deal_${deal.id}',
      vendorId: vendorToUse.id,
      vendorName: 'StreatEats Festive Sweets',
      name: deal.title,
      description: deal.subtitle ?? 'Festive Special Sweet Box',
      vendorPrice: deal.price,
      appPrice: deal.price,
      originalPrice: deal.originalPrice,
      isDiscounted:
          deal.originalPrice != null && deal.originalPrice! > deal.price,
      category: 'Festive Deals',
      isAvailable: true,
      imageUrl: deal.imageUrl,
      isVeg: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemDetailScreen(
          item: dealItem,
          vendor: vendorToUse,
        ),
      ),
    );
  }

  void _openAllFestiveDeals() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllFestiveDealsScreen(
          deals: _festiveDeals.isNotEmpty
              ? _festiveDeals
              : _getFallbackFestiveDeals(),
          allVendors: _allVendors,
        ),
      ),
    );
  }

  void _addFestiveDealToCart(FestiveDealModel deal) {
    HapticFeedback.mediumImpact();

    VendorModel vendorToUse = _centralSweetsVendor;
    if (deal.vendorId != null) {
      final match = _allVendors.where((v) => v['id'] == deal.vendorId).firstOrNull;
      if (match != null) {
        vendorToUse = VendorModel.fromMap(Map<String, dynamic>.from(match));
      }
    }

    final dealItem = MenuItemModel(
      id: 'festive_deal_${deal.id}',
      vendorId: vendorToUse.id,
      vendorName: 'StreatEats Festive Sweets',
      name: deal.title,
      description: deal.subtitle ?? 'Festive Special Sweet Box',
      vendorPrice: deal.price,
      appPrice: deal.price,
      originalPrice: deal.originalPrice,
      isDiscounted:
          deal.originalPrice != null && deal.originalPrice! > deal.price,
      category: 'Festive Deals',
      isAvailable: true,
      imageUrl: deal.imageUrl,
      isVeg: true,
    );

    CartUtils.handleCartAddItem(
      context,
      dealItem,
      vendorToUse,
      onSuccess: () {
        AppSnackBar.showSuccess(context, '${deal.title} added to cart!');
      },
      onLimitReached: () {
        AppSnackBar.showError(context, 'Cart limit reached!');
      },
    );
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

  void _openVendorDetail(VendorModel vendor) {
    HapticFeedback.lightImpact();
    if (vendor.distanceKm != null && vendor.distanceKm! > 0) {
      context.read<CartProvider>().setDeliveryChargeForDistance(
        vendor.distanceKm!,
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor)),
    );
  }

  void _openItemDetail(MenuItemModel item, VendorModel vendor) {
    HapticFeedback.lightImpact();
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
            // 1. Sticky Header
            SliverPersistentHeader(
              pinned: true,
              delegate: _SweetsHeaderDelegate(
                topPadding: topPadding,
                vendorCount: _allVendors.length,
              ),
            ),

            // 2. Location banner (if needed)
            if (showBanner)
              SliverToBoxAdapter(
                child: _LocationBanner(
                  serviceEnabled: _locationServiceEnabled,
                  onTap: _onLocationBannerTap,
                ),
              ),

            // 3. Categories (MOVED TO TOP RIGHT AFTER HEADER!)
            SliverToBoxAdapter(child: _buildCategories()),

            // 4. Dynamic Festive Hero Banner (Admin Managed)
            if (_isFestiveBannerEnabled)
              SliverToBoxAdapter(
                child: _FestiveHeroBanner(
                  title: _festiveBannerTitle,
                  subtitle: _festiveBannerSubtitle,
                  countdownText: _festiveCountdownText,
                  onBuildDabba: _openCustomDabbaSheet,
                ),
              ),

            // 5. Dynamic Custom Dabba Builder Card (Admin Managed)
            if (_isCustomDabbaEnabled)
              SliverToBoxAdapter(
                child: _CustomDabbaPromoCard(onTap: _openCustomDabbaSheet),
              ),

            // 6. Dynamic Festive Best-Sellers / Today's Trending Sweets
            if (_isFestiveBestsellersEnabled && _festiveDeals.isNotEmpty)
              SliverToBoxAdapter(
                child: _FestiveBestsellersRow(
                  festiveDeals: _festiveDeals,
                  onAddToCart: _addFestiveDealToCart,
                  onDealTap: _openFestiveDealDetail,
                  onViewAll: _openAllFestiveDeals,
                ),
              ),

            // 7. Section header (Preserved)
            SliverToBoxAdapter(child: _buildSectionHeader()),

            // 8. Sweet Vendors Explore-Menu Content
            if (_isLoading)
              const SliverToBoxAdapter(child: _ShimmerGrid())
            else if (!_isAppActive)
              SliverToBoxAdapter(
                child: _SweetsClosedWidget(openTime: _openTime),
              )
            else if (_filteredVendors.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              ..._buildSweetVendorExploreSlivers(),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: DisclaimerWidget()),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSweetVendorExploreSlivers() {
    final slivers = <Widget>[];

    for (final vMap in _filteredVendors) {
      final distKm = vMap['_distanceKm'] as double?;
      final vendor = VendorModel.fromMap(Map<String, dynamic>.from(vMap));
      if (distKm != null) vendor.distanceKm = distKm;

      final allVendorItems = _sweetMenuItemsMap[vendor.id] ?? [];
      List<MenuItemModel> displayItems = allVendorItems;
      if (_selectedCategory != 'All') {
        displayItems = allVendorItems.where((item) {
          final cats = item.category
              .split(',')
              .map((c) => c.trim().toLowerCase())
              .toList();
          final specialty = (vendor.specialtyCategory ?? '').toLowerCase();
          final selected = _selectedCategory.toLowerCase();
          return cats.contains(selected) || specialty.contains(selected);
        }).toList();
      }

      // Vendor Heading
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _LC.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vendor.name,
                              style: const TextStyle(
                                fontSize: 16,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _LC.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: _LC.green,
                                  ),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (vendor.distanceKm != null) ...[
                            Text(
                              '${vendor.distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _LC.textMuted,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(color: _LC.textMuted),
                            ),
                          ],
                          Text(
                            '${vendor.deliveryMinutes ?? 20} min',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _LC.textMuted,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (vendor.specialtyCategory != null &&
                              vendor.specialtyCategory!.isNotEmpty) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: _LC.textMuted),
                            ),
                            Text(
                              vendor.specialtyCategory!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _LC.warning,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openVendorDetail(vendor),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _LC.accentLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _LC.accentBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Visit Shop',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _LC.accent,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(width: 3),
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
        ),
      );

      if (displayItems.isEmpty) {
        // Fallback to vendor card if no items in this category
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: VendorCard(
                vendor: vendor,
                onTap: () => _openVendorDetail(vendor),
                layout: 'list',
              ),
            ),
          ),
        );
      } else {
        // 2-column Grid of items (up to 4 items)
        final itemsToShow = displayItems.take(4).toList();
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
                    item: itemsToShow[index],
                    onTap: () => _openItemDetail(itemsToShow[index], vendor),
                  );
                },
                childCount: itemsToShow.length,
              ),
            ),
          ),
        );

        if (displayItems.length > 4) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Center(
                  child: InkWell(
                    onTap: () => _openVendorDetail(vendor),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _LC.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _LC.border),
                      ),
                      child: Text(
                        'View all ${displayItems.length} items from ${vendor.name} →',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _LC.accent,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }

      // Divider between sweet shops
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            height: 1,
            color: _LC.border.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return slivers;
  }

  // ── Categories Widget (Preserved) ─────────────────────────
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
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _sweetCategories.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (ctx, i) {
              final cat = _sweetCategories[i];
              final name = cat['name'] as String? ?? '';
              final emoji = cat['emoji'] as String? ?? '🍬';
              final img = cat['image_url'] as String?;
              final isSel = _selectedCategory == name;

              return GestureDetector(
                onTap: () => _onCategoryTap(name),
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? _LC.accentLight : _LC.surface,
                          border: Border.all(
                            color: isSel ? _LC.accent : _LC.border,
                            width: isSel ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSel
                                  ? _LC.accent.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: img != null && img.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                                )
                              : Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? _LC.accent : _LC.textSecondary,
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

  // ── Section Header ───────────────────────────────────────
  Widget _buildSectionHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _LC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LC.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB703), Color(0xFFFF6B2B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: _LC.accent.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🏬',
                style: TextStyle(fontSize: 21),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedCategory == 'All'
                      ? 'Sweet Shops Nearby'
                      : '$_selectedCategory Shops',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: _LC.textPrimary,
                    fontFamily: 'Poppins',
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userLat != null && _userLng != null
                      ? '📍 Sorted by shortest delivery distance'
                      : '📍 Famous mithai shops in Haldwani',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _LC.textMuted,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_filteredVendors.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _LC.accentLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _LC.accentBorder),
              ),
              child: Text(
                '${_filteredVendors.length} places',
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Text('🍮', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'No sweet shops found for "$_selectedCategory"',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _LC.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FESTIVE HERO BANNER (Admin Controlled)
// ═══════════════════════════════════════════════════════════
class _FestiveHeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String countdownText;
  final VoidCallback onBuildDabba;

  const _FestiveHeroBanner({
    required this.title,
    required this.subtitle,
    required this.countdownText,
    required this.onBuildDabba,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C2D12), Color(0xFFB45309), Color(0xFFBE185D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB45309).withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm, color: Color(0xFFFEF08A), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      countdownText,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFEF08A),
                      ),
                    ),
                  ],
                ),
              ),
              const Text('✨', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFFFDE68A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onBuildDabba,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF991B1B),
                    size: 14,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Build Custom Dabba',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF991B1B),
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
}

// ═══════════════════════════════════════════════════════════
// CUSTOM DABBA PROMO CARD (Admin Controlled)
// ═══════════════════════════════════════════════════════════
class _CustomDabbaPromoCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CustomDabbaPromoCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Material(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B),
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Apna 4-in-1 Mithai Box Banao! 🎁',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kaju Katli + Gulab Jamun + Ladoo mix & match',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FESTIVE BESTSELLERS ROW (Admin Controlled)
// ═══════════════════════════════════════════════════════════
class _FestiveBestsellersRow extends StatelessWidget {
  final List<FestiveDealModel> festiveDeals;
  final ValueChanged<FestiveDealModel> onAddToCart;
  final ValueChanged<FestiveDealModel> onDealTap;
  final VoidCallback onViewAll;

  const _FestiveBestsellersRow({
    required this.festiveDeals,
    required this.onAddToCart,
    required this.onDealTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '✨ Festive Best-Sellers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _LC.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _LC.accent,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: _LC.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: festiveDeals.length,
            itemBuilder: (ctx, i) {
              final deal = festiveDeals[i];
              return GestureDetector(
                onTap: () => onDealTap(deal),
                child: Container(
                  width: 148,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _LC.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _LC.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with badge
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (deal.imageUrl != null &&
                                  deal.imageUrl!.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: deal.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _fallbackPlaceholder(),
                                )
                              else
                                _fallbackPlaceholder(),
                              Positioned(
                                top: 4,
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
                                    deal.badgeText,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFEF08A),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _LC.textPrimary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            if (deal.subtitle != null)
                              Text(
                                deal.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: _LC.textMuted,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${deal.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _LC.textPrimary,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                InkWell(
                                  onTap: () => onAddToCart(deal),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _LC.accentLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _LC.accentBorder,
                                      ),
                                    ),
                                    child: const Text(
                                      '+ ADD',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: _LC.accent,
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
    );
  }

  Widget _fallbackPlaceholder() {
    return Container(
      color: _LC.accentLight,
      child: const Center(
        child: Text('🍮', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CUSTOM DABBA BUILDER BOTTOM SHEET (WITH ADD & REMOVE)
// ═══════════════════════════════════════════════════════════
class _CustomDabbaBottomSheet extends StatefulWidget {
  final List<CustomBoxItemModel> availableSweets;
  final Function(List<CustomBoxItemModel> items, double totalPrice)
      onPackAndAddToCart;

  const _CustomDabbaBottomSheet({
    required this.availableSweets,
    required this.onPackAndAddToCart,
  });

  @override
  State<_CustomDabbaBottomSheet> createState() =>
      _CustomDabbaBottomSheetState();
}

class _CustomDabbaBottomSheetState extends State<_CustomDabbaBottomSheet> {
  // 4 slots (null = empty)
  final List<CustomBoxItemModel?> _slots = [null, null, null, null];

  double get _totalPrice => _slots.fold(
        0.0,
        (sum, item) => sum + (item?.pricePerSlot ?? 0.0),
      );

  int get _filledCount => _slots.where((s) => s != null).length;

  int _getItemCount(String name) {
    return _slots.where((s) => s != null && s.name == name).length;
  }

  void _addItem(CustomBoxItemModel sweet) {
    final emptyIndex = _slots.indexOf(null);
    if (emptyIndex == -1) {
      AppSnackBar.showWarning(
        context,
        'Box is full (4/4 slots)! Slot par ✕ click karke remove karein.',
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _slots[emptyIndex] = sweet;
    });
  }

  void _removeSlot(int index) {
    if (_slots[index] != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _slots[index] = null;
      });
    }
  }

  void _removeItemByName(String name) {
    for (int i = 3; i >= 0; i--) {
      if (_slots[i] != null && _slots[i]!.name == name) {
        HapticFeedback.lightImpact();
        setState(() {
          _slots[i] = null;
        });
        return;
      }
    }
  }

  void _packBox() {
    final filledItems = _slots.whereType<CustomBoxItemModel>().toList();
    if (filledItems.isEmpty) {
      AppSnackBar.showWarning(context, 'Please add at least 1 sweet to the box!');
      return;
    }
    widget.onPackAndAddToCart(filledItems, _totalPrice);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('🎁', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    '4-in-1 Mithai Box Builder',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _LC.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Sweets add ya remove karke apna 500g luxury assorted dabba taiyar karein:',
            style: TextStyle(fontSize: 11.5, color: _LC.textSecondary),
          ),
          const SizedBox(height: 12),

          // 4 Visual Slots Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Custom Box (500g)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    Text(
                      '$_filledCount / 4 Slots Filled',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _filledCount == 4
                            ? _LC.green
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(4, (i) {
                    final item = _slots[i];
                    final isFilled = item != null;
                    return Expanded(
                      child: Container(
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isFilled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFilled
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isFilled) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB45309),
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.weightLabel} • ₹${item.pricePerSlot.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: _LC.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () => _removeSlot(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: _LC.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              Text(
                                'Slot ${i + 1}\n(Empty)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Sweets Picker List
          const Text(
            'Select Sweets to Add:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _LC.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.availableSweets.length,
              itemBuilder: (ctx, i) {
                final sweet = widget.availableSweets[i];
                final count = _getItemCount(sweet.name);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sweet.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _LC.textPrimary,
                            ),
                          ),
                          Text(
                            '${sweet.weightLabel} • +₹${sweet.pricePerSlot.toStringAsFixed(0)} / slot',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _LC.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // - button
                          InkWell(
                            onTap: count > 0
                                ? () => _removeItemByName(sweet.name)
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? _LC.surface
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: count > 0
                                      ? const Color(0xFFCBD5E1)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.remove,
                                  size: 14,
                                  color: count > 0
                                      ? _LC.textPrimary
                                      : _LC.textMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 16,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // + button
                          InkWell(
                            onTap: () => _addItem(sweet),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _LC.accentLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _LC.accentBorder),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 14,
                                  color: _LC.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Pack & Add to Cart Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _filledCount > 0 ? _packBox : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                _filledCount > 0
                    ? 'Pack Dabba & Add to Cart (₹${_totalPrice.toStringAsFixed(0)})'
                    : 'Select sweets to pack box',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EXISTING HEADER, BANNER & TIMING WIDGETS (PRESERVED)
// ═══════════════════════════════════════════════════════════
class _SweetsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final int vendorCount;
  _SweetsHeaderDelegate({required this.topPadding, required this.vendorCount});

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
        boxShadow: shrinkOffset > 0
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
              Icons.cake_rounded,
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
                  'Mithai & Sweets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _LC.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  '$vendorCount sweet shops in Haldwani',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _LC.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: _LC.green, size: 13),
                SizedBox(width: 3),
                Text(
                  'Fresh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _LC.green,
                    fontFamily: 'Poppins',
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
  bool shouldRebuild(covariant _SweetsHeaderDelegate oldDelegate) =>
      oldDelegate.topPadding != topPadding ||
      oldDelegate.vendorCount != vendorCount;
}

class _LocationBanner extends StatelessWidget {
  final bool serviceEnabled;
  final VoidCallback onTap;
  const _LocationBanner({required this.serviceEnabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _LC.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _LC.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: _LC.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              serviceEnabled
                  ? 'Location permission denied. Distance accurate nahi dikhegi.'
                  : 'Location service band hai. Turn on karein.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'ENABLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF92400E),
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 100,
          decoration: BoxDecoration(
            color: _LC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _LC.border),
          ),
        ),
      ),
    );
  }
}

class _SweetsClosedWidget extends StatelessWidget {
  final String openTime;
  const _SweetsClosedWidget({required this.openTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _LC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _LC.border),
      ),
      child: Column(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'Sweet Shops Currently Closed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _LC.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We open next at $openTime. Pre-orders available!',
            style: const TextStyle(
              fontSize: 12,
              color: _LC.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
