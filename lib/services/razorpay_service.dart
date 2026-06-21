// lib/services/razorpay_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RazorpayService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> createOrder({
    required String orderId,
    required double amount,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-razorpay-order',
        body: {
          'orderId': orderId,
          'amount': amount,
        },
      );

      debugPrint('RZP Edge status: ${response.status}');
      debugPrint('RZP Edge data: ${response.data}');

      if (response.status != 200) {
        debugPrint('Edge function error: ${response.data}');
        return null;
      }

      if (response.data == null) {
        debugPrint('Edge function returned null data');
        return null;
      }

      // Safe cast
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }

      // Fallback cast
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      debugPrint('RazorpayService createOrder error: $e');
      return null;
    }
  }
}
