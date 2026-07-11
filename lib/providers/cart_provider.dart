// lib/providers/cart_provider.dart
// v4.1 — Delivery Charge Fix
//
// FIX in v4.1:
//   ✅ _currentDistanceKm — properly stores distance set by any screen
//   ✅ setDeliveryChargeForDistance() — actually stores distance now (was empty!)
//   ✅ deliveryCharge getter — uses _currentDistanceKm as priority
//   ✅ addItem() — auto-updates distance from vendor.distanceKm if available
//   ✅ clearCart() — resets _currentDistanceKm
//   ✅ All v4.0 features 100% preserved (packaging fee, platform fee, address, slabs)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item_model.dart';
import '../models/vendor_model.dart';
import '../models/delivery_address_model.dart';

typedef PortionType = String?;

class CartItem {
  final MenuItemModel item;
  final VendorModel vendor;
  int quantity;
  final PortionType portionType;
  final double effectivePrice;
  final bool isFirstOrderDiscounted;

  CartItem({
    required this.item,
    required this.vendor,
    this.quantity = 1,
    this.portionType,
    double? effectivePrice,
    this.isFirstOrderDiscounted = false, // ✅ NEW
  }) : effectivePrice = effectivePrice ?? item.appPrice;

  String get cartKey {
    if (portionType == null) return item.id;
    return '${item.id}_$portionType';
  }

  double get totalPrice => effectivePrice * quantity;

  String get portionLabel {
    if (portionType == 'half') return 'Half';
    if (portionType == 'full') return 'Full';
    return '';
  }

