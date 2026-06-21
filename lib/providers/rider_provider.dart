import 'package:flutter/material.dart';
import '../models/rider_model.dart';
import '../services/rider_service.dart';

class RiderProvider extends ChangeNotifier {
  final RiderService _riderService = RiderService();

  RiderModel? _rider;
  bool _isLoading = false;
  String? _error;

  RiderModel? get rider => _rider;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isPending => _rider?.isPending ?? false;
  bool get isApproved => _rider?.isApproved ?? false;
  bool get isRejected => _rider?.isRejected ?? false;
  bool get isAvailable => _rider?.isAvailable ?? false;

  // ─── Rider Profile Fetch ───────────────────────────────────
  Future<void> fetchRiderProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rider = await _riderService.getRiderProfile();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Toggle Availability ───────────────────────────────────
  Future<void> toggleAvailability() async {
    if (_rider == null) return;
    final newVal = !_rider!.isAvailable;

    try {
      await _riderService.toggleAvailability(newVal);
      await fetchRiderProfile();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Clear ─────────────────────────────────────────────────
  void clearRider() {
    _rider = null;
    _error = null;
    notifyListeners();
  }
}
