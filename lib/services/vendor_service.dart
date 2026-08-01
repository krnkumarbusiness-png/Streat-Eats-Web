// lib/services/vendor_service.dart
// v2.5 — Shift hours ab DB (app_settings.time_slots) se dynamically load hote hain
// ✅ FIX: VendorModel static shift hours hardcoded nahi rahenge — DB se sync
// ✅ FIX: _copyWithImages() ab morningShiftActive/eveningShiftActive/discountText preserve karta hai
// ✅ All v2.4 features preserved exactly

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_model.dart';

class VendorService {
  final _client = Supabase.instance.client;

  // ── Shift hours ek baar load hote hain, cache ho jaate hain ──
  static bool _shiftHoursLoaded = false;

  Future<void> _loadShiftHoursIfNeeded() async {
    if (_shiftHoursLoaded) return;
    try {
      final data = await _client
          .from('app_settings')
          .select('time_slots')
          .limit(1)
          .maybeSingle();

      final slotsRaw = data?['time_slots'];
      if (slotsRaw != null && (slotsRaw as List).isNotEmpty) {
        final slots = slotsRaw
            .map((s) => Map<String, dynamic>.from(s as Map))
            .where((s) => s['enabled'] == true)
            .toList();

        // Admin screen jaisi hi classification: hour < 14 = morning, >= 14 = evening
        final morningSlots = slots.where((s) {
          final open = s['open'] as String? ?? '';
          final hour = int.tryParse(open.split(':')[0]) ?? -1;
          return hour >= 0 && hour < 14;
        }).toList();
        final eveningSlots = slots.where((s) {
          final open = s['open'] as String? ?? '';
          final hour = int.tryParse(open.split(':')[0]) ?? -1;
          return hour >= 14;
        }).toList();

        if (morningSlots.isNotEmpty) {
          final s = morningSlots.first;
          final openHour = int.tryParse((s['open'] as String).split(':')[0]);
          final closeHour = int.tryParse((s['close'] as String).split(':')[0]);
          if (openHour != null) VendorModel.morningStartHour = openHour;
          if (closeHour != null) VendorModel.morningEndHour = closeHour;
        }
        if (eveningSlots.isNotEmpty) {
          final s = eveningSlots.first;
          final openHour = int.tryParse((s['open'] as String).split(':')[0]);
          final closeHour = int.tryParse((s['close'] as String).split(':')[0]);
          if (openHour != null) VendorModel.eveningStartHour = openHour;
          if (closeHour != null) VendorModel.eveningEndHour = closeHour;
        }
      }
      _shiftHoursLoaded = true;
    } catch (e) {
      // DB fetch fail — hardcoded fallback (10/13/17/21) hi use hoga, crash nahi hoga
      _shiftHoursLoaded = true;
    }
  }

  Future<List<VendorModel>> getVendors({String city = 'Haldwani'}) async {
    await _loadShiftHoursIfNeeded();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final isTuesday = DateTime.now().weekday == 2;

    final data = await _client
        .from('vendors')
        .select()
        .eq('city', city)
        .eq('is_active', true)
        .or('day_off_date.is.null,day_off_date.neq.$today');

    List<VendorModel> vendors = (data as List)
        .map((e) => VendorModel.fromMap(e))
        .toList();

    if (isTuesday) {
      try {
        final settings = await _client
            .from('app_settings')
            .select('tuesday_nonveg_off')
            .limit(1)
            .maybeSingle();
        final tuesdayOff = settings?['tuesday_nonveg_off'] as bool? ?? false;
        if (tuesdayOff) {
          vendors = vendors.where((v) => v.vendorType == 'veg').toList();
        }
      } catch (_) {}
    }

    await _attachTopItemImages(vendors);
    return vendors;
  }

  // ✅ home_screen search bar ke liye all vendors (street food + restaurants)
  Future<List<VendorModel>> getAllVendors({String city = 'Haldwani'}) async {
    await _loadShiftHoursIfNeeded();
    try {
      final data = await _client.from('vendors').select().eq('city', city);
      final vendors = (data as List)
          .map((e) => VendorModel.fromMap(e))
          .toList();
      await _attachTopItemImages(vendors);
      return vendors;
    } catch (_) {
      return [];
    }
  }

  Future<List<VendorModel>> getStreetFoodVendors({String? city}) async {
    await _loadShiftHoursIfNeeded();
    // ✅ FIX: city filter optional — agar null ho to city filter nahi lagta
    var query = _client
        .from('vendors')
        .select()
        .eq('is_active', true)
        .eq('business_type', 'street_food');

    if (city != null && city.isNotEmpty) {
      query = query.eq('city', city);
    }

    final data = await query;
    final vendors = (data as List).map((e) => VendorModel.fromMap(e)).toList();
    await _attachTopItemImages(vendors);
    return vendors;
  }

