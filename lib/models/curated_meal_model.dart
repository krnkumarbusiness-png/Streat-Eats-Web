// lib/models/curated_meal_model.dart

class CuratedMealModel {
  final String id;
  final String? vendorId; // Hidden actual kitchen ID for delivery distance & rider pickup
  final String title;
  final String tagline;
  final String description;
  final double price;
  final double? strikePrice;
  final String? imageUrl;
  final String category;
  final String dietType; // 'VEG' or 'NON_VEG'
  final int servesCount;
  final String? caloriesInfo;
  final bool isAvailable;
  final int displayOrder;

  CuratedMealModel({
    required this.id,
    this.vendorId,
    required this.title,
    this.tagline = 'StreatEats Signature',
    this.description = '',
    required this.price,
    this.strikePrice,
    this.imageUrl,
    this.category = 'All Meals',
    this.dietType = 'VEG',
    this.servesCount = 1,
    this.caloriesInfo,
    this.isAvailable = true,
    this.displayOrder = 0,
  });

  bool get isVeg => dietType.toUpperCase() != 'NON_VEG';

  factory CuratedMealModel.fromMap(Map<String, dynamic> map) {
    return CuratedMealModel(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString(),
      title: map['title'] as String? ?? 'Special Meal',
      tagline: map['tagline'] as String? ?? 'StreatEats Signature',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      strikePrice: (map['strike_price'] as num?)?.toDouble(),
      imageUrl: map['image_url'] as String?,
      category: map['category'] as String? ?? 'All Meals',
      dietType: map['diet_type'] as String? ?? 'VEG',
      servesCount: (map['serves_count'] as num?)?.toInt() ?? 1,
      caloriesInfo: map['calories_info'] as String?,
      isAvailable: map['is_available'] as bool? ?? true,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'title': title,
      'tagline': tagline,
      'description': description,
      'price': price,
      'strike_price': strikePrice,
      'image_url': imageUrl,
      'category': category,
      'diet_type': dietType,
      'serves_count': servesCount,
      'calories_info': caloriesInfo,
      'is_available': isAvailable,
      'display_order': displayOrder,
    };
  }
}
