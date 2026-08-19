class RiderModel {
  final String id;
  final String fullName;
  final String phone;
  final String vehicleType;
  final String area;
  final String? upiId;
  final String status; // pending, approved, rejected
  final bool isAvailable;
  final double totalEarnings;
  final String? rejectionReason;
  final DateTime createdAt;

  RiderModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.area,
    this.upiId,
    required this.status,
    required this.isAvailable,
    required this.totalEarnings,
    this.rejectionReason,
    required this.createdAt,
  });

  factory RiderModel.fromMap(Map<String, dynamic> map) {
    return RiderModel(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      phone: map['phone'] ?? '',
      vehicleType: map['vehicle_type'] ?? '',
      area: map['area'] ?? '',
      upiId: map['upi_id'],
      status: map['status'] ?? 'pending',
      isAvailable: map['is_available'] ?? false,
      totalEarnings: (map['total_earnings'] ?? 0).toDouble(),
      rejectionReason: map['rejection_reason'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'phone': phone,
      'vehicle_type': vehicleType,
      'area': area,
      'upi_id': upiId,
      'status': status,
      'is_available': isAvailable,
      'total_earnings': totalEarnings,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
