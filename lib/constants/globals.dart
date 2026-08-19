import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class CartVisibilityControl {
  static final ValueNotifier<int> hideCount = ValueNotifier(0);
  
  static void hide() {
    hideCount.value++;
  }
  
  static void show() {
    // Clamp to prevent negative values from mismatched hide/show calls
    if (hideCount.value > 0) {
      hideCount.value--;
    }
  }
}