  Map<String, dynamic> toJson() => {
    'item': {
      'id': item.id,
      'vendor_id': item.vendorId,
      'name': item.name,
      'description': item.description,
      'vendor_price': item.vendorPrice,
      'app_price': item.appPrice,
      'category': item.category,
      'is_available': item.isAvailable,
      'image_url': item.imageUrl,
      'is_veg': item.isVeg,
      'stock_status': item.stockStatus,
      'has_half_full': item.hasHalfFull,
      'half_price': item.halfPrice,
      'full_price': item.fullPrice,
    },
    'vendor': {
      'id': vendor.id,
      'name': vendor.name,
      'area': vendor.area,
      'city': vendor.city,
      'phone': vendor.phone,
      'latitude': vendor.latitude,
      'longitude': vendor.longitude,
      'category': vendor.category,
      'timing': vendor.timing,
      'vendor_type': vendor.vendorType,
      'is_active': vendor.isActive,
      'image_url': vendor.imageUrl,
      'distance_km': vendor.distanceKm,
    },
    'quantity': quantity,
    'portion_type': portionType,
    'effective_price': effectivePrice,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final itemData = json['item'] as Map<String, dynamic>;
    final vendorData = json['vendor'] as Map<String, dynamic>? ?? {};
    final portionType = json['portion_type'] as String?;
    final effectivePrice = (json['effective_price'] as num?)?.toDouble();

    VendorModel vendor;
    try {
      vendor = VendorModel.fromMap(vendorData);
      final savedDist = (vendorData['distance_km'] as num?)?.toDouble();
      if (savedDist != null) vendor.distanceKm = savedDist;
    } catch (_) {
      vendor = VendorModel(
        id: vendorData['id'] as String? ?? '',
        name: vendorData['name'] as String? ?? 'Unknown',
        area: vendorData['area'] as String? ?? '',
        phone: vendorData['phone'] as String? ?? '',
        city: vendorData['city'] as String? ?? 'Haldwani',
        latitude: (vendorData['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (vendorData['longitude'] as num?)?.toDouble() ?? 0,
        category: vendorData['category'] as String? ?? '',
        timing: vendorData['timing'] as String? ?? '',
        isActive: vendorData['is_active'] as bool? ?? true,
        imageUrl: vendorData['image_url'] as String?,
        vendorType: vendorData['vendor_type'] as String? ?? 'both',
      );
    }

    final item = MenuItemModel(
      id: itemData['id'] as String,
      vendorId: itemData['vendor_id'] as String,
      name: itemData['name'] as String,
      description: itemData['description'] as String? ?? '',
      vendorPrice: (itemData['vendor_price'] as num).toDouble(),
      appPrice: (itemData['app_price'] as num).toDouble(),
      category: itemData['category'] as String? ?? '',
      isAvailable: itemData['is_available'] as bool? ?? true,
      imageUrl: itemData['image_url'] as String?,
      isVeg: itemData['is_veg'] as bool? ?? true,
      stockStatus: itemData['stock_status'] as String? ?? 'available',
      hasHalfFull: itemData['has_half_full'] as bool? ?? false,
      halfPrice: (itemData['half_price'] as num?)?.toDouble(),
      fullPrice: (itemData['full_price'] as num?)?.toDouble(),
    );

    return CartItem(
      item: item,
      vendor: vendor,
      quantity: json['quantity'] as int,
      portionType: portionType,
      effectivePrice: effectivePrice,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  // ── v4.0: Selected delivery address ─────────────────────────
  DeliveryAddress? _selectedDeliveryAddress;

  DeliveryAddress? get selectedDeliveryAddress => _selectedDeliveryAddress;

  void setDeliveryAddress(DeliveryAddress address) {
    _selectedDeliveryAddress = address;
    _confirmedPinDistanceKm =
        null; // ✅ naya address = purana pin distance invalid
    notifyListeners();
  }

  void clearDeliveryAddress() {
    _selectedDeliveryAddress = null;
    notifyListeners();
  }

  // ── v4.1 FIX: Explicit distance store ───────────────────────
  // Ye variable home screen / item detail screen set karta hai
  // taaki cart mein correct delivery charge calculate ho
  double? _currentDistanceKm;

  /// Distance explicitly set karo (home screen ya item detail se)
  /// Ye sabse pehle check hoga deliveryCharge mein
  void setDeliveryChargeForDistance(double distanceKm) {
    _currentDistanceKm = distanceKm;
    notifyListeners();
  }

  /// Current stored distance (debug ke liye useful)
  double? get currentDistanceKm => _currentDistanceKm;

  // ── v4.2 FIX: Explicit "confirmed pin" distance ─────────────
  // Sirf checkout screen set karta hai jab user map pe exact pin
  // confirm karta hai. Ye sabse high priority hai deliveryCharge mein
  // kyunki ye sabse accurate hota hai.
  double? _confirmedPinDistanceKm;

  double? get confirmedPinDistanceKm => _confirmedPinDistanceKm;

  /// Checkout se call hota hai jab user map pe exact location confirm kare
  void setConfirmedDeliveryDistance(double distanceKm) {
    _confirmedPinDistanceKm = distanceKm;
    notifyListeners();
  }

  // ── Fee settings ─────────────────────────────────────────────
  double _platformFee = 5.0;
  double _deliveryCharge0_1 = 0;
  double _deliveryCharge1_2 = 10;
  double _deliveryCharge2_3 = 20;
  double _deliveryCharge3_4 = 30;
  double _deliveryCharge4_5 = 40;
  double _deliveryCharge5Plus = 50;

  // v3.0 — Packaging fee slabs
  double _packagingFee0_99 = 2.0;
  double _packagingFee100_199 = 5.0;
  double _packagingFee200Plus = 8.0;

  // v4.0 — Fallback km for manual address (uses max slab charge)
  static const double _manualAddressFallbackKm = 4.5;
  // ── Cart Limits ──────────────────────────────────────────────
  static const int maxTotalItems = 20;
  static const double maxOrderValue = 5000.0;

  bool _settingsLoaded = false;

  Map<String, CartItem> get items => _items;

  VendorModel? get currentVendor =>
      _items.isEmpty ? null : _items.values.first.vendor;

  List<VendorModel> get vendors {
    final seen = <String>{};
    final result = <VendorModel>[];
    for (final ci in _items.values) {
      if (!seen.contains(ci.vendor.id)) {
        seen.add(ci.vendor.id);
        result.add(ci.vendor);
      }
    }
    return result;
  }

  int get totalItems => _items.values.fold(0, (sum, ci) => sum + ci.quantity);

  double get subtotal =>
      _items.values.fold(0.0, (sum, ci) => sum + ci.totalPrice);

  double get platformFee => _items.isEmpty ? 0 : _platformFee;

  // v3.0 — Packaging fee (subtotal based slab)
  // Multi-vendor: har vendor ke items ka subtotal alag calculate karo
  // Phir har vendor ki packaging fee add karo
  double get packagingFee {
    if (_items.isEmpty) return 0;
    final uniqueVendorIds = _items.values.map((ci) => ci.vendor.id).toSet();
    if (uniqueVendorIds.length <= 1) {
      // Single vendor — existing behaviour
      final sub = subtotal;
      if (sub < 100) return _packagingFee0_99;
      if (sub < 200) return _packagingFee100_199;
      return _packagingFee200Plus;
    }
    // Multi-vendor: har vendor ka alag packaging fee
    double total = 0;
    for (final vendorId in uniqueVendorIds) {
      final vendorSubtotal = _items.values
          .where((ci) => ci.vendor.id == vendorId)
          .fold(0.0, (sum, ci) => sum + ci.totalPrice);
      if (vendorSubtotal < 100) {
        total += _packagingFee0_99;
      } else if (vendorSubtotal < 200) {
        total += _packagingFee100_199;
      } else {
        total += _packagingFee200Plus;
      }
    }
    return total;
  }

  // ── FIXED: deliveryCharge — multi-vendor sum ─────────────────
  //
  // Multi-vendor logic:
  //   - Har unique vendor ka alag delivery charge calculate karo
  //   - Saare charges add karo — 20+20 = 40
  //   - Single vendor case mein same behaviour as before
  //
  // Priority for per-vendor distance:
  //   1. _confirmedPinDistanceKm — checkout map pin (single distance, sabse accurate)
  //      Multi-vendor mein ye use nahi hota — per-vendor distance use hoti hai
  //   2. Manual address — fallback km (safe max slab) × vendor count
  //   3. vendor.distanceKm from cart items
  //   4. _currentDistanceKm — single vendor fallback
  //   5. 0
  double get deliveryCharge {
    if (_items.isEmpty) return 0;

    final addr = _selectedDeliveryAddress;
    final uniqueVendors = vendors; // List<VendorModel> — unique vendors

    // ── Manual address: fallback slab × vendor count ────────────
    if (addr != null && addr.isManual) {
      double total = 0;
      for (int i = 0; i < uniqueVendors.length; i++) {
        total += calculateDeliveryCharge(_manualAddressFallbackKm);
      }
      return total;
    }

    // ── Confirmed pin (checkout map) — per-vendor distance calculate karo ──
    // _confirmedPinDistanceKm = customer ka exact location distance from farthest vendor
    // Multi-vendor mein: har vendor ki individual distance chahiye
    // Lekin pin se per-vendor distance available nahi hai (sirf max tha)
    // Toh: vendor.distanceKm use karo agar available ho, warna confirmed pin ka charge
    if (_confirmedPinDistanceKm != null && _confirmedPinDistanceKm! > 0) {
      // Check karo: kya saare vendors ki individual distanceKm available hai?
      final allHaveDist = uniqueVendors.every(
        (v) => v.distanceKm != null && v.distanceKm! > 0,
      );
      if (allHaveDist) {
        // Har vendor ka alag charge add karo
        double total = 0;
        for (final v in uniqueVendors) {
          total += calculateDeliveryCharge(v.distanceKm!);
        }
        return total;
      }
      // Individual distances nahi hain — confirmed pin ka charge × vendor count
      return calculateDeliveryCharge(_confirmedPinDistanceKm!) *
          uniqueVendors.length;
    }

    // ── GPS address with known distance ─────────────────────────
    if (addr != null && addr.isGps && addr.distanceKm != null) {
      final allHaveDist = uniqueVendors.every(
        (v) => v.distanceKm != null && v.distanceKm! > 0,
      );
      if (allHaveDist) {
        double total = 0;
        for (final v in uniqueVendors) {
          total += calculateDeliveryCharge(v.distanceKm!);
        }
        return total;
      }
      return calculateDeliveryCharge(addr.distanceKm!) * uniqueVendors.length;
    }

    // ── vendor.distanceKm available hai — har vendor ka alag charge ──
    final allHaveDist = uniqueVendors.every(
      (v) => v.distanceKm != null && v.distanceKm! > 0,
    );
    if (allHaveDist) {
      double total = 0;
      for (final v in uniqueVendors) {
        total += calculateDeliveryCharge(v.distanceKm!);
      }
      return total;
    }

    // ── Partial: kuch vendors ki distance available, kuch ki nahi ──
    // Jo available hai unka charge lo, baaki ke liye _currentDistanceKm fallback
    double total = 0;
    bool anyDist = false;
    for (final v in uniqueVendors) {
      final d = v.distanceKm ?? 0;
      if (d > 0) {
        total += calculateDeliveryCharge(d);
        anyDist = true;
      } else if (_currentDistanceKm != null && _currentDistanceKm! > 0) {
        total += calculateDeliveryCharge(_currentDistanceKm!);
        anyDist = true;
      }
    }
    if (anyDist) return total;

    // ── Last resort fallback ─────────────────────────────────────
    if (_currentDistanceKm != null && _currentDistanceKm! > 0) {
      return calculateDeliveryCharge(_currentDistanceKm!) *
          uniqueVendors.length;
    }

    return calculateDeliveryCharge(0);
  }

  // ── Farthest vendor distance (for display in cart screen) ──
  double get farthestVendorDistanceKm {
    if (_items.isEmpty) return 0;

    final addr = _selectedDeliveryAddress;
    if (addr != null && addr.isGps && addr.distanceKm != null) {
      return addr.distanceKm!;
    }
    if (_currentDistanceKm != null && _currentDistanceKm! > 0) {
      return _currentDistanceKm!;
    }

    double maxDist = 0;
    for (final ci in _items.values) {
      final d = ci.vendor.distanceKm ?? 0;
      if (d > maxDist) maxDist = d;
    }
    return maxDist;
  }

  // ── Unique vendor count in cart ────────────────────────────
  int get uniqueVendorCount {
    final ids = _items.values.map((ci) => ci.vendor.id).toSet();
    return ids.length;
  }

  // v3.0 — total includes packaging fee
  double get total =>
      subtotal + platformFee + deliveryCharge + packagingFee + _tipAmount;

  // ── Single source of truth for cash round-off ──────────────────
  // Applied identically for COD and Online so the displayed total
  // never mismatches between payment methods or screens
  double get cashRoundOff {
    final rounded = total.roundToDouble();
    return rounded - total;
  }

  double get roundedTotal => total.roundToDouble();

  // ── Tip Amount ───────────────────────────────────────────────
  int _tipAmount = 0;
  int get tipAmount => _tipAmount;

  void setTip(int amount) {
    _tipAmount = amount;
    notifyListeners();
  }

  // Referral discount = sum of all markup (app_price - vendor_price) × quantity
  // Only applied when valid referral code is entered on first order
  double get totalMarkupAmount {
    double markup = 0.0;
    for (final ci in _items.values) {
      final m = (ci.item.appPrice - ci.item.vendorPrice) * ci.quantity;
      if (m > 0) markup += m;
    }
    return markup;
  }

  bool get isEmpty => _items.isEmpty;

  int getQuantity(String itemId, {PortionType portionType}) {
    final key = portionType == null ? itemId : '${itemId}_$portionType';
    return _items[key]?.quantity ?? 0;
  }

  int getTotalQuantity(String itemId) {
    int total = 0;
    for (final entry in _items.entries) {
      if (entry.value.item.id == itemId) {
        total += entry.value.quantity;
      }
    }
    return total;
  }

  String _cartKey(String userId) => 'se_cart_v2_$userId';
  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  double calculateDeliveryCharge(double distanceKm) {
    if (distanceKm <= 1) return _deliveryCharge0_1;
    if (distanceKm <= 2) return _deliveryCharge1_2;
    if (distanceKm <= 3) return _deliveryCharge2_3;
    if (distanceKm <= 4) return _deliveryCharge3_4;
    if (distanceKm <= 5) return _deliveryCharge4_5;
    return _deliveryCharge5Plus;
  }

  Future<void> loadSettings() async {
    if (_settingsLoaded) return;
    await _fetchSettingsFromDB();
  }

  Future<void> reloadSettings() async {
    _settingsLoaded = false;
    await _fetchSettingsFromDB();
  }

  Future<void> _fetchSettingsFromDB() async {
    try {
      final data = await Supabase.instance.client
          .from('app_settings')
          .select(
            'platform_fee, delivery_charge_0_1, delivery_charge_1_2, '
            'delivery_charge_2_3, delivery_charge_3_4, '
            'delivery_charge_4_5, delivery_charge_5_plus, '
            'packaging_fee_0_99, packaging_fee_100_199, packaging_fee_200_plus',
          )
          .limit(1)
          .maybeSingle();

      if (data != null) {
        _platformFee = (data['platform_fee'] as num?)?.toDouble() ?? 5.0;
        _deliveryCharge0_1 =
            (data['delivery_charge_0_1'] as num?)?.toDouble() ?? 0;
        _deliveryCharge1_2 =
            (data['delivery_charge_1_2'] as num?)?.toDouble() ?? 10;
        _deliveryCharge2_3 =
            (data['delivery_charge_2_3'] as num?)?.toDouble() ?? 20;
        _deliveryCharge3_4 =
            (data['delivery_charge_3_4'] as num?)?.toDouble() ?? 30;
        _deliveryCharge4_5 =
            (data['delivery_charge_4_5'] as num?)?.toDouble() ?? 40;
        _deliveryCharge5Plus =
            (data['delivery_charge_5_plus'] as num?)?.toDouble() ?? 50;

        // v3.0 — Packaging fee
        _packagingFee0_99 =
            (data['packaging_fee_0_99'] as num?)?.toDouble() ?? 2.0;
        _packagingFee100_199 =
            (data['packaging_fee_100_199'] as num?)?.toDouble() ?? 5.0;
        _packagingFee200Plus =
            (data['packaging_fee_200_plus'] as num?)?.toDouble() ?? 8.0;

        _settingsLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('CartProvider settings error: $e');
    }
  }

  Future<void> _updateCartTimestamp() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'cart_updated_at': DateTime.now().toIso8601String(),
            'abandoned_cart_notified': false,
          })
          .eq('id', userId);
    } catch (e) {
      debugPrint('Cart timestamp update error: $e');
    }
  }

  bool addItem(
    MenuItemModel item,
    VendorModel vendor, {
    PortionType portionType,
    double? effectivePrice,
  }) {
    final price =
        effectivePrice ??
        (portionType == 'half'
            ? (item.halfPrice ?? item.appPrice)
            : portionType == 'full'
            ? (item.fullPrice ?? item.appPrice)
            : item.appPrice);

    final key = portionType == null ? item.id : '${item.id}_$portionType';
    final isExisting = _items.containsKey(key);

    // ✅ Quantity limit check
    if (totalItems >= maxTotalItems) return false;

    // ✅ Price limit — sirf naya item add hone pe check karo
    if (!isExisting && (subtotal + price > maxOrderValue)) return false;

    if (_items.containsKey(key)) {
      _items[key]!.quantity++;
    } else {
      _items[key] = CartItem(
        item: item,
        vendor: vendor,
        portionType: portionType,
        effectivePrice: price,
      );
    }

    // ✅ v4.1 FIX: Item add hote time vendor ka distanceKm bhi sync karo
    // Agar vendor mein distanceKm hai aur _currentDistanceKm set nahi hai
    // ya vendor ki distance zyada accurate hai, to use set karo
    final vendorDist = vendor.distanceKm;
    if (vendorDist != null && vendorDist > 0) {
      // Sirf tab override karo jab _currentDistanceKm null ho
      // (matlab explicitly set distance ko preserve karo)
      _currentDistanceKm ??= vendorDist;
    }

    _saveCartToPrefs();
    _updateCartTimestamp();
    notifyListeners();
    return true;
  }

  void forceAddItem(
    MenuItemModel item,
    VendorModel vendor, {
    PortionType portionType,
    double? effectivePrice,
  }) {
    _items.clear();
    _currentDistanceKm = null; // ✅ Reset distance on force clear
    final price =
        effectivePrice ??
        (portionType == 'half'
            ? (item.halfPrice ?? item.appPrice)
            : portionType == 'full'
            ? (item.fullPrice ?? item.appPrice)
            : item.appPrice);
    final key = portionType == null ? item.id : '${item.id}_$portionType';
    _items[key] = CartItem(
      item: item,
      vendor: vendor,
      portionType: portionType,
      effectivePrice: price,
    );

    // ✅ v4.1: Force add pe bhi distance sync karo
    final vendorDist = vendor.distanceKm;
    if (vendorDist != null && vendorDist > 0) {
      _currentDistanceKm = vendorDist;
    }

    _saveCartToPrefs();
    _updateCartTimestamp();
    notifyListeners();
  }

  void removeItem(String itemId, {PortionType portionType}) {
    final key = portionType == null ? itemId : '${itemId}_$portionType';
    if (!_items.containsKey(key)) return;

    if (_items[key]!.quantity > 1) {
      _items[key]!.quantity--;
    } else {
      _items.remove(key);
    }
    _saveCartToPrefs();
    if (_items.isEmpty) {
      _currentDistanceKm = null; // ✅ Reset distance when cart empty
      _clearCartTimestamp();
    } else {
      _updateCartTimestamp();
    }
    notifyListeners();
  }

  void removeAllOfItem(String itemId, {PortionType portionType}) {
    final key = portionType == null ? itemId : '${itemId}_$portionType';
    _items.remove(key);
    if (_items.isEmpty) {
      _currentDistanceKm = null; // ✅ Reset distance when cart empty
      _clearCartTimestamp();
    }
    _saveCartToPrefs();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _currentDistanceKm = null;
    _confirmedPinDistanceKm = null;
    _selectedDeliveryAddress = null;
    _tipAmount = 0; // ✅ Reset tip on cart clear
    _clearCartPrefs();
    _clearCartTimestamp();
    notifyListeners();
  }

  Future<void> _clearCartTimestamp() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'cart_updated_at': null, 'abandoned_cart_notified': false})
          .eq('id', userId);
    } catch (_) {}
  }

  Future<void> _saveCartToPrefs() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = _items.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_cartKey(userId), jsonEncode(itemsJson));
    } catch (e) {
      debugPrint('Cart save error: $e');
    }
  }

  Future<void> restoreCart() async {
    final userId = _currentUserId;
    if (userId == null) {
      _items.clear();
      notifyListeners();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString(_cartKey(userId));
      if (cartStr != null) {
        final cartJson = jsonDecode(cartStr) as Map<String, dynamic>;
        _items.clear();
        _currentDistanceKm = null;
        cartJson.forEach((k, v) {
          try {
            final ci = CartItem.fromJson(v as Map<String, dynamic>);
            _items[ci.cartKey] = ci;
          } catch (e) {
            debugPrint('Cart item restore error: $e');
          }
        });

        // ✅ v4.1: Restore karte time bhi distance recover karo vendor se
        if (_items.isNotEmpty) {
          double maxDist = 0;
          for (final ci in _items.values) {
            final d = ci.vendor.distanceKm ?? 0;
            if (d > maxDist) maxDist = d;
          }
          if (maxDist > 0) _currentDistanceKm = maxDist;
        }

        await loadSettings();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Cart restore error: $e');
      await _clearCartPrefs();
    }
  }

  Future<void> clearCartOnLogout() async {
    final userId = _currentUserId;
    _items.clear();
    _currentDistanceKm = null;
    _confirmedPinDistanceKm = null;
    _selectedDeliveryAddress = null;
    _tipAmount = 0; // ✅ Reset tip on logout
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cartKey(userId));
        await _clearCartTimestamp();
      } catch (e) {
        debugPrint('Cart logout clear error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _clearCartPrefs() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey(userId));
    } catch (e) {
      debugPrint('Cart clear prefs error: $e');
    }
  }
}
