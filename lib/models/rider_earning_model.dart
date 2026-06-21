class RiderEarningModel {
  final String id;
  final String riderId;
  final String orderId;
  final double amount;
  final DateTime earnedAt;
  final bool isPaid;
  final DateTime? paidAt;
  final int tipAmount;

  RiderEarningModel({
    required this.id,
    required this.riderId,
    required this.orderId,
    required this.amount,
    required this.earnedAt,
    required this.isPaid,
    this.paidAt,
    this.tipAmount = 0,
  });

  factory RiderEarningModel.fromMap(Map<String, dynamic> map) {
    return RiderEarningModel(
      id: map['id'] ?? '',
      riderId: map['rider_id'] ?? '',
      orderId: map['order_id'] ?? '',
      amount: (map['amount'] ?? 15).toDouble(),
      earnedAt: DateTime.parse(map['earned_at']),
      isPaid: map['is_paid'] ?? false,
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at']) : null,
      tipAmount: (map['tip_amount'] as num?)?.toInt() ?? 0,
    );
  }
}
