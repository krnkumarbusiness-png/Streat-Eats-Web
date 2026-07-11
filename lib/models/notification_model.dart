class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? orderId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.orderId,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      isRead: map['is_read'] ?? false,
      orderId: map['order_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Type ke hisaab se icon
  String get icon {
    switch (type) {
      case 'order':
        return '🛵';
      case 'promo':
        return '🎉';
      case 'system':
        return '⚙️';
      default:
        return '🔔';
    }
  }
}
