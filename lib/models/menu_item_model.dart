// lib/models/menu_item_model.dart
// v5.0 — upsellItemIds (TEXT[]) added, old upsell fields preserved for backward compat
// NEW: upsell_item_ids = list of item IDs jo is item ke popup mein dikhenge
// OLD fields (upsellPopupTitle, upsellPopupMessage, upsellType) still work

class MenuItemModel {
  final String id;
  final String vendorId;
  final String vendorName;
  final String name;
  final String description;
  final String? longDescription;
  final double vendorPrice;
  final double appPrice;
  final double? originalPrice;
  final bool isDiscounted;
  final bool isSuggestedItem;
  final String? suggestedCategory;
  final String category;
  final bool isAvailable;
  final String? imageUrl;
  final bool isVeg;
  final String stockStatus;
  final String? tag;
  final bool isRecommendedHome;

  // Half/Full portion
  final bool hasHalfFull;
  final double? halfPrice;
  final double? fullPrice;
  final double? halfVendorPrice;
  final double? fullVendorPrice;

  // Independent Half/Full discounts
  final bool halfIsDiscounted;
  final double? halfOriginalPrice;
  final bool fullIsDiscounted;
  final double? fullOriginalPrice;

  // Upsell popup customization (old — still used for title/message)
  final String? upsellPopupTitle;
  final String? upsellPopupMessage;
  final String? upsellType;

  // ✅ NEW v5.0: Direct item IDs for upsell popup
  // Admin jab koi item select karta hai "Show in popup" ke liye
  // unke IDs yahan store hote hain
  final List<String> upsellItemIds;

  MenuItemModel({
    required this.id,
    required this.vendorId,
    this.vendorName = '',
    required this.name,
    required this.description,
    this.longDescription,
    required this.vendorPrice,
    required this.appPrice,
    this.originalPrice,
    this.isDiscounted = false,
    this.isSuggestedItem = false,
    this.suggestedCategory,
    required this.category,
    required this.isAvailable,
    this.imageUrl,
    this.isVeg = true,
    this.stockStatus = 'available',
    this.tag,
    this.isRecommendedHome = false,
    this.hasHalfFull = false,
    this.halfPrice,
    this.fullPrice,
    this.halfVendorPrice,
    this.fullVendorPrice,
    this.halfIsDiscounted = false,
    this.halfOriginalPrice,
    this.fullIsDiscounted = false,
    this.fullOriginalPrice,
    this.upsellPopupTitle,
    this.upsellPopupMessage,
    this.upsellType,
    this.upsellItemIds = const [],
  });

  // ✅ Helper: kya is item ka upsell popup dikhana chahiye?
  bool get hasUpsellPopup => upsellItemIds.isNotEmpty;

  int get discountPercent {
    if (!isDiscounted || originalPrice == null || originalPrice! <= appPrice) {
      return 0;
    }
    return (((originalPrice! - appPrice) / originalPrice!) * 100).round();
  }

  double get displayPrice => appPrice;

  double get minPrice {
    if (hasHalfFull && halfPrice != null) return halfPrice!;
    return appPrice;
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    // ✅ upsell_item_ids parse — Supabase TEXT[] as List
    List<String> parseUpsellIds(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        // Fallback: "{id1,id2}" format
        final cleaned = raw.replaceAll('{', '').replaceAll('}', '').trim();
        if (cleaned.isEmpty) return [];
        return cleaned.split(',').map((e) => e.trim()).toList();
      }
      return [];
    }

    return MenuItemModel(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      vendorName:
          map['vendor_name'] as String? ??
          (map['vendors'] as Map<String, dynamic>?)?['name'] as String? ??
          '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      longDescription: map['long_description'] as String?,
      vendorPrice: (map['vendor_price'] as num?)?.toDouble() ?? 0,
      appPrice: (map['app_price'] as num?)?.toDouble() ?? 0,
      originalPrice: (map['original_price'] as num?)?.toDouble(),
      isDiscounted: map['is_discounted'] as bool? ?? false,
      isSuggestedItem: map['is_suggested_item'] as bool? ?? false,
      suggestedCategory: map['suggested_category'] as String?,
      category: map['category'] ?? 'Other',
      isAvailable: map['is_available'] as bool? ?? true,
      imageUrl: map['image_url'] as String?,
      isVeg: map['is_veg'] as bool? ?? true,
      stockStatus: map['stock_status'] as String? ?? 'available',
      tag: map['tag'] as String?,
      isRecommendedHome: map['is_recommended_home'] as bool? ?? false,
      hasHalfFull: map['has_half_full'] as bool? ?? false,
      halfPrice: (map['half_price'] as num?)?.toDouble(),
      fullPrice: (map['full_price'] as num?)?.toDouble(),
      halfVendorPrice: (map['half_vendor_price'] as num?)?.toDouble(),
      fullVendorPrice: (map['full_vendor_price'] as num?)?.toDouble(),
      halfIsDiscounted: map['half_is_discounted'] as bool? ?? false,
      halfOriginalPrice: (map['half_original_price'] as num?)?.toDouble(),
      fullIsDiscounted: map['full_is_discounted'] as bool? ?? false,
      fullOriginalPrice: (map['full_original_price'] as num?)?.toDouble(),
      upsellPopupTitle: map['upsell_popup_title'] as String?,
      upsellPopupMessage: map['upsell_popup_message'] as String?,
      upsellType: map['upsell_type'] as String?,
      upsellItemIds: parseUpsellIds(map['upsell_item_ids']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'name': name,
      'description': description,
      'long_description': longDescription,
      'vendor_price': vendorPrice,
      'app_price': appPrice,
      'original_price': originalPrice,
      'is_discounted': isDiscounted,
      'is_suggested_item': isSuggestedItem,
      'suggested_category': suggestedCategory,
      'category': category,
      'is_available': isAvailable,
      'image_url': imageUrl,
      'is_veg': isVeg,
      'stock_status': stockStatus,
      'tag': tag,
      'is_recommended_home': isRecommendedHome,
      'has_half_full': hasHalfFull,
      'half_price': halfPrice,
      'full_price': fullPrice,
      'half_vendor_price': halfVendorPrice,
      'full_vendor_price': fullVendorPrice,
      'half_is_discounted': halfIsDiscounted,
      'half_original_price': halfOriginalPrice,
      'full_is_discounted': fullIsDiscounted,
      'full_original_price': fullOriginalPrice,
      'upsell_popup_title': upsellPopupTitle,
      'upsell_popup_message': upsellPopupMessage,
      'upsell_type': upsellType,
      'upsell_item_ids': upsellItemIds,
    };
  }
}
