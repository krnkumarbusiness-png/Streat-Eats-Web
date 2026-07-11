import 'dart:math' show Random, sin, cos, sqrt, atan2;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../providers/cart_provider.dart';
import '../models/vendor_model.dart';
import 'push_notification_sender.dart';

class OrderService {
  final _client = Supabase.instance.client;

  Map<String, dynamic>? _cachedSettings;

  Future<Map<String, dynamic>> _getSettings() async {
    if (_cachedSettings != null) return _cachedSettings!;
    try {
      // NAYA
      final response = await _client
          .from('app_settings')
          .select(
            'platform_fee, '
            'delivery_charge_0_1, delivery_charge_1_2, '
            'delivery_charge_2_3, delivery_charge_3_4, '
            'delivery_charge_4_5, '
            'delivery_charge_extra_per_km, '
            'rider_payout_0_1, rider_payout_1_2, '
            'rider_payout_2_3, rider_payout_3_4, '
            'rider_payout_4_5, rider_payout_extra_per_km, '
            'max_delivery_km, '
            'is_timing_enabled, open_time, close_time, time_slots, '
            'packaging_enabled, packaging_fee_0_99, '
            'packaging_fee_100_199, packaging_fee_200_plus',
          )
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _cachedSettings = response;
        return _cachedSettings!;
      }
    } catch (_) {}

