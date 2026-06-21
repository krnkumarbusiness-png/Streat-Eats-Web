import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================================
// FILE: lib/services/offer_service.dart
// Offer code validate, apply, aur use count track karna
// ================================================================

class OfferResult {
  final bool isValid;
  final String? errorMessage;
  final int discountAmount;
  final String? offerId;
  final String? description;
  final String? discountType;
  final int? discountValue;

  const OfferResult({
    required this.isValid,
    this.errorMessage,
    this.discountAmount = 0,
    this.offerId,
    this.description,
    this.discountType,
    this.discountValue,
  });
}

class OfferService {
  final _client = Supabase.instance.client;

  // ── Offer code validate karo ──────────────────────────────────
  Future<OfferResult> validateOffer({
    required String code,
    required int orderTotal,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const OfferResult(
        isValid: false,
        errorMessage: 'Please login first',
      );
    }

    final trimmedCode = code.trim().toUpperCase();
    if (trimmedCode.isEmpty) {
      return const OfferResult(
        isValid: false,
        errorMessage: 'Enter a valid code',
      );
    }

    try {
      // 1. Offer fetch karo
      final offerData = await _client
          .from('offers')
          .select()
          .eq('code', trimmedCode)
          .eq('is_active', true)
          .maybeSingle();

      if (offerData == null) {
        return const OfferResult(
          isValid: false,
          errorMessage: 'Invalid offer code',
        );
      }

      // 2. Expiry check
      final expiresAt = offerData['expires_at'];
      if (expiresAt != null) {
        final expiry = DateTime.parse(expiresAt as String);
        if (DateTime.now().isAfter(expiry)) {
          return const OfferResult(
            isValid: false,
            errorMessage: 'This offer has expired',
          );
        }
      }

      // 3. Max uses check
      final maxUses = offerData['max_uses'] as int? ?? 0;
      final usedCount = offerData['used_count'] as int? ?? 0;
      if (maxUses > 0 && usedCount >= maxUses) {
        return const OfferResult(
          isValid: false,
          errorMessage: 'Offer limit reached. Try another code!',
        );
      }

      // 4. Min order check
      final minOrder = offerData['min_order_amount'] as int? ?? 0;
      if (orderTotal < minOrder) {
        return OfferResult(
          isValid: false,
          errorMessage: 'Min order ₹$minOrder required for this offer',
        );
      }

      // 5. Per-user limit check
      final perUserLimit = offerData['per_user_limit'] as int? ?? 1;
      final userUsageData = await _client
          .from('offer_uses')
          .select('id')
          .eq('offer_id', offerData['id'] as String)
          .eq('user_id', userId);

      final userUseCount = (userUsageData as List).length;
      if (userUseCount >= perUserLimit) {
        final limitText = perUserLimit == 1
            ? 'You have already used this offer'
            : 'You have used this offer $userUseCount/$perUserLimit times';
        return OfferResult(isValid: false, errorMessage: limitText);
      }
      // 5b. First order offer check
      final isFirstOrderOffer =
          offerData['is_first_order_offer'] as bool? ?? false;
      if (isFirstOrderOffer) {
        final userId2 = userId;
        final userData = await _client
            .from('users')
            .select('has_placed_first_order')
            .eq('id', userId2)
            .maybeSingle();
        final hasOrdered =
            userData?['has_placed_first_order'] as bool? ?? false;
        if (hasOrdered) {
          return const OfferResult(
            isValid: false,
            errorMessage: 'This code is only for first-time orders',
          );
        }
      }
      // 6. Discount calculate karo
      final discountType = offerData['discount_type'] as String? ?? 'flat';
      final discountValue = offerData['discount_value'] as int? ?? 0;
      int discountAmount = 0;

      if (discountType == 'flat') {
        discountAmount = discountValue;
      } else if (discountType == 'percent') {
        discountAmount = ((orderTotal * discountValue) / 100).round();
      }

      // Discount order total se zyada nahi ho sakta
      discountAmount = discountAmount.clamp(0, orderTotal);

      return OfferResult(
        isValid: true,
        discountAmount: discountAmount,
        offerId: offerData['id'] as String,
        description: offerData['description'] as String?,
        discountType: discountType,
        discountValue: discountValue,
      );
    } catch (e) {
      return OfferResult(
        isValid: false,
        errorMessage: 'Error: ${e.toString()}',
      );
    }
  }

  // ── Offer use record karo (order place hone ke baad call karo) ─
  Future<void> recordOfferUse({
    required String offerId,
    required String orderId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // offer_uses mein insert karo
      await _client.from('offer_uses').insert({
        'offer_id': offerId,
        'user_id': userId,
        'order_id': orderId,
      });

      // used_count increment karo
      await _client.rpc(
        'increment_offer_use_count',
        params: {'offer_id_param': offerId},
      );
    } catch (_) {}
  }
}
