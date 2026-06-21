// ═══════════════════════════════════════════════════════════
// STREAT EATS — Float Service
// Handles all rider float + cash log + settlement logic
// Uses Supabase RPC + direct table operations
// ═══════════════════════════════════════════════════════════

import 'package:supabase_flutter/supabase_flutter.dart';

class FloatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────────────────
  // GET: Aaj ka sab riders ka float summary
  // Admin float management screen ke liye
  // ─────────────────────────────────────────────────────────
  Future<List<RiderFloatSummary>> getTodayFloatSummary() async {
    try {
      final response = await _supabase.rpc('get_rider_float_summary').select();

      return (response as List)
          .map((e) => RiderFloatSummary.fromMap(e))
          .toList();
    } catch (e) {
      throw Exception('Float summary fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // GET: Specific date ka float summary
  // ─────────────────────────────────────────────────────────
  Future<List<RiderFloatSummary>> getFloatSummaryByDate(DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _supabase
          .rpc('get_rider_float_summary', params: {'target_date': dateStr})
          .select();

      return (response as List)
          .map((e) => RiderFloatSummary.fromMap(e))
          .toList();
    } catch (e) {
      throw Exception('Float summary fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // SET: Rider ko float assign karo (day start pe)
  // Admin manually karta hai ya auto hota hai
  // ─────────────────────────────────────────────────────────
  Future<void> assignFloat({
    required String riderId,
    required double floatAmount,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _supabase.from('rider_float').upsert({
        'rider_id': riderId,
        'float_amount': floatAmount,
        'date': dateStr,
        'is_active': true,
      }, onConflict: 'rider_id,date');
    } catch (e) {
      throw Exception('Float assign failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // LOG: Order complete hone pe cash log entry
  // rider_service.dart se call hoga jab order deliver ho
  // ─────────────────────────────────────────────────────────
  Future<void> logCashTransaction({
    required String riderId,
    required String orderId,
    required double vendorPaid,
    required double customerCollected,
  }) async {
    try {
      await _supabase.from('rider_cash_log').insert({
        'rider_id': riderId,
        'order_id': orderId,
        'vendor_paid': vendorPaid,
        'customer_collected': customerCollected,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Cash log failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // SETTLE: Rider ka day end settlement mark karo
  // "Mark as Settled" button press pe
  // ─────────────────────────────────────────────────────────
  Future<void> markAsSettled({
    required String riderId,
    required double settlementAmount,
    required double floatGiven,
    required int ordersCount,
    String? notes,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Settlement record insert karo
      await _supabase.from('rider_settlements').insert({
        'rider_id': riderId,
        'amount': settlementAmount,
        'float_given': floatGiven,
        'orders_count': ordersCount,
        'settled_at': DateTime.now().toIso8601String(),
        'settled_by': _supabase.auth.currentUser?.id,
        'notes': notes,
        'date': dateStr,
      });

      // Float ko inactive mark karo — aaj ka done
      await _supabase
          .from('rider_float')
          .update({'is_active': false})
          .eq('rider_id', riderId)
          .eq('date', dateStr);
    } catch (e) {
      throw Exception('Settlement failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // GET: Rider ki settlement history
  // ─────────────────────────────────────────────────────────
  Future<List<SettlementHistory>> getSettlementHistory(String riderId) async {
    try {
      final response = await _supabase
          .from('rider_settlements')
          .select('''
            id,
            amount,
            float_given,
            orders_count,
            settled_at,
            notes,
            date
          ''')
          .eq('rider_id', riderId)
          .order('settled_at', ascending: false)
          .limit(30);

      return (response as List)
          .map((e) => SettlementHistory.fromMap(e))
          .toList();
    } catch (e) {
      throw Exception('Settlement history fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // GET: Aaj ka cash log — specific rider ka
  // ─────────────────────────────────────────────────────────
  Future<List<CashLogEntry>> getTodayCashLog(String riderId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String();
      final endOfDay = DateTime(
        today.year,
        today.month,
        today.day,
        23,
        59,
        59,
      ).toIso8601String();

      final response = await _supabase
          .from('rider_cash_log')
          .select('''
            id,
            order_id,
            vendor_paid,
            customer_collected,
            timestamp
          ''')
          .eq('rider_id', riderId)
          .gte('timestamp', startOfDay)
          .lte('timestamp', endOfDay)
          .order('timestamp', ascending: false);

      return (response as List).map((e) => CashLogEntry.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Cash log fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // GET: All riders ki aaj settlement ho gayi ya nahi
  // Quick status check ke liye
  // ─────────────────────────────────────────────────────────
  Future<Map<String, bool>> getTodaySettlementStatus() async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('rider_settlements')
          .select('rider_id')
          .eq('date', dateStr);

      final Map<String, bool> statusMap = {};
      for (final row in (response as List)) {
        statusMap[row['rider_id'].toString()] = true;
      }
      return statusMap;
    } catch (e) {
      throw Exception('Settlement status fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // GET: Approved riders list — Assign Float sheet ke liye
  // ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getApprovedRiders() async {
    try {
      final response = await _supabase
          .from('riders')
          .select('id, full_name, phone, rider_phone, status')
          .eq('status', 'approved')
          .order('full_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Riders fetch failed: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════
// DATA MODELS — Float ke liye local models
// (Full models Step 4 mein aayenge, yeh sirf service ke liye)
// ═══════════════════════════════════════════════════════════

class RiderFloatSummary {
  final String riderId;
  final String riderName;
  final String riderPhone;
  final double floatAmount;
  final double totalVendorPaid;
  final double totalCollected;
  final double currentBalance;
  final double settlementAmount;
  final int ordersCount;
  final bool isSettled;

  RiderFloatSummary({
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.floatAmount,
    required this.totalVendorPaid,
    required this.totalCollected,
    required this.currentBalance,
    required this.settlementAmount,
    required this.ordersCount,
    required this.isSettled,
  });

  factory RiderFloatSummary.fromMap(Map<String, dynamic> map) {
    return RiderFloatSummary(
      riderId: map['rider_id']?.toString() ?? '',
      riderName: map['rider_name']?.toString() ?? 'Unknown',
      riderPhone: map['rider_phone']?.toString() ?? '',
      floatAmount: (map['float_amount'] as num?)?.toDouble() ?? 500.0,
      totalVendorPaid: (map['total_vendor_paid'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (map['total_collected'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      settlementAmount: (map['settlement_amount'] as num?)?.toDouble() ?? 0.0,
      ordersCount: (map['orders_count'] as num?)?.toInt() ?? 0,
      isSettled: map['is_settled'] as bool? ?? false,
    );
  }
}

class SettlementHistory {
  final String id;
  final double amount;
  final double floatGiven;
  final int ordersCount;
  final DateTime settledAt;
  final String? notes;
  final DateTime date;

  SettlementHistory({
    required this.id,
    required this.amount,
    required this.floatGiven,
    required this.ordersCount,
    required this.settledAt,
    this.notes,
    required this.date,
  });

  factory SettlementHistory.fromMap(Map<String, dynamic> map) {
    return SettlementHistory(
      id: map['id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      floatGiven: (map['float_given'] as num?)?.toDouble() ?? 500.0,
      ordersCount: (map['orders_count'] as num?)?.toInt() ?? 0,
      settledAt: DateTime.parse(
        map['settled_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      notes: map['notes']?.toString(),
      date: DateTime.parse(
        map['date']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class CashLogEntry {
  final String id;
  final String? orderId;
  final double vendorPaid;
  final double customerCollected;
  final DateTime timestamp;

  CashLogEntry({
    required this.id,
    this.orderId,
    required this.vendorPaid,
    required this.customerCollected,
    required this.timestamp,
  });

  factory CashLogEntry.fromMap(Map<String, dynamic> map) {
    return CashLogEntry(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString(),
      vendorPaid: (map['vendor_paid'] as num?)?.toDouble() ?? 0.0,
      customerCollected: (map['customer_collected'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(
        map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
