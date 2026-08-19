import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================================
// FILE: lib/services/location_service.dart
// v2.1 — Added getCurrentPosition() alias + distanceBetween() wrapper
// ✅ NEW: getCurrentPosition() — alias for getCurrentLocation()
// ✅ NEW: distanceBetween() — instance wrapper for Geolocator.distanceBetween()
// ✅ All v2.0 features 100% preserved
// ================================================================

class LocationService {
  // ── Permission ka current status check karo (no request) ────
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  // ── Location service enabled hai? ───────────────────────────
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // ── Permission granted hai? ──────────────────────────────────
  Future<bool> hasPermission() async {
    final status = await Geolocator.checkPermission();
    return status == LocationPermission.always ||
        status == LocationPermission.whileInUse;
  }

  // ── Sirf permission request karo — location nahi ───────────
  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    if (permission == LocationPermission.deniedForever) return false;

    permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ── Permission denied forever hai? ──────────────────────────
  Future<bool> isPermanentlyDenied() async {
    final status = await Geolocator.checkPermission();
    return status == LocationPermission.deniedForever;
  }

  // ── Permission handle karo + location fetch karo ─────────────
  Future<bool> _handlePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location service disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied');
      return false;
    }

    return true;
  }

  // ── Current location fetch karo ─────────────────────────────
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermissionResult = await _handlePermission();
      if (!hasPermissionResult) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Location fetch error: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // ✅ v2.1 NEW — Alias for getCurrentLocation()
  // home_screen.dart v21.1 uses getCurrentPosition() — this is the fix
  Future<Position?> getCurrentPosition() => getCurrentLocation();

  // ── Distance calculate karo ──────────────────────────────────
  double getDistanceKm(
    double userLat,
    double userLng,
    double vendorLat,
    double vendorLng,
  ) {
    final meters = Geolocator.distanceBetween(
      userLat,
      userLng,
      vendorLat,
      vendorLng,
    );
    return meters / 1000;
  }

  // ✅ v2.1 NEW — Instance wrapper for Geolocator.distanceBetween()
  // home_screen.dart v21.1 calls _locationService.distanceBetween(...) — this is the fix
  // Returns distance in METERS (same as Geolocator.distanceBetween)
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // ── Delivery time estimate ───────────────────────────────────
  int getDeliveryMinutes(double distanceKm) {
    return (distanceKm * 4).round() + 5;
  }

  // ── Always deliverable ───────────────────────────────────────
  bool isDeliverable(double distanceKm) => true;

  // ── Settings screen pe location open karo ───────────────────
  // NOTE: Not supported on web — no-op with debug log
  Future<void> openLocationSettings() async {
    if (kIsWeb) {
      debugPrint('LocationService: openLocationSettings() not supported on web');
      return;
    }
    await Geolocator.openLocationSettings();
  }

  // ── App settings pe jaao (permanently denied ke liye) ───────
  // NOTE: Not supported on web — no-op with debug log
  Future<void> openAppSettings() async {
    if (kIsWeb) {
      debugPrint('LocationService: openAppSettings() not supported on web');
      return;
    }
    await Geolocator.openAppSettings();
  }

  // ════════════════════════════════════════════════════════════
  // v2.0 — Delivery Zone Check
  // Supabase app_settings se center + radius fetch karke check
  // ════════════════════════════════════════════════════════════

  // ── User delivery zone ke andar hai ya nahi ─────────────────
  // Returns true = order allowed
  // Returns true bhi — agar location na mile ya settings error ho
  Future<bool> isWithinDeliveryZone({Position? existingPosition}) async {
    try {
      final position = existingPosition ?? await getCurrentLocation();
      if (position == null) {
        debugPrint('Zone check: location null — allowing');
        return true;
      }

      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('app_settings')
          .select(
            'delivery_center_lat, delivery_center_lng, delivery_radius_km',
          )
          .limit(1)
          .maybeSingle();

      if (data == null) {
        debugPrint('Zone check: no settings — allowing');
        return true;
      }

      final centerLat =
          (data['delivery_center_lat'] as num?)?.toDouble() ?? 29.2183;
      final centerLng =
          (data['delivery_center_lng'] as num?)?.toDouble() ?? 79.5130;
      final radiusKm = (data['delivery_radius_km'] as num?)?.toDouble() ?? 15.0;

      final distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        centerLat,
        centerLng,
      );

      final distanceKm = distanceMeters / 1000;
      final inZone = distanceKm <= radiusKm;

      debugPrint(
        'Zone check: ${distanceKm.toStringAsFixed(2)}km, radius: ${radiusKm}km, inZone: $inZone',
      );

      return inZone;
    } catch (e) {
      debugPrint('Zone check error: $e — allowing');
      return true;
    }
  }

  // ════════════════════════════════════════════════════════════
  // v2.0 — Dynamic Delivery Charge Calculator
  // Supabase se slabs fetch karo, distance ke hisaab se charge do
  // 5km+ = base_charge + (extra_km * per_km_rate)
  // ════════════════════════════════════════════════════════════

  static double calculateDeliveryCharge(
    double distanceKm, {
    Map<String, dynamic>? settings,
  }) {
    if (settings == null) {
      return _fallbackCharge(distanceKm);
    }

    try {
      if (distanceKm <= 1.0) {
        return (settings['delivery_charge_0_1'] as num?)?.toDouble() ?? 0;
      }
      if (distanceKm <= 2.0) {
        return (settings['delivery_charge_1_2'] as num?)?.toDouble() ?? 10;
      }
      if (distanceKm <= 3.0) {
        return (settings['delivery_charge_2_3'] as num?)?.toDouble() ?? 20;
      }
      if (distanceKm <= 4.0) {
        return (settings['delivery_charge_3_4'] as num?)?.toDouble() ?? 30;
      }
      if (distanceKm <= 5.0) {
        return (settings['delivery_charge_4_5'] as num?)?.toDouble() ?? 40;
      }

      final baseCharge =
          (settings['delivery_charge_5km_base'] as num?)?.toDouble() ?? 70.0;
      final perKmRate =
          (settings['delivery_charge_per_km_after_5'] as num?)?.toDouble() ??
          10.0;
      final extraKm = distanceKm - 5.0;
      return baseCharge + (extraKm * perKmRate);
    } catch (e) {
      debugPrint('Charge calc error: $e');
      return _fallbackCharge(distanceKm);
    }
  }

  static double _fallbackCharge(double distanceKm) {
    if (distanceKm <= 1.0) return 0;
    if (distanceKm <= 2.0) return 10;
    if (distanceKm <= 3.0) return 20;
    if (distanceKm <= 4.0) return 30;
    if (distanceKm <= 5.0) return 40;
    return 70.0 + ((distanceKm - 5.0) * 10.0);
  }

  Future<double> getDeliveryCharge(double distanceKm) async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('app_settings')
          .select(
            'delivery_charge_0_1, delivery_charge_1_2, delivery_charge_2_3, '
            'delivery_charge_3_4, delivery_charge_4_5, '
            'delivery_charge_5km_base, delivery_charge_per_km_after_5',
          )
          .limit(1)
          .maybeSingle();

      return calculateDeliveryCharge(distanceKm, settings: data);
    } catch (e) {
      debugPrint('getDeliveryCharge error: $e');
      return _fallbackCharge(distanceKm);
    }
  }

  static String formatDeliveryCharge(double charge) {
    if (charge == 0) return 'Free';
    return '₹${charge.toStringAsFixed(0)}';
  }

  static String deliveryChargeLabel(
    double distanceKm, {
    Map<String, dynamic>? settings,
  }) {
    final charge = calculateDeliveryCharge(distanceKm, settings: settings);
    return formatDeliveryCharge(charge);
  }
}
