import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewService {
  final _client = Supabase.instance.client;

  /// Ek order ke liye review submit karo.
  /// Agar already review hai to PostgreSQL UNIQUE constraint se error aayega — handled.
  Future<void> submitReview({
    required String orderId,
    required String vendorId,
    required int foodQualityRating,
    required int tasteRating,
    required int riderRating,
    String? comment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _client.from('reviews').insert({
      'order_id': orderId,
      'user_id': userId,
      'vendor_id': vendorId,
      'food_quality_rating': foodQualityRating,
      'taste_rating': tasteRating,
      'rider_rating': riderRating,
      'comment': (comment?.trim().isEmpty ?? true) ? null : comment?.trim(),
    });
  }

  /// Diye gaye order IDs me se kaunse already reviewed hain — Set return karta hai.
  /// Order history screen me batch check ke liye use hota hai.
  Future<Set<String>> getReviewedOrderIds(List<String> orderIds) async {
    if (orderIds.isEmpty) return {};
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final data = await _client
          .from('reviews')
          .select('order_id')
          .eq('user_id', userId)
          .inFilter('order_id', orderIds);

      return (data as List).map((e) => e['order_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }
}