    return {
      'platform_fee': 5,
      'delivery_charge_0_1': 18,
      'delivery_charge_1_2': 28,
      'delivery_charge_2_3': 38,
      'delivery_charge_3_4': 48,
      'delivery_charge_4_5': 58,
      'delivery_charge_5_plus': 58,
      'delivery_charge_extra_per_km': 10,
      'rider_payout_0_1': 15,
      'rider_payout_1_2': 22,
      'rider_payout_2_3': 30,
      'rider_payout_3_4': 38,
      'rider_payout_4_5': 46,
      'rider_payout_extra_per_km': 8,
      'max_delivery_km': 10,
    };
  }

  Future<int> getDeliveryCharge(double distanceKm) async {
    final s = await _getSettings();
    if (distanceKm <= 1) {
      return (s['delivery_charge_0_1'] as num?)?.toInt() ?? 18;
    }
    if (distanceKm <= 2) {
      return (s['delivery_charge_1_2'] as num?)?.toInt() ?? 28;
    }
    if (distanceKm <= 3) {
      return (s['delivery_charge_2_3'] as num?)?.toInt() ?? 38;
    }
    if (distanceKm <= 4) {
      return (s['delivery_charge_3_4'] as num?)?.toInt() ?? 48;
    }
    if (distanceKm <= 5) {
      return (s['delivery_charge_4_5'] as num?)?.toInt() ?? 58;
    }
    final base = (s['delivery_charge_4_5'] as num?)?.toInt() ?? 58;
    final perKm = (s['delivery_charge_extra_per_km'] as num?)?.toInt() ?? 10;
    final extraKm = (distanceKm - 5).ceil();
    return base + (perKm * extraKm);
  }

  // Rider payout — rider ko actually ye milta hai, platform margin rakhta hai
  Future<int> getRiderPayout(double distanceKm) async {
    final s = await _getSettings();
    if (distanceKm <= 1) {
      return (s['rider_payout_0_1'] as num?)?.toInt() ?? 15;
    }
    if (distanceKm <= 2) {
      return (s['rider_payout_1_2'] as num?)?.toInt() ?? 22;
    }
    if (distanceKm <= 3) {
      return (s['rider_payout_2_3'] as num?)?.toInt() ?? 30;
    }
    if (distanceKm <= 4) {
      return (s['rider_payout_3_4'] as num?)?.toInt() ?? 38;
    }
    if (distanceKm <= 5) {
      return (s['rider_payout_4_5'] as num?)?.toInt() ?? 46;
    }
    final base = (s['rider_payout_4_5'] as num?)?.toInt() ?? 46;
    final perKm = (s['rider_payout_extra_per_km'] as num?)?.toInt() ?? 8;
    final extraKm = (distanceKm - 5).ceil();
    return base + (perKm * extraKm);
  }

  Future<int> getPlatformFee() async {
    final s = await _getSettings();
    return (s['platform_fee'] as num?)?.toInt() ?? 5;
  }

  void invalidateSettingsCache() {
    _cachedSettings = null;
  }

  // ── App Open Check ──────────────────────────────────────
  // Time slots JSONB check karta hai — multiple slots support
  // Fallback: single open_time/close_time columns
  Future<bool> isAppOpen() async {
    try {
      final data = await _client
          .from('app_settings')
          .select('is_timing_enabled, open_time, close_time, time_slots')
          .limit(1)
          .maybeSingle();

      if (data == null) return true;

      final timingEnabled = data['is_timing_enabled'] as bool? ?? true;
      if (!timingEnabled) return true;

      final now = TimeOfDay.now();
      final nowMin = now.hour * 60 + now.minute;

      // ── Multi-slot check ────────────────────────────────
      final slotsRaw = data['time_slots'];
      if (slotsRaw != null) {
        final slots = slotsRaw as List<dynamic>;
        for (final slot in slots) {
          final enabled = slot['enabled'] as bool? ?? true;
          if (!enabled) continue;
          final openStr = slot['open'] as String? ?? '17:00';
          final closeStr = slot['close'] as String? ?? '21:00';
          if (_timeInRange(nowMin, openStr, closeStr)) return true;
        }
        // Koi bhi slot match nahi hua
        return false;
      }

      // ── Single slot fallback ────────────────────────────
      final openStr = data['open_time'] as String? ?? '17:00';
      final closeStr = data['close_time'] as String? ?? '21:00';
      return _timeInRange(nowMin, openStr, closeStr);
    } catch (_) {
      return true; // DB error pe block mat karo
    }
  }

  // SAHI
  Future<double> getPackagingFee(double subtotal) async {
    final s = await _getSettings();
    final enabled = s['packaging_enabled'] as bool? ?? false;
    if (!enabled) return 0.0;
    if (subtotal < 100) {
      return (s['packaging_fee_0_99'] as num?)?.toDouble() ?? 0.0;
    } else if (subtotal < 200) {
      return (s['packaging_fee_100_199'] as num?)?.toDouble() ?? 0.0;
    } else {
      return (s['packaging_fee_200_plus'] as num?)?.toDouble() ?? 0.0;
    }
  }

  // Next open time return karta hai — "Band hai, X baje khulega"
  Future<String> getNextOpenTime() async {
    try {
      final data = await _client
          .from('app_settings')
          .select('is_timing_enabled, open_time, time_slots')
          .limit(1)
          .maybeSingle();

      if (data == null) return '17:00';

      final timingEnabled = data['is_timing_enabled'] as bool? ?? true;
      if (!timingEnabled) return '';

      final now = TimeOfDay.now();
      final nowMin = now.hour * 60 + now.minute;

      final slotsRaw = data['time_slots'];
      if (slotsRaw != null) {
        final slots = slotsRaw as List<dynamic>;
        // Aaj ke baad wala pehla enabled slot dhundo
        // Find the next upcoming slot from now
        String? nextTime;
        int? nextMin;

        // Pass 1: Find next slot today whose open time is still in the future
        for (final slot in slots) {
          final enabled = slot['enabled'] as bool? ?? true;
          if (!enabled) continue;
          final openStr = slot['open'] as String? ?? '17:00';
          final parts = openStr.split(':');
          final slotMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          // Only pick slots that haven't opened yet
          if (slotMin > nowMin) {
            if (nextMin == null || slotMin < nextMin) {
              nextMin = slotMin;
              nextTime = openStr;
            }
          }
        }

        // Pass 2: No future slot today — return earliest slot (for tomorrow)
        if (nextTime == null && slots.isNotEmpty) {
          int? earliestMin;
          for (final slot in slots) {
            final enabled = slot['enabled'] as bool? ?? true;
            if (!enabled) continue;
            final openStr = slot['open'] as String? ?? '17:00';
            final parts = openStr.split(':');
            final slotMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
            if (earliestMin == null || slotMin < earliestMin) {
              earliestMin = slotMin;
              nextTime = openStr;
            }
          }
        }

        return nextTime ?? '17:00';
      }

      return data['open_time'] as String? ?? '17:00';
    } catch (_) {
      return '17:00';
    }
  }

  bool _timeInRange(int nowMin, String openStr, String closeStr) {
    try {
      final op = openStr.split(':');
      final cl = closeStr.split(':');
      final openMin = int.parse(op[0]) * 60 + int.parse(op[1]);
      final closeMin = int.parse(cl[0]) * 60 + int.parse(cl[1]);
      return nowMin >= openMin && nowMin < closeMin;
    } catch (_) {
      return true;
    }
  }

  String _generateOtp() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  // Haversine formula — Geolocator package ke bina bhi kaam karta hai
  // Returns distance in METERS between two GPS coordinates
  double _geoDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthR = 6371000; // meters
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthR * c;
  }

  double _toRad(double deg) => deg * (3.141592653589793 / 180);

  Future<OrderModel> placeOrder({
    required CartProvider cart,
    required String address,
    required String landmark,
    required String userPhone,
    double? distanceKm,
    int onlineDiscount = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Blocked user check
    try {
      final userCheck = await _client
          .from('users')
          .select('is_blocked, full_name')
          .eq('id', userId)
          .maybeSingle();

      if (userCheck?['is_blocked'] == true) {
        throw Exception(
          'Your account has been blocked. '
          'Please contact support at @streeteats.hld on Instagram.',
        );
      }
    } catch (e) {
      if (e.toString().contains('blocked')) rethrow;
    }

    final vendor = cart.currentVendor!;
    final int platformFee = await getPlatformFee();

    // ── Multi-vendor delivery charge calculation ──────────────
    // GPS se saare unique vendors ki distance nikalo
    // Sabse door wale vendor ki distance se charge fetch karo Supabase se
    double maxDistanceKm = 0;
    int vendorCountInCart = cart.uniqueVendorCount;

    // Step 1: Customer ki current GPS location lo
    double? customerLat;
    double? customerLng;
    try {
      final locationData = await _client
          .from('users')
          .select('last_lat, last_lng')
          .eq('id', userId)
          .maybeSingle();
      customerLat = (locationData?['last_lat'] as num?)?.toDouble();
      customerLng = (locationData?['last_lng'] as num?)?.toDouble();
    } catch (_) {}

    // Step 2: Saare unique vendor IDs nikalo cart se
    if (customerLat != null && customerLng != null) {
      final uniqueVendorIds = cart.items.values
          .map((ci) => ci.vendor.id)
          .toSet();

      for (final ci in cart.items.values) {
        // Agar vendor ki location null hai to skip
        final vLat = ci.vendor.latitude;
        final vLng = ci.vendor.longitude;
        if (vLat == 0 && vLng == 0) continue;

        final distMeters = _geoDistanceMeters(
          customerLat,
          customerLng,
          vLat,
          vLng,
        );
        final distKm = distMeters / 1000;
        if (distKm > maxDistanceKm) maxDistanceKm = distKm;
      }
    }

    // Step 3: Max distance se delivery charge fetch karo Supabase se
    // Agar GPS nahi mila to cart ka existing charge use karo
    int deliveryCharge;
    if (maxDistanceKm > 0) {
      deliveryCharge = await getDeliveryCharge(maxDistanceKm);
    } else {
      // Fallback: cart provider ka charge ya passed distanceKm
      deliveryCharge = cart.deliveryCharge.round();
      if (deliveryCharge == 0 && distanceKm != null && distanceKm > 1) {
        deliveryCharge = await getDeliveryCharge(distanceKm);
        maxDistanceKm = distanceKm;
      }
    }

    // ✅ Rider payout — hamesha actual distance se fresh calculate hota hai
    final int riderPayout = maxDistanceKm > 0
        ? await getRiderPayout(maxDistanceKm)
        : (distanceKm != null ? await getRiderPayout(distanceKm) : 0);

    final double subtotal = double.parse(cart.subtotal.toStringAsFixed(2));
    final double packagingFee = double.parse(
      cart.packagingFee.toStringAsFixed(2),
    );

    // Total = subtotal + platformFee + deliveryCharge + packagingFee - onlineDiscount
    final int tipAmount = cart.tipAmount;
    final double total =
        subtotal +
        platformFee +
        deliveryCharge +
        packagingFee +
        tipAmount -
        onlineDiscount;
    final otp = _generateOtp();

    String customerName = '';
    String customerPhone = userPhone;
    try {
      final userInfo = await _client
          .from('users')
          .select('full_name, phone')
          .eq('id', userId)
          .maybeSingle();
      customerName = userInfo?['full_name'] as String? ?? '';
      if (customerPhone.isEmpty) {
        customerPhone = userInfo?['phone'] as String? ?? '';
      }
    } catch (_) {}

    final itemsList = cart.items.values
        .map(
          (cartItem) => {
            'item_id': cartItem.item.id,
            'name': cartItem.item.name,
            'quantity': cartItem.quantity,
            'price': cartItem.item.appPrice,
            'vendor_id': cartItem.vendor.id,
            'vendor_name': cartItem.vendor.name,
            'portion': cartItem.portionType ?? '',
            'vendor_price': cartItem.item.hasHalfFull
                ? (cartItem.portionType == 'half'
                      ? (cartItem.item.halfVendorPrice ??
                            cartItem.item.vendorPrice)
                      : (cartItem.item.fullVendorPrice ??
                            cartItem.item.vendorPrice))
                : cartItem.item.vendorPrice,
            'app_price': cartItem.effectivePrice,
          },
        )
        .toList();

    final orderData = await _client
        .from('orders')
        .insert({
          'user_id': userId,
          'vendor_id': vendor.id,
          'vendor_name': vendor.name,
          'items': itemsList,
          'subtotal': subtotal,
          'platform_fee': platformFee,
          'delivery_charge': deliveryCharge,
          'customer_delivery_fee': deliveryCharge,
          'rider_payout': riderPayout,
          'packaging_fee': packagingFee,
          'total': total,
          'tip_amount': tipAmount,
          'status': 'placed',
          'address': address,
          'landmark': landmark,
          'payment_method': 'cod',
          'online_discount': onlineDiscount,
          'delivery_otp': otp,
          'distance_km': maxDistanceKm > 0
              ? maxDistanceKm
              : (distanceKm ?? vendor.distanceKm),
          'max_delivery_distance_km': maxDistanceKm, // ✅ NEW
          'vendor_count': vendorCountInCart, // ✅ NEW
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'mystery_gift_item': await _fetchRandomMysteryGift(),
        })
        .select()
        .single();

    final placedOrder = OrderModel.fromMap(orderData);

    // ── Admin + Rider notifications ──────────────────────────
    try {
      // 1. Admin ko notify karo
      final adminData = await _client
          .from('users')
          .select('id')
          .eq('role', 'admin')
          .limit(5);

      final shortId = placedOrder.id
          .substring(placedOrder.id.length - 6)
          .toUpperCase();

      for (final admin in (adminData as List)) {
        final adminId = admin['id'] as String;
        await PushNotificationSender.newOrderToAdmin(
          adminUserId: adminId,
          orderShortId: shortId,
          vendorName: vendor.name,
          amount: total,
        );
      }

      // 2. Saare online riders ko notify karo — device_tokens se direct
      final riderTokens = await _client
          .from('device_tokens')
          .select('fcm_token')
          .eq('user_type', 'rider')
          .eq('is_active', true);

      for (final rt in (riderTokens as List)) {
        final token = rt['fcm_token'] as String?;
        if (token == null || token.isEmpty) continue;
        await PushNotificationSender.newOrderToRiderDirect(
          fcmToken: token,
          orderShortId: shortId,
          amount: total,
          vendorName: vendor.name,
        );
      }
    } catch (_) {
      // Notification fail = order still placed
    }

    return placedOrder;
  }

  Future<OrderModel> placeOrderForVendor({
    required VendorModel vendor,
    required List<CartItem> items,
    required CartProvider cart,
    required String address,
    required String landmark,
    required String userPhone,
    int onlineDiscount = 0,
    int deliveryDiscount =
        0, // ✅ NEW — promo code ka delivery-specific discount
    bool applyPlatformFee = true,
    double? customerLat,
    double? customerLng,
    String paymentMethod =
        'cod', // 'cod' ya 'online' — checkout_screen se aata hai
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final int platformFee = applyPlatformFee ? await getPlatformFee() : 0;

    // ✅ v4.1: Map-pinned coordinates > saved GPS — accuracy ke liye priority
    double distKm = 0;
    double? finalCustomerLat = customerLat;
    double? finalCustomerLng = customerLng;
    try {
      if (finalCustomerLat == null || finalCustomerLng == null) {
        final locationData = await _client
            .from('users')
            .select('last_lat, last_lng')
            .eq('id', userId)
            .maybeSingle();
        finalCustomerLat = (locationData?['last_lat'] as num?)?.toDouble();
        finalCustomerLng = (locationData?['last_lng'] as num?)?.toDouble();
      }
      if (finalCustomerLat != null && finalCustomerLng != null) {
        final meters = _geoDistanceMeters(
          finalCustomerLat,
          finalCustomerLng,
          vendor.latitude,
          vendor.longitude,
        );
        distKm = meters / 1000;
      }
    } catch (_) {}

    final int rawDeliveryCharge = distKm > 0
        ? await getDeliveryCharge(distKm)
        : cart.deliveryCharge.round();

    // ✅ UPDATED: Promo discount sirf customer ke delivery_charge se
    // minus hota hai. Rider payout hamesha poora milta hai — discount
    // ka cost platform apne margin se absorb karta hai
    final int deliveryCharge = (rawDeliveryCharge - deliveryDiscount) < 0
        ? 0
        : rawDeliveryCharge - deliveryDiscount;

    final int riderPayout = distKm > 0 ? await getRiderPayout(distKm) : 0;
    // Baaki discount (platform fee, packaging fee, online payment) —
    // total se yahi remaining part minus hoga
    final int remainingDiscount = onlineDiscount - deliveryDiscount;

    // Sirf is vendor ke items ka subtotal
    final double subtotal = items.fold(0.0, (sum, ci) => sum + ci.totalPrice);
    final double packagingFee = await getPackagingFee(subtotal);
    final int tipAmount = cart.tipAmount;
    final double total =
        subtotal +
        platformFee +
        deliveryCharge +
        packagingFee +
        tipAmount -
        remainingDiscount;

    final otp = _generateOtp();

    String customerName = '';
    String customerPhone = userPhone;
    try {
      final userInfo = await _client
          .from('users')
          .select('full_name, phone')
          .eq('id', userId)
          .maybeSingle();
      customerName = userInfo?['full_name'] as String? ?? '';
      if (customerPhone.isEmpty) {
        customerPhone = userInfo?['phone'] as String? ?? '';
      }
    } catch (_) {}

    final itemsList = items
        .map(
          (ci) => {
            'item_id': ci.item.id,
            'name': ci.item.name,
            'quantity': ci.quantity,
            'price': ci.item.appPrice,
            'vendor_id': vendor.id,
            'vendor_name': vendor.name,
            'portion': ci.portionType ?? '',
            'vendor_price': ci.item.hasHalfFull
                ? (ci.portionType == 'half'
                      ? (ci.item.halfVendorPrice ?? ci.item.vendorPrice)
                      : (ci.item.fullVendorPrice ?? ci.item.vendorPrice))
                : ci.item.vendorPrice,
            'app_price': ci.effectivePrice,
          },
        )
        .toList();

    final orderData = await _client
        .from('orders')
        .insert({
          'user_id': userId,
          'vendor_id': vendor.id,
          'vendor_name': vendor.name,
          'items': itemsList,
          'subtotal': double.parse(subtotal.toStringAsFixed(2)),
          'platform_fee': platformFee,
          'delivery_charge': deliveryCharge,
          'customer_delivery_fee': deliveryCharge,
          'rider_payout': riderPayout,
          'packaging_fee': double.parse(packagingFee.toStringAsFixed(2)),
          'total': double.parse(total.toStringAsFixed(2)),
          'tip_amount': tipAmount,
          'status': 'placed',
          'address': address,
          'landmark': landmark,
          'payment_method': paymentMethod,
          'online_discount': onlineDiscount,
          'delivery_otp': otp,
          'distance_km': distKm,
          'customer_lat': finalCustomerLat,
          'customer_lng': finalCustomerLng,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'mystery_gift_item': await _fetchRandomMysteryGift(),
        })
        .select()
        .single();

    final placedOrder2 = OrderModel.fromMap(orderData);

    // ── COD: turant notify karo. Online: SKIP — checkout_screen payment
    // confirm hone ke baad notifyAdminAndRiders() khud call karega ──
    if (paymentMethod != 'online') {
      await notifyAdminAndRiders(
        orderId: placedOrder2.id,
        vendorName: vendor.name,
        amount: total,
        deliveryCharge: deliveryCharge.toDouble(),
      );
    }

    return placedOrder2;
  }

  // ── Reusable: Admin + online riders ko naya order notify karo ──────
  // COD ke liye yahi method placeOrderForVendor() ke andar se chalta hai.
  // Online payment ke liye checkout_screen payment-success ke baad
  // isko alag se call karta hai (per vendor order).
  Future<void> notifyAdminAndRiders({
    required String orderId,
    required String vendorName,
    required double amount,
    double deliveryCharge = 15.0,
  }) async {
    try {
      final shortId = orderId.substring(orderId.length - 6).toUpperCase();

      final adminData = await _client
          .from('users')
          .select('id')
          .eq('role', 'admin')
          .limit(5);

      for (final admin in (adminData as List)) {
        await PushNotificationSender.newOrderToAdmin(
          adminUserId: admin['id'] as String,
          orderShortId: shortId,
          vendorName: vendorName,
          amount: amount,
        );
      }

      final riderTokens = await _client
          .from('device_tokens')
          .select('fcm_token')
          .eq('user_type', 'rider')
          .eq('is_active', true);

      for (final rt in (riderTokens as List)) {
        final token = rt['fcm_token'] as String?;
        if (token == null || token.isEmpty) continue;
        await PushNotificationSender.newOrderToRiderDirect(
          fcmToken: token,
          orderShortId: shortId,
          amount: amount,
          vendorName: vendorName,
          deliveryCharge: deliveryCharge,
        );
      }
    } catch (_) {
      // Notification fail = order still placed, silent fail
    }
  }

  Future<List<OrderModel>> getUserOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('orders')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => OrderModel.fromMap(e)).toList();
  }

  Future<OrderModel> getOrderById(String orderId) async {
    final data = await _client
        .from('orders')
        .select()
        .eq('id', orderId)
        .single();
    return OrderModel.fromMap(data);
  }

  // 👇 YAHAN PASTE KARO
  Future<String?> _fetchRandomMysteryGift() async {
    try {
      final data = await _client
          .from('mystery_gifts')
          .select('item_name')
          .eq('is_active', true);
      if ((data as List).isEmpty) return null;
      final random = Random();
      final index = random.nextInt(data.length);
      return data[index]['item_name'] as String?;
    } catch (_) {
      return null;
    }
  }
} // ← class closing bracket
