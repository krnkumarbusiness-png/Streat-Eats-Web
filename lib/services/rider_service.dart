// lib/services/rider_service.dart
// v3.0 — User App only — sirf checkout notification ke liye
// ✅ Rider profile/earnings/order-accept logic hata diya (wo Rider App mein hai)

import 'package:supabase_flutter/supabase_flutter.dart';

class RiderService {
  final _supabase = Supabase.instance.client;

  // ─── Get all ONLINE rider IDs ──────────────────────────────────
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
      return [];
    }
  }
}