  // ✅ FIX: city filter optional — DB mein city inconsistent ho sakti hai
  Future<List<VendorModel>> getRestaurants({String? city}) async {
    await _loadShiftHoursIfNeeded();
    try {
      var query = _client
          .from('vendors')
          .select()
          .eq('is_active', true)
          .eq('business_type', 'restaurant');

      if (city != null && city.isNotEmpty) {
        query = query.eq('city', city);
      }

      final data = await query;
      final vendors = (data as List)
          .map((e) => VendorModel.fromMap(e))
          .toList();
      await _attachTopItemImages(vendors);
      return vendors;
    } catch (e) {
      // Fallback: fetch all active vendors and filter by business_type locally
      try {
        final data = await _client
            .from('vendors')
            .select()
            .eq('is_active', true);
        final all = (data as List).map((e) => VendorModel.fromMap(e)).toList();
        final restaurants = all
            .where((v) => v.businessType == 'restaurant')
            .toList();
        await _attachTopItemImages(restaurants);
        return restaurants;
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<VendorModel>> getVendorsByCategory({
    required String category,
    String city = 'Haldwani',
    String? businessType,
  }) async {
    await _loadShiftHoursIfNeeded();
    var query = _client
        .from('vendors')
        .select()
        .eq('city', city)
        .eq('is_active', true);

    if (businessType != null) {
      query = query.eq('business_type', businessType);
    }

    final data = await query;
    List<VendorModel> vendors = (data as List)
        .map((e) => VendorModel.fromMap(e))
        .toList();

    if (category != 'All') {
      vendors = vendors.where((v) {
        final cats = v.category
            .split(',')
            .map((c) => c.trim().toLowerCase())
            .toList();
        return cats.contains(category.toLowerCase());
      }).toList();
    }

    await _attachTopItemImages(vendors);
    return vendors;
  }

  Future<List<VendorModel>> searchVendors(
    String query, {
    String city = 'Haldwani',
    String? businessType,
  }) async {
    await _loadShiftHoursIfNeeded();
    var dbQuery = _client
        .from('vendors')
        .select()
        .eq('city', city)
        .eq('is_active', true);

    if (businessType != null) {
      dbQuery = dbQuery.eq('business_type', businessType);
    }

    final data = await dbQuery;
    List<VendorModel> vendors = (data as List)
        .map((e) => VendorModel.fromMap(e))
        .toList();

    if (query.isEmpty) {
      await _attachTopItemImages(vendors);
      return vendors;
    }

    final q = query.toLowerCase();
    vendors = vendors.where((v) {
      return v.name.toLowerCase().contains(q) ||
          v.category.toLowerCase().contains(q) ||
          v.area.toLowerCase().contains(q) ||
          (v.cuisineType?.toLowerCase().contains(q) ?? false);
    }).toList();

    await _attachTopItemImages(vendors);
    return vendors;
  }

  Future<List<VendorModel>> searchVendorsByCategory({
    required String query,
    String city = 'Haldwani',
  }) async => searchVendors(query, city: city);

  Future<VendorModel?> getVendorById(String vendorId) async {
    await _loadShiftHoursIfNeeded();
    try {
      final data = await _client
          .from('vendors')
          .select()
          .eq('id', vendorId)
          .maybeSingle();

      if (data == null) return null;

      final vendor = VendorModel.fromMap(data);
      final vendors = [vendor];
      await _attachTopItemImages(vendors);
      return vendors.first;
    } catch (e) {
      return null;
    }
  }

  Future<List<VendorModel>> getSweetVendors({String? city}) async {
    await _loadShiftHoursIfNeeded();
    try {
      var query = _client
          .from('vendors')
          .select()
          .eq('is_active', true)
          .eq('business_type', 'sweets');

      if (city != null && city.isNotEmpty) {
        query = query.eq('city', city);
      }

      final data = await query;
      final vendors = (data as List)
          .map((e) => VendorModel.fromMap(e))
          .toList();
      await _attachTopItemImages(vendors);
      return vendors;
    } catch (e) {
      return [];
    }
  }

  Future<void> _attachTopItemImages(List<VendorModel> vendors) async {
    if (vendors.isEmpty) return;

    final vendorIds = vendors.map((v) => v.id).toList();

    final itemsData = await _client
        .from('menu_items')
        .select('vendor_id, image_url')
        .inFilter('vendor_id', vendorIds)
        .eq('is_available', true)
        .not('image_url', 'is', null);

    final Map<String, List<String>> imageMap = {};
    for (final item in itemsData as List) {
      final vid = item['vendor_id'] as String? ?? '';
      final url = item['image_url'] as String? ?? '';
      if (vid.isEmpty || url.isEmpty) continue;
      imageMap.putIfAbsent(vid, () => []);
      if ((imageMap[vid]!.length) < 5) {
        imageMap[vid]!.add(url);
      }
    }

    for (var i = 0; i < vendors.length; i++) {
      final images = imageMap[vendors[i].id] ?? [];
      if (images.isNotEmpty) {
        vendors[i] = _copyWithImages(vendors[i], images);
      }
    }
  }

  VendorModel _copyWithImages(VendorModel v, List<String> images) {
    return VendorModel(
      id: v.id,
      name: v.name,
      area: v.area,
      phone: v.phone,
      city: v.city,
      latitude: v.latitude,
      longitude: v.longitude,
      category: v.category,
      timing: v.timing,
      isActive: v.isActive,
      imageUrl: v.imageUrl,
      distanceKm: v.distanceKm,
      deliveryMinutes: v.deliveryMinutes,
      vendorType: v.vendorType,
      chaupatiName: v.chaupatiName,
      businessType: v.businessType,
      cuisineType: v.cuisineType,
      priceForTwo: v.priceForTwo,
      otherPlatformAvg: v.otherPlatformAvg,
      minOrder: v.minOrder,
      vendorBadge: v.vendorBadge,
      rating: v.rating,
      topItemImages: images,
      specialtyCategory: v.specialtyCategory,
      morningShiftActive: v.morningShiftActive,
      eveningShiftActive: v.eveningShiftActive,
      openTime: v.openTime, // ✅ NEW
      closeTime: v.closeTime, // ✅ NEW
      discountText: v.discountText,
    );
  }
}
