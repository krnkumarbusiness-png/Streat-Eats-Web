class OrderModel {
  final String id;
  final String userId;
  final String vendorId;
  final String vendorName;
  final List<OrderItemModel> items;
  final double subtotal;
  final double platformFee;
  final double deliveryCharge;
  final double customerDeliveryFee; // ✅ NEW — customer actually pays this
  final double riderPayout; // ✅ NEW — rider actually earns this
  final double maxDeliveryDistanceKm; // ✅ NEW — farthest vendor distance
  final int
  vendorCount; // ✅ NEW — kitne vendors the cart mein  final double maxDeliveryDistanceKm; // ✅ NEW — farthest vendor distance  final int vendorCount; // ✅ NEW — kitne vendors the cart mein
  final double total;
  final String status;
  final String address;
  final String landmark;
  final String paymentMethod;
  final String? deliveryOtp;
  final String? riderName;
  final String? riderPhone;
  final DateTime createdAt;
  final List<String> rejectedBy;
  final String? appliedPromoCode; // ✅ NEW
  final double affiliateCommissionLogged; // ✅ NEW
  final String orderType;
  final double packagingFee;
  final int tipAmount;

  OrderModel({
    required this.id,
    required this.userId,
    required this.vendorId,
    required this.vendorName,
    required this.items,
    required this.subtotal,
    required this.platformFee,
    this.deliveryCharge = 0,
    this.customerDeliveryFee = 0, // ✅ NEW
    this.riderPayout = 0, // ✅ NEW
    this.maxDeliveryDistanceKm = 0, // ✅ NEW
    this.vendorCount = 1, // ✅ NEW
    required this.total,
    required this.status,
    required this.address,
    required this.landmark,
    required this.paymentMethod,
    this.deliveryOtp,
    this.riderName,
    this.riderPhone,
    required this.createdAt,
    this.rejectedBy = const [],
    this.appliedPromoCode, // ✅ NEW
    this.affiliateCommissionLogged = 0, // ✅ NEW
    this.orderType = 'street_food',
    this.packagingFee = 0,
    this.tipAmount = 0,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    List<OrderItemModel> parsedItems = [];
    if (map['items'] != null) {
      try {
        final rawItems = map['items'] as List<dynamic>;
        parsedItems = rawItems
            .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        parsedItems = [];
      }
    }

    return OrderModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      vendorName: map['vendor_name'] ?? '',
      items: parsedItems,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      platformFee: (map['platform_fee'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (map['delivery_charge'] as num?)?.toDouble() ?? 0.0,
      customerDeliveryFee:
          (map['customer_delivery_fee'] as num?)?.toDouble() ?? 0.0, // ✅ NEW
      riderPayout: (map['rider_payout'] as num?)?.toDouble() ?? 0.0, // ✅ NEW
      maxDeliveryDistanceKm:
          (map['max_delivery_distance_km'] as num?)?.toDouble() ?? 0.0, // ✅ NEW
      vendorCount: (map['vendor_count'] as num?)?.toInt() ?? 1, // ✅ NEW
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'placed',
      address: map['address'] ?? '',
      landmark: map['landmark'] ?? '',
      paymentMethod: map['payment_method'] ?? 'cod',
      deliveryOtp: map['delivery_otp']?.toString(),
      riderName: map['rider_name'],
      riderPhone: map['rider_phone'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      rejectedBy: List<String>.from(map['rejected_by'] ?? []),
      appliedPromoCode: map['applied_promo_code'] as String?, // ✅ NEW
      affiliateCommissionLogged:
          (map['affiliate_commission_logged'] as num?)?.toDouble() ??
          0, // ✅ NEW
      orderType: map['order_type'] as String? ?? 'street_food',
      packagingFee: (map['packaging_fee'] as num?)?.toDouble() ?? 0.0,
      tipAmount: (map['tip_amount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'platform_fee': platformFee,
      'delivery_charge': deliveryCharge,
      'customer_delivery_fee': customerDeliveryFee, // ✅ NEW
      'rider_payout': riderPayout, // ✅ NEW
      'max_delivery_distance_km': maxDeliveryDistanceKm, // ✅ NEW
      'vendor_count': vendorCount, // ✅ NEW
      'total': total,
      'status': status,
      'address': address,
      'landmark': landmark,
      'payment_method': paymentMethod,
      'delivery_otp': deliveryOtp,
      'rider_name': riderName,
      'rider_phone': riderPhone,
      'created_at': createdAt.toIso8601String(),
      'rejected_by': rejectedBy,
      'applied_promo_code': appliedPromoCode, // ✅ NEW
      'affiliate_commission_logged': affiliateCommissionLogged, // ✅ NEW
      'order_type': orderType,
      'packaging_fee': packagingFee,
      'tip_amount': tipAmount,
    };
  }
}

class OrderItemModel {
  final String itemId;
  final String name;
  final int quantity;
  final double price;
  final String vendorId;
  final String vendorName;
  final String portion; // ✅ NEW: 'half', 'full', or '' (empty = single)
  final double vendorPrice; // ✅ NEW: what we pay vendor
  final double appPrice; // ✅ NEW: what customer paid

  OrderItemModel({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.vendorId = '',
    this.vendorName = '',
    this.portion = '', // ✅ NEW
    this.vendorPrice = 0, // ✅ NEW
    this.appPrice = 0, // ✅ NEW
  });

  Map<String, dynamic> toMap() => {
    'item_id': itemId,
    'name': name,
    'quantity': quantity,
    'price': price,
    'vendor_id': vendorId,
    'vendor_name': vendorName,
    'portion': portion, // ✅ NEW
    'vendor_price': vendorPrice, // ✅ NEW
    'app_price': appPrice, // ✅ NEW
  };

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      itemId: map['item_id'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      vendorId: map['vendor_id'] as String? ?? '',
      vendorName: map['vendor_name'] as String? ?? '',
      portion: map['portion'] as String? ?? '', // ✅ NEW
      vendorPrice: (map['vendor_price'] as num?)?.toDouble() ?? 0.0, // ✅ NEW
      appPrice: (map['app_price'] as num?)?.toDouble() ?? 0.0, // ✅ NEW
    );
  }
}
