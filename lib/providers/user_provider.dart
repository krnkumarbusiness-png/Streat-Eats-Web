import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String get userName => _userData?['full_name'] ?? 'Dost';

  // ── Theme color — always orange (veg toggle hat gaya) ────────
  Color get themeColor => const Color(0xFFFF6B35);

  // ── Saved delivery address ───────────────────────────────────
  String get savedAddress => _userData?['delivery_address'] ?? '';
  String get savedLandmark => _userData?['delivery_landmark'] ?? '';

  Future<void> fetchUserData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
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
      notifyListeners();
    }
  }

  void updateDeliveryAddress(String address, String landmark) {
    if (_userData != null) {
      _userData!['delivery_address'] = address;
      _userData!['delivery_landmark'] = landmark;
      notifyListeners();
    }
  }

  void clearUser() {
    _userData = null;
    notifyListeners();
  }
}
