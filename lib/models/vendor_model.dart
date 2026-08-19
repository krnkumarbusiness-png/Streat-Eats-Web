// lib/models/vendor_model.dart
// v2.4 — discountText + minimumOrder getters added for Home Screen compatibility
// ✅ NEW: discountText getter — DB field 'discount_text' se
// ✅ NEW: minimumOrder getter — existing minOrder ka alias (double? return)
// ✅ No breaking changes — all fields same as v2.3

class VendorModel {
  final String id;
  final String name;
  final String area;
  final String phone;
  final String city;
  final double latitude;
  final double longitude;
  final String category;
  final String timing;
  final bool isActive;
  final String? imageUrl;
  final String vendorType;
  final String? chaupatiName;
  final String businessType;
  final String? cuisineType;
  final int? priceForTwo;
  final int? otherPlatformAvg;
  final int minOrder;
  final String? vendorBadge;
  final double? rating;
  final String? specialtyCategory;
  final List<String> topItemImages;
  final bool morningShiftActive;
  final bool eveningShiftActive;
  final String? openTime; // ✅ NEW — "HH:mm" format, e.g. "11:00"
  final String? closeTime; // ✅ NEW — "HH:mm" format, e.g. "21:00"

  // ✅ NEW — DB field 'discount_text' (e.g. "₹30 off", "10% off")
  final String? _discountText;

  double? distanceKm;
  int? deliveryMinutes;

  VendorModel({
    required this.id,
    required this.name,
    required this.area,
    required this.phone,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.timing,
    required this.isActive,
    this.imageUrl,
    this.distanceKm,
    this.deliveryMinutes,
    this.vendorType = 'both',
    this.chaupatiName,
    this.businessType = 'street_food',
    this.cuisineType,
    this.priceForTwo,
    this.otherPlatformAvg,
    this.minOrder = 0,
    this.vendorBadge,
    this.rating,
    this.specialtyCategory,
    this.topItemImages = const [],
    this.morningShiftActive = false,
    this.eveningShiftActive = true,
    this.openTime, // ✅ NEW
    this.closeTime, // ✅ NEW
    String? discountText, // ✅ NEW
  }) : _discountText = discountText;

  bool get isRestaurant => businessType == 'restaurant';
  bool get isStreetFood => businessType == 'street_food';

  /// Current time ke hisaab se vendor available hai ya nahi
  // Static shift time ranges — app_settings se update hote hain
  static int morningStartHour = 10;
  static int morningEndHour = 13;
  static int eveningStartHour = 17;
  static int eveningEndHour = 21;

  bool get isCurrentShiftActive {
    final hour = DateTime.now().hour;
    final isMorning = hour >= morningStartHour && hour < morningEndHour;
    final isEvening = hour >= eveningStartHour && hour < eveningEndHour;
    if (isMorning && morningShiftActive) return true;
    if (isEvening && eveningShiftActive) return true;
    return false;
  }

  /// Shift badge text — "Morning Only", "Evening Only", "Both Shifts", "No Shift"
  String get shiftLabel {
    if (morningShiftActive && eveningShiftActive) return 'Morning & Evening';
    if (morningShiftActive) return 'Morning Only';
    if (eveningShiftActive) return 'Evening Only';
    return 'No Shift Set';
  }

  String get unavailableShiftMessage {
    final hour = DateTime.now().hour;
    final isMorning = hour >= morningStartHour && hour < morningEndHour;
    final isEvening = hour >= eveningStartHour && hour < eveningEndHour;
    final mLabel = '$morningStartHour:00 AM – $morningEndHour:00 AM';
    final eLabel = '$eveningStartHour:00 PM – $eveningEndHour:00 PM';
    if (isMorning && !morningShiftActive && eveningShiftActive) {
      return 'This vendor opens in the evening shift ($eLabel). Please order then.';
    }
    if (isEvening && !eveningShiftActive && morningShiftActive) {
      return 'This vendor is available in the morning shift ($mLabel). Please order then.';
    }
    if (!morningShiftActive && eveningShiftActive) {
      return 'This vendor is available in the evening shift ($eLabel). Please order then.';
    }
    if (morningShiftActive && !eveningShiftActive) {
      return 'This vendor is available in the morning shift ($mLabel). Please order then.';
    }
    return 'This vendor is not available right now. Please check back later.';
  }

  /// Check if vendor has specific custom open/close timings
  bool get hasOwnTiming =>
      (openTime != null && openTime!.isNotEmpty) &&
      (closeTime != null && closeTime!.isNotEmpty);

