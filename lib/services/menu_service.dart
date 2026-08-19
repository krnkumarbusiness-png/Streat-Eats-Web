// lib/services/menu_service.dart
// v3.0 — getAllMenuItems function added

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item_model.dart';

class MenuService {
  final _client = Supabase.instance.client;

  // Vendor ke saare available menu items
  Future<List<MenuItemModel>> getMenuItems(String vendorId) async {
    final data = await _client
        .from('menu_items')
        .select()
        .eq('vendor_id', vendorId)
        .eq('is_available', true);

    return (data as List).map((e) => MenuItemModel.fromMap(e)).toList();
  }

  // ✅ Home Screen "Recommended For You" section ke liye
  Future<List<MenuItemModel>> getRecommendedItems() async {
    final data = await _client
        .from('menu_items')
        .select()
        .eq('is_recommended_home', true)
        .eq('is_available', true)
        .order('created_at', ascending: false)
        .limit(10);

    return (data as List).map((e) => MenuItemModel.fromMap(e)).toList();
  }

  // ✅ NEW v3.0 — Category filter fallback ke liye
  Future<List<MenuItemModel>> getAllMenuItems() async {
    final data = await _client
        .from('menu_items')
        .select('*, vendors!inner(city, is_active)')
        .eq('is_available', true)
        .eq('vendors.city', 'Haldwani')
        .eq('vendors.is_active', true)
        .order('created_at', ascending: false);

    return (data as List).map((e) => MenuItemModel.fromMap(e)).toList();
  }

  // ✅ Search screen ke liye — vendor ID se grouped items
  Future<Map<String, List<MenuItemModel>>> fetchAllMenuItemsGrouped() async {
    try {
      final data = await _client
          .from('menu_items')
          .select()
          .eq('is_available', true)
          .order('name', ascending: true);

      final Map<String, List<MenuItemModel>> grouped = {};
      for (final row in data as List) {
        final item = MenuItemModel.fromMap(row as Map<String, dynamic>);
        grouped.putIfAbsent(item.vendorId, () => []).add(item);
      }
      return grouped;
    } catch (e) {
      return {};
    }
  }

  // ✅ Home Screen "Today's Best Deals" section ke liye (Admin controlled)
  Future<List<MenuItemModel>> getTodaysDeals() async {
    try {
      final data = await _client
          .from('menu_items')
          .select()
          .eq('is_todays_deal', true)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(15);

      final items = (data as List).map((e) => MenuItemModel.fromMap(e)).toList();
      if (items.isNotEmpty) return items;
    } catch (_) {}

    // Fallback: If no is_todays_deal is flagged yet, show top discounted items
    try {
      final data = await _client
          .from('menu_items')
          .select()
          .eq('is_discounted', true)
          .eq('is_available', true)
          .order('app_price', ascending: true)
          .limit(10);

      return (data as List).map((e) => MenuItemModel.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ✅ Home Screen "Trending in Haldwani" section ke liye (Admin controlled)
  Future<List<MenuItemModel>> getTrendingItems() async {
    try {
      final data = await _client
          .from('menu_items')
          .select()
          .eq('is_trending', true)
          .eq('is_available', true)
          .order('trending_rank', ascending: true)
          .limit(15);

      final items = (data as List).map((e) => MenuItemModel.fromMap(e)).toList();
      if (items.isNotEmpty) return items;
    } catch (_) {}

    // Fallback: If no items are flagged as is_trending, use recent available items
    try {
      final data = await _client
          .from('menu_items')
          .select()
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(10);

      return (data as List).map((e) => MenuItemModel.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Category wise filter (local — no DB call)
  List<MenuItemModel> filterByCategory(
    List<MenuItemModel> items,
    String category,
  ) {
    if (category == 'All') return items;
    return items.where((i) => i.category == category).toList();
  }

  // Unique categories list
  List<String> getCategories(List<MenuItemModel> items) {
    final cats = items.map((i) => i.category).toSet().toList();
    return ['All', ...cats];
  }
}
