class ComboModel {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final double vendorPrice;
  final double appPrice;
  final double? originalPrice;
  final bool isDiscounted;
  final bool isAvailable;
  final String? imageUrl;
  final String itemsIncluded;
  final int sortOrder;
  final DateTime createdAt;

  ComboModel({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.vendorPrice,
    required this.appPrice,
    this.originalPrice,
    this.isDiscounted = false,
    this.isAvailable = true,
    this.imageUrl,
    this.itemsIncluded = '',
    this.sortOrder = 0,
    required this.createdAt,
  });

  int get discountPercent {
    if (!isDiscounted || originalPrice == null || originalPrice! <= appPrice) {
      return 0;
    }
    return (((originalPrice! - appPrice) / originalPrice!) * 100).round();
  }

  factory ComboModel.fromMap(Map<String, dynamic> map) {
    return ComboModel(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      vendorPrice: (map['vendor_price'] as num?)?.toDouble() ?? 0,
      appPrice: (map['app_price'] as num?)?.toDouble() ?? 0,
      originalPrice: (map['original_price'] as num?)?.toDouble(),
      isDiscounted: map['is_discounted'] as bool? ?? false,
      isAvailable: map['is_available'] as bool? ?? true,
      imageUrl: map['image_url'] as String?,
      itemsIncluded: map['items_included'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'vendor_price': vendorPrice,
      'app_price': appPrice,
      'original_price': originalPrice,
      'is_discounted': isDiscounted,
      'is_available': isAvailable,
      'image_url': imageUrl,
      'items_included': itemsIncluded,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
