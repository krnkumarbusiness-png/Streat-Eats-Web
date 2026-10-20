// lib/models/festive_deal_model.dart

class FestiveDealModel {
  final String id;
  final String? vendorId; // Actual sweet vendor ID
  final String title;
  final String? subtitle;
  final double price;
  final double? originalPrice;
  final String? imageUrl;
  final String badgeText;
  final bool isAvailable;
  final int displayOrder;

  FestiveDealModel({
    required this.id,
    this.vendorId,
    required this.title,
    this.subtitle,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    this.badgeText = 'Festive Deal',
    this.isAvailable = true,
    this.displayOrder = 0,
  });

  factory FestiveDealModel.fromMap(Map<String, dynamic> map) {
    return FestiveDealModel(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString(),
      title: map['title'] as String? ?? 'Festive Sweet',
      subtitle: map['subtitle'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['original_price'] as num?)?.toDouble(),
      imageUrl: map['image_url'] as String?,
      badgeText: map['badge_text'] as String? ?? 'Festive Deal',
      isAvailable: map['is_available'] as bool? ?? true,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'original_price': originalPrice,
      'image_url': imageUrl,
      'badge_text': badgeText,
      'is_available': isAvailable,
      'display_order': displayOrder,
    };
  }
}
