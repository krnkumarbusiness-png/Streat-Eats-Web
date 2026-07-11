// lib/models/delivery_address_model.dart
// v1.0 — Manual Location Selection Feature
//
// Two address types:
//   AddressType.gps    — current GPS location (coords known)
//   AddressType.manual — user typed address (no coords)
//
// Delivery charge logic:
//   gps    → distance calculated from coords → slab charge
//   manual → fallback to max slab (safe assumption)

enum AddressType { gps, manual }

class DeliveryAddress {
  final AddressType type;

  // GPS address fields
  final double? latitude;
  final double? longitude;
  final double? distanceKm; // pre-calculated from vendor

  // Common fields (both types)
  final String address; // full address text
  final String landmark; // nearby landmark

  // Manual-only label
  final String? recipientName; // optional: "Deliver to Priya"
  final String? recipientPhone; // optional: different contact number

  const DeliveryAddress({
    required this.type,
    required this.address,
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.recipientName,
    this.recipientPhone,
  });

  bool get isGps => type == AddressType.gps;
  bool get isManual => type == AddressType.manual;
  bool get hasCoords => latitude != null && longitude != null;

  /// Display label for UI
  String get displayLabel {
    if (recipientName != null && recipientName!.isNotEmpty) {
      return 'Delivering to: $recipientName';
    }
    return isGps ? 'My Location' : 'Other Address';
  }

  /// Address summary for order confirmation
  String get fullAddressSummary {
    if (landmark.isNotEmpty) return '$address\nNear: $landmark';
    return address;
  }

  /// Copy with updated fields
  DeliveryAddress copyWith({
    AddressType? type,
    String? address,
    String? landmark,
    double? latitude,
    double? longitude,
    double? distanceKm,
    String? recipientName,
    String? recipientPhone,
  }) {
    return DeliveryAddress(
      type: type ?? this.type,
      address: address ?? this.address,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'address': address,
    'landmark': landmark,
    'latitude': latitude,
    'longitude': longitude,
    'distance_km': distanceKm,
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
  };

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      type: json['type'] == 'gps' ? AddressType.gps : AddressType.manual,
      address: json['address'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
    );
  }

  /// Empty/default address
  static const DeliveryAddress empty = DeliveryAddress(
    type: AddressType.manual,
    address: '',
    landmark: '',
  );
}
