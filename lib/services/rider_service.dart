// lib/services/rider_service.dart
// v2.1 — getOnlineRiderIds() added for checkout notification
// ✅ Sabhi online riders ke IDs fetch karo → checkout se notify karo

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rider_model.dart';
import '../models/rider_earning_model.dart';
import '../models/order_model.dart';
import 'push_notification_sender.dart';

class RiderService {
  final _supabase = Supabase.instance.client;

  // ─── Rider Signup ─────────────────────────────────────────────
  Future<void> createRiderProfile({
    required String fullName,
    required String phone,
    required String vehicleType,
    required String area,
    String? upiId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('users').update({'role': 'rider'}).eq('id', userId);
    await _supabase.from('riders').insert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'vehicle_type': vehicleType,
      'area': area,
      'upi_id': upiId,
      'status': 'pending',
    });
  }

  // ─── Rider Profile Fetch ──────────────────────────────────────
  Future<RiderModel?> getRiderProfile() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('riders')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    return RiderModel.fromMap(response);
  }

  // ─── ✅ NEW: Get all ONLINE rider IDs ──────────────────────────
  // Checkout pe order place hone ke baad in sabko notify karo
  // Sirf approved + available riders ko hi notify karna hai
  Future<List<String>> getOnlineRiderIds() async {
    try {
      final response = await _supabase
          .from('riders')
          .select('id')
          .eq('is_available', true)
          .eq('status', 'approved'); // sirf approved riders

      return (response as List).map((r) => r['id'] as String).toList();
    } catch (e) {
      // Notification fail hone se order fail nahi hona chahiye
      // Silently return empty — polling fallback kaam karega
      return [];
    }
  }

  // ─── Available Orders ──────────────────────────────────────────
  Future<List<OrderModel>> getAvailableOrders() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('orders')
        .select()
        .eq('status', 'placed')
        .isFilter('rider_id', null)
        .order('created_at', ascending: false);

    final allOrders = (response as List)
        .map((o) => OrderModel.fromMap(o))
        .toList();

    return allOrders.where((order) {
      final rejectedBy = order.rejectedBy;
      return !rejectedBy.contains(userId);
    }).toList();
  }

  // ─── Accept Order ──────────────────────────────────────────────
  Future<void> acceptOrder(String orderId) async {
    final userId = _supabase.auth.currentUser!.id;
    final rider = await getRiderProfile();
    await _supabase
        .from('orders')
        .update({
          'rider_id': userId,
          'rider_name': rider?.fullName ?? 'Rider',
          'rider_phone': rider?.phone ?? '',
          'status': 'preparing',
        })
        .eq('id', orderId);
  }

  // ─── Reject Order ─────────────────────────────────────────────
  Future<void> rejectOrder(String orderId, {String? reason}) async {
    final userId = _supabase.auth.currentUser!.id;

    final orderData = await _supabase
        .from('orders')
        .select('rejected_by, rejection_reason')
        .eq('id', orderId)
        .maybeSingle();

    final List<dynamic> existingRejectedBy =
        (orderData?['rejected_by'] as List<dynamic>?) ?? [];

    if (!existingRejectedBy.contains(userId)) {
      existingRejectedBy.add(userId);
    }

    await _supabase
        .from('orders')
        .update({
          'rejected_by': existingRejectedBy,
          'rejection_reason': reason ?? 'Rider unavailable',
          'rider_id': null,
          'rider_name': null,
          'rider_phone': null,
        })
        .eq('id', orderId);
  }

  // ─── Update Order Status ───────────────────────────────────────
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _supabase.from('orders').update({'status': status}).eq('id', orderId);
  }

  // ─── Single Order Fetch ────────────────────────────────────────
  Future<OrderModel?> getOrderById(String orderId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (response == null) return null;
    return OrderModel.fromMap(response);
  }

  // ─── Verify Delivery OTP ──────────────────────────────────────
  Future<bool> verifyDeliveryOtp(String orderId, String enteredOtp) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('delivery_otp, status')
          .eq('id', orderId)
          .single();

      final rawOtp = response['delivery_otp'];
      if (rawOtp == null) return false;

      final String savedOtp;
      if (rawOtp is int) {
        savedOtp = rawOtp.toString().trim();
      } else if (rawOtp is double) {
        savedOtp = rawOtp.toInt().toString().trim();
      } else {
        savedOtp = rawOtp.toString().trim();
      }

      // ✅ OTP fetch hua — abhi customer ko notify karo
      // Rider ne "Deliver with OTP" click kiya = customer ready ho jaye
      try {
        final orderInfo = await _supabase
            .from('orders')
            .select('user_id')
            .eq('id', orderId)
            .maybeSingle();
        final customerId = orderInfo?['user_id'] as String?;
        if (customerId != null) {
          await PushNotificationSender.sendDeliveryOtpToCustomer(
            customerId: customerId,
            orderId: orderId,
            otp: savedOtp,
          );
        }
      } catch (_) {}

      final String inputOtp = enteredOtp.trim();
      if (savedOtp.isEmpty || savedOtp != inputOtp) return false;

      await _supabase
          .from('orders')
          .update({
            'status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      final userId = _supabase.auth.currentUser!.id;

      // Actual delivery charge + tip order se fetch karo
      final orderData = await _supabase
          .from('orders')
          .select('delivery_charge, tip_amount')
          .eq('id', orderId)
          .maybeSingle();

      final deliveryCharge =
          (orderData?['delivery_charge'] as num?)?.toDouble() ?? 15.0;
      final tipAmount = (orderData?['tip_amount'] as num?)?.toInt() ?? 0;

      await _supabase.from('rider_earnings').insert({
        'rider_id': userId,
        'order_id': orderId,
        'amount': deliveryCharge,
        'tip_amount': tipAmount,
        'is_paid': false,
        'earned_at': DateTime.now().toIso8601String(),
      });

      final rider = await getRiderProfile();
      final currentEarnings = rider?.totalEarnings ?? 0;
      await _supabase
          .from('riders')
          .update({
            'total_earnings': currentEarnings + deliveryCharge + tipAmount,
          })
          .eq('id', userId);
      // OTP sahi nikla, order delivered — customer ko notify karo
      try {
        final orderInfo = await _supabase
            .from('orders')
            .select('user_id, vendor_name')
            .eq('id', orderId)
            .maybeSingle();
        final customerId = orderInfo?['user_id'] as String?;
        final vendorName = orderInfo?['vendor_name'] as String? ?? 'the vendor';
        if (customerId != null) {
          await PushNotificationSender.orderDeliveredToCustomer(
            customerId: customerId,
            vendorName: vendorName,
          );
        }
      } catch (_) {}
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── My Active Order ──────────────────────────────────────────
  Future<OrderModel?> getMyActiveOrder() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('orders')
        .select()
        .eq('rider_id', userId)
        .not('status', 'eq', 'delivered')
        .not('status', 'eq', 'cancelled')
        .order('created_at', ascending: false)
        .maybeSingle();
    if (response == null) return null;
    return OrderModel.fromMap(response);
  }

  // ─── My Earnings ──────────────────────────────────────────────
  Future<List<RiderEarningModel>> getMyEarnings() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('rider_earnings')
        .select()
        .eq('rider_id', userId)
        .order('earned_at', ascending: false);
    return (response as List).map((e) => RiderEarningModel.fromMap(e)).toList();
  }

  // ─── Today Earnings ───────────────────────────────────────────
  Future<Map<String, dynamic>> getTodayEarnings() async {
    final userId = _supabase.auth.currentUser!.id;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final response = await _supabase
        .from('rider_earnings')
        .select()
        .eq('rider_id', userId)
        .gte('earned_at', startOfDay.toIso8601String());
    final earnings = (response as List)
        .map((e) => RiderEarningModel.fromMap(e))
        .toList();
    final totalAmount = earnings.fold<double>(0, (sum, e) => sum + e.amount);
    return {'amount': totalAmount, 'orders': earnings.length};
  }

  // ─── Week Earnings ────────────────────────────────────────────
  Future<Map<String, dynamic>> getWeekEarnings() async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final response = await _supabase
        .from('rider_earnings')
        .select()
        .eq('rider_id', userId)
        .gte('earned_at', weekStart.toIso8601String());
    final earnings = (response as List)
        .map((e) => RiderEarningModel.fromMap(e))
        .toList();
    final totalAmount = earnings.fold<double>(0, (sum, e) => sum + e.amount);
    final Map<int, double> perDay = {};
    for (final e in earnings) {
      final day = e.earnedAt.weekday;
      perDay[day] = (perDay[day] ?? 0) + e.amount;
    }
    return {'amount': totalAmount, 'orders': earnings.length, 'perDay': perDay};
  }

  // ─── Update UPI ───────────────────────────────────────────────
  Future<void> updateUpiId(String upiId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('riders').update({'upi_id': upiId}).eq('id', userId);
  }

  // ─── Toggle Availability ──────────────────────────────────────
  Future<void> toggleAvailability(bool isAvailable) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('riders')
        .update({'is_available': isAvailable})
        .eq('id', userId);
  }

  // ─── Next Sunday ──────────────────────────────────────────────
  DateTime getNextSunday() {
    final now = DateTime.now();
    final daysUntilSunday = 7 - now.weekday;
    return now.add(Duration(days: daysUntilSunday));
  }
}
