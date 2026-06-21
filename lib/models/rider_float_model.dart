// ═══════════════════════════════════════════════════════════
// STREAT EATS — Rider Float Model
// Float assignment + cash log + settlement data models
// ═══════════════════════════════════════════════════════════

class RiderFloatModel {
  final String id;
  final String riderId;
  final double floatAmount;
  final DateTime date;
  final bool isActive;
  final DateTime createdAt;

  RiderFloatModel({
    required this.id,
    required this.riderId,
    required this.floatAmount,
    required this.date,
    required this.isActive,
    required this.createdAt,
  });

  factory RiderFloatModel.fromMap(Map<String, dynamic> map) {
    return RiderFloatModel(
      id: map['id']?.toString() ?? '',
      riderId: map['rider_id']?.toString() ?? '',
      floatAmount: (map['float_amount'] as num?)?.toDouble() ?? 500.0,
      date: DateTime.parse(
        map['date']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(
        map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rider_id': riderId,
      'float_amount': floatAmount,
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────
class RiderCashLogModel {
  final String id;
  final String riderId;
  final String? orderId;
  final double vendorPaid;
  final double customerCollected;
  final DateTime timestamp;

  RiderCashLogModel({
    required this.id,
    required this.riderId,
    this.orderId,
    required this.vendorPaid,
    required this.customerCollected,
    required this.timestamp,
  });

  // Net cash change for this transaction
  double get netCash => customerCollected - vendorPaid;

  factory RiderCashLogModel.fromMap(Map<String, dynamic> map) {
    return RiderCashLogModel(
      id: map['id']?.toString() ?? '',
      riderId: map['rider_id']?.toString() ?? '',
      orderId: map['order_id']?.toString(),
      vendorPaid: (map['vendor_paid'] as num?)?.toDouble() ?? 0.0,
      customerCollected: (map['customer_collected'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(
        map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rider_id': riderId,
      'order_id': orderId,
      'vendor_paid': vendorPaid,
      'customer_collected': customerCollected,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────
class RiderSettlementModel {
  final String id;
  final String riderId;
  final double amount;
  final double floatGiven;
  final int ordersCount;
  final DateTime settledAt;
  final String? settledBy;
  final String? notes;
  final DateTime date;

  RiderSettlementModel({
    required this.id,
    required this.riderId,
    required this.amount,
    required this.floatGiven,
    required this.ordersCount,
    required this.settledAt,
    this.settledBy,
    this.notes,
    required this.date,
  });

  // Settlement status label
  String get amountLabel {
    if (amount > 0) return 'Rs.${amount.toStringAsFixed(0)} Jama Kiya';
    if (amount < 0) {
      return 'Rs.${amount.abs().toStringAsFixed(0)} Dena Tha';
    }
    return 'Zero Settlement';
  }

  factory RiderSettlementModel.fromMap(Map<String, dynamic> map) {
    return RiderSettlementModel(
      id: map['id']?.toString() ?? '',
      riderId: map['rider_id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      floatGiven: (map['float_given'] as num?)?.toDouble() ?? 500.0,
      ordersCount: (map['orders_count'] as num?)?.toInt() ?? 0,
      settledAt: DateTime.parse(
        map['settled_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      settledBy: map['settled_by']?.toString(),
      notes: map['notes']?.toString(),
      date: DateTime.parse(
        map['date']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rider_id': riderId,
      'amount': amount,
      'float_given': floatGiven,
      'orders_count': ordersCount,
      'settled_at': settledAt.toIso8601String(),
      'settled_by': settledBy,
      'notes': notes,
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    };
  }
}
