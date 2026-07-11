import 'package:supabase_flutter/supabase_flutter.dart';

class OfferResult {
  final bool isValid;
  final String? errorMessage;
  final String? offerId;
  final String? description;
  final double deliveryDiscount;
  final double platformFeeDiscount;
  final double packagingFeeDiscount;
  final double totalDiscount;

  const OfferResult({
    required this.isValid,
    this.errorMessage,
    this.offerId,
    this.description,
    this.deliveryDiscount = 0,
    this.platformFeeDiscount = 0,
    this.packagingFeeDiscount = 0,
    this.totalDiscount = 0,
  });
}

class OfferService {
  final _client = Supabase.instance.client;

  double _calcDiscount({
    required String type,
    required double value,
    required double originalAmount,
  }) {
    if (type == 'free') return originalAmount;
    if (type == 'flat') return value.clamp(0, originalAmount);
    if (type == 'percent') {
      return ((originalAmount * value) / 100).clamp(0, originalAmount);
    }
    return 0;
  }

  Future<OfferResult> validateOffer({
    required String code,
    required double cartSubtotal,
    required double deliveryCharge,
    required double platformFee,
    required double packagingFee,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const OfferResult(
        isValid: false,
        errorMessage: 'Please login first',
      );
    }

    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return const OfferResult(
        isValid: false,
        errorMessage: 'Enter a valid code',
      );
    }

    try {
      final offer = await _client
          .from('offers')
          .select()
          .eq('coupon_code', trimmed)
          .eq('is_active', true)
          .maybeSingle();

      if (offer == null) {
        return const OfferResult(
          isValid: false,
          errorMessage: 'Invalid offer code',
        );
      }

      // Expiry check
      final expiresAt = offer['expires_at'];
      if (expiresAt != null) {
        if (DateTime.now().isAfter(DateTime.parse(expiresAt as String))) {
          return const OfferResult(
            isValid: false,
            errorMessage: 'This offer has expired',
          );
        }
      }

      // Max uses check
      final maxUses = (offer['max_uses_new'] as num?)?.toInt() ?? 0;
      final totalUses = (offer['total_uses'] as num?)?.toInt() ?? 0;
      if (maxUses > 0 && totalUses >= maxUses) {
        return const OfferResult(
          isValid: false,
          errorMessage: 'Offer limit reached!',
        );
      }

      // Cart value checks
      final minCart = (offer['min_cart_value'] as num?)?.toDouble() ?? 0;
      final maxCart = (offer['max_cart_value'] as num?)?.toDouble() ?? 0;
      if (minCart > 0 && cartSubtotal < minCart) {
        return OfferResult(
          isValid: false,
          errorMessage:
              'Add ₹${(minCart - cartSubtotal).ceil()} more to use this code',
        );
      }
      if (maxCart > 0 && cartSubtotal > maxCart) {
        return OfferResult(
          isValid: false,
          errorMessage:
              'This code is only for orders up to ₹${maxCart.toInt()}',
        );
      }

      // Order number target check
      final orderTarget = (offer['order_number_target'] as num?)?.toInt() ?? 0;
      if (orderTarget > 0) {
        final ordersData = await _client
            .from('orders')
            .select('id')
            .eq('user_id', userId)
            .not('status', 'eq', 'cancelled');
        final orderCount = (ordersData as List).length;
        if (orderTarget == 1 && orderCount != 0) {
          return const OfferResult(
            isValid: false,
            errorMessage: 'This code is only for your first order',
          );
        }
        if (orderTarget == 2 && orderCount != 1) {
          return const OfferResult(
            isValid: false,
            errorMessage: 'This code is only for your second order',
          );
        }
        if (orderTarget == 3 && orderCount != 2) {
          return const OfferResult(
            isValid: false,
            errorMessage: 'This code is only for your third order',
          );
        }
      }

      // Already used check
      final usedBy = List<String>.from(offer['used_by_users'] as List? ?? []);
      if (usedBy.contains(userId)) {
        return const OfferResult(
          isValid: false,
          errorMessage: 'You have already used this code',
        );
      }

      // Calculate per-fee discounts
      final deliveryDiscountType =
          offer['delivery_discount_type'] as String? ?? 'none';
      final deliveryDiscountVal =
          (offer['delivery_discount_value'] as num?)?.toDouble() ?? 0;
      final platformDiscountType =
          offer['platform_fee_discount_type'] as String? ?? 'none';
      final platformDiscountVal =
          (offer['platform_fee_discount_value'] as num?)?.toDouble() ?? 0;
      final packagingDiscountType =
          offer['packaging_fee_discount_type'] as String? ?? 'none';
      final packagingDiscountVal =
          (offer['packaging_fee_discount_value'] as num?)?.toDouble() ?? 0;

      final dDiscount = deliveryDiscountType == 'none'
          ? 0.0
          : _calcDiscount(
              type: deliveryDiscountType,
              value: deliveryDiscountVal,
              originalAmount: deliveryCharge,
            );
      final pDiscount = platformDiscountType == 'none'
          ? 0.0
          : _calcDiscount(
              type: platformDiscountType,
              value: platformDiscountVal,
              originalAmount: platformFee,
            );
      final pkDiscount = packagingDiscountType == 'none'
          ? 0.0
          : _calcDiscount(
              type: packagingDiscountType,
              value: packagingDiscountVal,
              originalAmount: packagingFee,
            );

      final total = dDiscount + pDiscount + pkDiscount;

      return OfferResult(
        isValid: true,
        offerId: offer['id'] as String,
        description: offer['description'] as String?,
        deliveryDiscount: dDiscount,
        platformFeeDiscount: pDiscount,
        packagingFeeDiscount: pkDiscount,
        totalDiscount: total,
      );
    } catch (e) {
      return OfferResult(isValid: false, errorMessage: 'Error: $e');
    }
  }

  Future<void> recordOfferUse({
    required String offerId,
    required String orderId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // used_by_users array mein add karo
      await _client.rpc(
        'append_offer_user',
        params: {'offer_id_param': offerId, 'user_id_param': userId},
      );
      // total_uses increment
      await _client.rpc(
        'increment_offer_total_uses',
        params: {'offer_id_param': offerId},
      );
      // offer_uses table mein bhi log karo
      await _client.from('offer_uses').insert({
        'offer_id': offerId,
        'user_id': userId,
        'order_id': orderId,
      });
    } catch (_) {}
  }

  // ✅ NEW — Home screen ke liye offers (admin se show_on_home control hota hai)
  Future<List<Map<String, dynamic>>> getHomeOffers() async {
    try {
      final data = await _client
          .from('offers')
          .select()
          .eq('is_active', true)
          .eq('show_on_home', true)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }
}
