import 'package:flutter/material.dart';

class EtaHelper {
  EtaHelper._();

  static const int _m1Open = 10 * 60; // 10:00 AM
  static const int _m1Close = 13 * 60; // 1:00 PM
  static const int _m2Open = 17 * 60; // 5:00 PM
  static const int _m2Close = 21 * 60; // 9:00 PM

  static bool get _isEveningShift {
    final mins = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
    return mins >= _m2Open && mins < _m2Close;
  }

  static String getEta({double? distanceKm}) {
    if (distanceKm == null) return '30-35 min';

    int base;
    if (distanceKm <= 1.0) {
      base = 28;
    } else if (distanceKm <= 2.0)
      base = 30;
    else if (distanceKm <= 3.0)
      base = 33;
    else
      base = 35;

    if (_isEveningShift) base += 3;
    base = base.clamp(28, 38);
    final max = (base + 5).clamp(30, 40);

    return '$base-$max min';
  }
}
