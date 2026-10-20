// lib/models/custom_box_item_model.dart

class CustomBoxItemModel {
  final String id;
  final String name;
  final String weightLabel;
  final double pricePerSlot;
  final String? imageUrl;
  final bool isAvailable;
  final int displayOrder;

  CustomBoxItemModel({
    required this.id,
    required this.name,
    this.weightLabel = '125g',
    required this.pricePerSlot,
    this.imageUrl,
    this.isAvailable = true,
    this.displayOrder = 0,
  });

  factory CustomBoxItemModel.fromMap(Map<String, dynamic> map) {
    return CustomBoxItemModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] as String? ?? 'Sweet',
      weightLabel: map['weight_label'] as String? ?? '125g',
      pricePerSlot: (map['price_per_slot'] as num?)?.toDouble() ?? 80.0,
      imageUrl: map['image_url'] as String?,
      isAvailable: map['is_available'] as bool? ?? true,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weight_label': weightLabel,
      'price_per_slot': pricePerSlot,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'display_order': displayOrder,
    };
  }
}
