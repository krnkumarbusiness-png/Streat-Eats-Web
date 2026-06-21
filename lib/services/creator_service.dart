// lib/services/creator_service.dart
// Creator Challenge System — All Supabase calls
// Handles: apply, status check, wallet, coupon validate/use, deduction

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorService {
  final _supabase = Supabase.instance.client;

  // ── Apply as Creator ─────────────────────────────────────────
  Future<Map<String, dynamic>?> applyAsCreator({
    required String userId,
    required String instagramHandle,
  }) async {
    // Check if already applied
    final existing = await _supabase
        .from('creators')
        .select('id, status')
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) return existing;

    final referralCode = _generateReferralCode(instagramHandle);
    final data = await _supabase
        .from('creators')
        .insert({
          'user_id': userId,
          'instagram_handle': instagramHandle,
          'referral_code': referralCode,
          'wallet_balance': 0.0,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return data;
  }

  // ── Get Creator Status ───────────────────────────────────────
  Future<Map<String, dynamic>?> getCreatorStatus(String userId) async {
    return await _supabase
        .from('creators')
        .select(
          'id, status, wallet_balance, referral_code, instagram_handle, approved_at',
        )
        .eq('user_id', userId)
        .maybeSingle();
  }

  // ── Get Wallet Balance ───────────────────────────────────────
  Future<double> getWalletBalance(String creatorId) async {
    final data = await _supabase
        .from('creators')
        .select('wallet_balance')
        .eq('id', creatorId)
        .single();
    return (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
  }

  // ── Get My Coupons ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyCoupons(String creatorId) async {
    final data = await _supabase
        .from('creator_coupons')
        .select('*')
        .eq('creator_id', creatorId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Get Challenge Tiers ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getChallengeTiers() async {
    final data = await _supabase
        .from('challenge_tiers')
        .select('*')
        .eq('is_active', true)
        .order('views_required', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Validate Coupon (at checkout) ────────────────────────────
  // Returns: {valid: bool, error: String?, coupon: Map?}
  Future<Map<String, dynamic>> validateCoupon({
    required String couponCode,
    required String currentUserId,
  }) async {
    final coupon = await _supabase
        .from('creator_coupons')
        .select('*, creators(user_id)')
        .eq('coupon_code', couponCode.toUpperCase())
        .maybeSingle();

    if (coupon == null) {
      return {'valid': false, 'error': 'Invalid coupon code'};
    }
    if (coupon['is_used'] == true) {
      return {'valid': false, 'error': 'Coupon already used'};
    }
    // Expiry check
    if (coupon['expires_at'] != null) {
      final expiry = DateTime.parse(coupon['expires_at']);
      if (DateTime.now().isAfter(expiry)) {
        return {'valid': false, 'error': 'Coupon has expired'};
      }
    }
    // Coupon sirf us creator ke account se chalega
    // jisne generate kiya — dusre user ke account mein nahi
    final creatorUserId = coupon['creators']?['user_id'];
    if (creatorUserId != null && creatorUserId == currentUserId) {
      return {'valid': false, 'error': 'Cannot use your own coupon'};
    }

    return {'valid': true, 'coupon': coupon};
  }

  // ── Mark Coupon as Used ──────────────────────────────────────
  Future<void> markCouponUsed({
    required String couponId,
    required String orderId,
  }) async {
    await _supabase
        .from('creator_coupons')
        .update({
          'is_used': true,
          'used_in_order_id': orderId,
          'used_at': DateTime.now().toIso8601String(),
        })
        .eq('id', couponId);
  }

  // ── Deduct Wallet (checkout pe) ──────────────────────────────
  // Sirf total markup tak deduct hoga — face_value cap hai
  // actual_deduction = min(total_markup_of_items, wallet_balance)
  Future<double> deductWallet({
    required String creatorId,
    required double currentBalance,
    required double totalMarkup, // sum of (app_price - vendor_price)
    required String orderId,
  }) async {
    final actualDeduction = min(totalMarkup, currentBalance);
    if (actualDeduction <= 0) return 0;

    final newBalance = currentBalance - actualDeduction;

    await _supabase
        .from('creators')
        .update({'wallet_balance': newBalance})
        .eq('id', creatorId);

    await _supabase.from('wallet_transactions').insert({
      'creator_id': creatorId,
      'amount': -actualDeduction,
      'type': 'debit',
      'note':
          'Used on order #${orderId.substring(orderId.length - 6).toUpperCase()}',
      'order_id': orderId,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _supabase
        .from('orders')
        .update({'wallet_discount': actualDeduction})
        .eq('id', orderId);

    return actualDeduction;
  }

  // ── Get Wallet Transactions ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getWalletTransactions(
    String creatorId,
  ) async {
    final data = await _supabase
        .from('wallet_transactions')
        .select('*')
        .eq('creator_id', creatorId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Admin: Get All Creators ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllCreators({String? status}) async {
    var query = _supabase.from('creators').select('*, users(full_name, phone)');
    if (status != null) {
      query = query.eq('status', status);
    }
    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Admin: Approve Creator ────────────────────────────────────
  Future<void> approveCreator(String creatorId) async {
    await _supabase
        .from('creators')
        .update({
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', creatorId);
  }

  // ── Admin: Reject Creator ─────────────────────────────────────
  Future<void> rejectCreator(String creatorId) async {
    await _supabase
        .from('creators')
        .update({'status': 'rejected'})
        .eq('id', creatorId);
  }

  // ── Admin: Adjust Wallet Manually ────────────────────────────
  Future<void> adjustWallet({
    required String creatorId,
    required double currentBalance,
    required double adjustAmount, // positive = credit, negative = debit
    required String note,
  }) async {
    final newBalance = currentBalance + adjustAmount;
    await _supabase
        .from('creators')
        .update({'wallet_balance': newBalance < 0 ? 0 : newBalance})
        .eq('id', creatorId);

    await _supabase.from('wallet_transactions').insert({
      'creator_id': creatorId,
      'amount': adjustAmount,
      'type': adjustAmount >= 0 ? 'credit' : 'debit',
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Admin: Generate Coupon ────────────────────────────────────
  Future<Map<String, dynamic>> generateCoupon({
    required String creatorId,
    required String type, // 'flat' or 'percent'
    required double faceValue,
    required DateTime expiresAt,
  }) async {
    final code = _generateCouponCode();
    final data = await _supabase
        .from('creator_coupons')
        .insert({
          'creator_id': creatorId,
          'coupon_code': code,
          'type': type,
          'face_value': faceValue,
          'is_used': false,
          'expires_at': expiresAt.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return data;
  }

  // ── Admin: Get All Coupons ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllCoupons() async {
    final data = await _supabase
        .from('creator_coupons')
        .select('*, creators(users(full_name))')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Admin: Challenge Tiers CRUD ───────────────────────────────
  Future<List<Map<String, dynamic>>> getChallengeTiersAdmin() async {
    final data = await _supabase
        .from('challenge_tiers')
        .select('*')
        .order('views_required', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addChallengeTier({
    required int viewsRequired,
    required double couponValue,
    required bool isActive,
  }) async {
    await _supabase.from('challenge_tiers').insert({
      'views_required': viewsRequired,
      'coupon_value': couponValue,
      'is_active': isActive,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateChallengeTier({
    required String tierId,
    required int viewsRequired,
    required double couponValue,
    required bool isActive,
  }) async {
    await _supabase
        .from('challenge_tiers')
        .update({
          'views_required': viewsRequired,
          'coupon_value': couponValue,
          'is_active': isActive,
        })
        .eq('id', tierId);
  }

  Future<void> deleteChallengeTier(String tierId) async {
    await _supabase.from('challenge_tiers').delete().eq('id', tierId);
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _generateReferralCode(String instagramHandle) {
    final clean = instagramHandle
        .replaceAll('@', '')
        .replaceAll('.', '')
        .toUpperCase();
    final prefix = clean.length >= 4 ? clean.substring(0, 4) : clean;
    final rand = Random().nextInt(9000) + 1000;
    return '$prefix$rand';
  }

  String _generateCouponCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
