import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VegFilterProvider extends ChangeNotifier {
  bool _isVegOnly = false;
  bool get isVegOnly => _isVegOnly;

  VegFilterProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isVegOnly = prefs.getBool('veg_only_filter') ?? false;
    notifyListeners();
  }

  Future<void> toggleVegFilter() async {
    _isVegOnly = !_isVegOnly;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('veg_only_filter', _isVegOnly);
    notifyListeners();
  }
}
