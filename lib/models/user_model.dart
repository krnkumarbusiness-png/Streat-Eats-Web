import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  bool _isVegMode = false;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String get userName => _userData?['full_name'] ?? 'Dost';
  bool get isVegMode => _isVegMode;

  // Theme color — always orange
  Color get themeColor => const Color(0xFFFF6B35);

  // Saved delivery address
  String get savedAddress => _userData?['delivery_address'] ?? '';
  String get savedLandmark => _userData?['delivery_landmark'] ?? '';

  // ✅ FIX: notifyListeners() ko build phase mein call hone se rokna
  void _safeNotify() {
    // Agar build chal raha hai toh next frame mein notify karo
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  Future<void> fetchUserData() async {
    _isLoading = true;
    _safeNotify(); // ✅ safe notify

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _isLoading = false;
        _safeNotify();
        return;
      }
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      _userData = data;
    } catch (e) {
      debugPrint('User fetch error: $e');
    } finally {
      _isLoading = false;
      _safeNotify(); // ✅ safe notify
    }
  }

  void updateDeliveryAddress(String address, String landmark) {
    if (_userData != null) {
      _userData!['delivery_address'] = address;
      _userData!['delivery_landmark'] = landmark;
      _safeNotify();
    }
  }

  void loadVegPreference() {
    // SharedPreferences se load kar sakte ho — abhi default false
    _isVegMode = false;
  }

  void toggleVegMode() {
    _isVegMode = !_isVegMode;
    _safeNotify();
  }

  void clearUser() {
    _userData = null;
    _safeNotify();
  }
}
