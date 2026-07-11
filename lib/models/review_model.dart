class ReviewModel {
  final String id;
  final String orderId;
  final String userId;
  final String vendorId;
  final int foodQualityRating;
  final int tasteRating;
  final int riderRating;
  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.vendorId,
    required this.foodQualityRating,
    required this.tasteRating,
    required this.riderRating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'] ?? '',
      orderId: map['order_id'] ?? '',
      userId: map['user_id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      foodQualityRating: (map['food_quality_rating'] as num?)?.toInt() ?? 1,
      tasteRating: (map['taste_rating'] as num?)?.toInt() ?? 1,
      riderRating: (map['rider_rating'] as num?)?.toInt() ?? 1,
      comment: map['comment'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'user_id': userId,
      'vendor_id': vendorId,
      'food_quality_rating': foodQualityRating,
      'taste_rating': tasteRating,
      'rider_rating': riderRating,
      'comment': comment,
    };
  }
}