  /// Check if current time is within vendor's custom open hours
  bool get isWithinOwnHours {
    if (!hasOwnTiming) return isCurrentShiftActive;
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final oParts = openTime!.split(':');
      final cParts = closeTime!.split(':');
      final oMinutes = int.parse(oParts[0]) * 60 + int.parse(oParts[1]);
      final cMinutes = int.parse(cParts[0]) * 60 + int.parse(cParts[1]);
      if (oMinutes <= cMinutes) {
        return nowMinutes >= oMinutes && nowMinutes < cMinutes;
      } else {
        // Overnight shift
        return nowMinutes >= oMinutes || nowMinutes < cMinutes;
      }
    } catch (_) {
      return isCurrentShiftActive;
    }
  }

  /// Master open status: Active and within shift/hours
  bool get isOpenNow {
    if (!isActive) return false;
    if (hasOwnTiming) return isWithinOwnHours;
    return isCurrentShiftActive;
  }

  /// Minutes until next open shift
  int? get opensInMinutes {
    if (isOpenNow) return null;
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      if (hasOwnTiming) {
        final oParts = openTime!.split(':');
        final oMinutes = int.parse(oParts[0]) * 60 + int.parse(oParts[1]);
        if (oMinutes > nowMinutes) {
          return oMinutes - nowMinutes;
        }
      } else {
        if (morningShiftActive && now.hour < morningStartHour) {
          return (morningStartHour * 60) - nowMinutes;
        }
        if (eveningShiftActive && now.hour < eveningStartHour) {
          return (eveningStartHour * 60) - nowMinutes;
        }
      }
    } catch (_) {}
    return null;
  }

  String? get opensInLabel {
    final mins = opensInMinutes;
    if (mins != null && mins > 0) {
      return 'Opens in $mins min';
    }
    return null;
  }

  String? get timingRangeLabel {
    if (hasOwnTiming) {
      return '$openTime – $closeTime';
    }
    if (timing.isNotEmpty) return timing;
    return null;
  }

  /// Categories as list of strings
  List<String> get categories {
    if (category.isEmpty) return [];
    return category
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  /// Delivery time label
  String get deliveryTime {
    if (deliveryMinutes != null && deliveryMinutes! > 0) {
      return '$deliveryMinutes min';
    }
    return '20-30 min';
  }

  String get unavailableTimingMessage => unavailableShiftMessage;

  // ✅ NEW — Home screen discount tag ke liye
  String? get discountText => _discountText;

  // ✅ NEW — Home screen minimumOrder ke liye (minOrder ka double? alias)
  double? get minimumOrder => minOrder > 0 ? minOrder.toDouble() : null;

  /// Kitna % sasta hai humara platform vs baaki — 0 if not applicable
  int get savingsPercent {
    if (!isRestaurant) return 0;
    if (otherPlatformAvg == null || priceForTwo == null) return 0;
    if (otherPlatformAvg! <= 0 || priceForTwo! <= 0) return 0;
    final pct = (((otherPlatformAvg! - priceForTwo!) / otherPlatformAvg!) * 100)
        .round();
    return pct.clamp(0, 99);
  }

  /// Display label for price — "₹X/person" format
  String get pricePerPersonLabel {
    if (priceForTwo == null) return '';
    return '₹$priceForTwo';
  }

  /// Display label for other platforms avg
  String get otherPlatformLabel {
    if (otherPlatformAvg == null) return '';
    return '₹$otherPlatformAvg';
  }

  bool showInVegMode() => vendorType == 'veg' || vendorType == 'both';
  bool showInNonVegMode() => true;

  factory VendorModel.fromMap(Map<String, dynamic> map) {
    List<String> parseTopImages(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .take(5)
            .toList();
      }
      return [];
    }

    return VendorModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      area: map['area'] ?? '',
      phone: map['phone'] ?? '',
      city: map['city'] ?? 'Haldwani',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      category: map['category'] ?? '',
      timing: map['timing'] ?? '',
      isActive: map['is_active'] as bool? ?? false,
      imageUrl: map['image_url'] as String?,
      vendorType: map['vendor_type'] as String? ?? 'both',
      chaupatiName: map['chaupati_name'] as String?,
      businessType: map['business_type'] as String? ?? 'street_food',
      cuisineType: map['cuisine_type'] as String?,
      priceForTwo: (map['price_for_two'] as num?)?.toInt(),
      otherPlatformAvg: (map['other_platform_avg'] as num?)?.toInt(),
      minOrder: (map['min_order'] as num?)?.toInt() ?? 0,
      vendorBadge: map['vendor_badge'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      topItemImages: parseTopImages(map['top_item_images']),
      discountText: map['discount_text'] as String?,
      specialtyCategory: map['specialty_category'] as String?,
      morningShiftActive: map['morning_shift_active'] as bool? ?? false,
      eveningShiftActive: map['evening_shift_active'] as bool? ?? true,
      openTime: map['open_time'] as String?, // ✅ NEW
      closeTime: map['close_time'] as String?, // ✅ NEW
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'area': area,
    'phone': phone,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
    'timing': timing,
    'is_active': isActive,
    'image_url': imageUrl,
    'vendor_type': vendorType,
    'chaupati_name': chaupatiName,
    'business_type': businessType,
    'cuisine_type': cuisineType,
    'price_for_two': priceForTwo,
    'other_platform_avg': otherPlatformAvg,
    'min_order': minOrder,
    'vendor_badge': vendorBadge,
    'rating': rating,
    'top_item_images': topItemImages,
    'discount_text': _discountText,
    'specialty_category': specialtyCategory,
    'morning_shift_active': morningShiftActive,
    'evening_shift_active': eveningShiftActive,
    'open_time': openTime, // ✅ NEW
    'close_time': closeTime, // ✅ NEW
  };
}
