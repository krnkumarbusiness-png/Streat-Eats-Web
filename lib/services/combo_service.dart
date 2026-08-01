import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/combo_model.dart';

class ComboService {
  final _client = Supabase.instance.client;

  // Home screen ke liye — sirf available combos, limit 5
  Future<List<ComboModel>> getHomeCombos() async {
    try {
      final data = await _client
          .from('combos')
          .select('*, vendors!inner(is_active, city)')
          .eq('is_available', true)
          .eq('vendors.is_active', true)
          .eq('vendors.city', 'Haldwani')
          .order('sort_order')
          .limit(5);
      return (data as List).map((e) => ComboModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // View All combos list
  Future<List<ComboModel>> getAllCombos() async {
    try {
      final data = await _client
          .from('combos')
          .select()
          .eq('is_available', true)
          .order('sort_order');
      return (data as List).map((e) => ComboModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Admin ke liye — saare combos
  Future<List<ComboModel>> getAllCombosAdmin() async {
    try {
      final data = await _client.from('combos').select().order('sort_order');
      return (data as List).map((e) => ComboModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<ComboModel?> getComboById(String id) async {
    try {
      final data = await _client
          .from('combos')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return ComboModel.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // Admin — create
  Future<bool> createCombo(Map<String, dynamic> data) async {
    try {
      await _client.from('combos').insert(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Admin — update
  Future<bool> updateCombo(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('combos').update(data).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Admin — delete
  Future<bool> deleteCombo(String id) async {
    try {
      await _client.from('combos').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Toggle availability
  Future<bool> toggleAvailability(String id, bool value) async {
    try {
      await _client.from('combos').update({'is_available': value}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }
}
