import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════
// AdminNotificationService — Refactored
// Ab direct FCM call NAHI — sirf edge function use karta hai
// Pehle wala _fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE' tha
// jo kisi ko notification nahi bhej raha tha
// ══════════════════════════════════════════════════════════════

class AdminNotificationService {
  final _supabase = Supabase.instance.client;

  static final AdminNotificationService _instance =
      AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  Map<String, String> _authHeaders() {
    final session = _supabase.auth.currentSession;
    return session != null
        ? {'Authorization': 'Bearer ${session.accessToken}'}
        : {};
  }

  Future<bool> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'data': {'type': data?['type'] ?? 'general', ...?data},
        },
        headers: _authHeaders(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendToAll({
    required String title,
    required String body,
    Map<String, String>? data,
    bool personalize = false,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'send_to_all': true,
          'title': title,
          'body': body,
          'personalize': personalize,
          'data': {'type': data?['type'] ?? 'general', ...?data},
        },
        headers: _authHeaders(),
      );
    } catch (_) {}
  }

  Future<bool> sendOrderUpdate({
    required String userId,
    required String orderId,
    required String status,
  }) async {
    final messages = <String, (String, String)>{
      'confirmed': (
        'Order Confirmed! ✅',
        'Your order has been confirmed and is being prepared.',
      ),
      'preparing': (
        'Being Prepared 👨‍🍳',
        'Your food is being freshly prepared for you!',
      ),
      'picked_up': (
        'Rider On The Way 🛵',
        'Your rider has picked up the order and is heading your way!',
      ),
      'on_the_way': (
        'Almost There! 🚀',
        'Your order is nearby. Get ready to receive it!',
      ),
      'delivered': (
        'Delivered! 🎉',
        'Your order has been delivered. Enjoy your food!',
      ),
      'cancelled': (
        'Order Cancelled ❌',
        'Your order has been cancelled. Contact us for support.',
      ),
    };
    final msg = messages[status];
    if (msg == null) return false;
    return sendToUser(
      userId: userId,
      title: msg.$1,
      body: msg.$2,
      data: {'order_id': orderId, 'type': 'order_update', 'status': status},
    );
  }

  Future<bool> sendCustomMessage({
    required String userId,
    required String title,
    required String body,
  }) async {
    return sendToUser(
      userId: userId,
      title: title,
      body: body,
      data: {'type': 'custom'},
    );
  }

  Future<void> sendPromoToAll({
    required String title,
    required String body,
  }) async {
    await sendToAll(
      title: title,
      body: body,
      data: {'type': 'promo'},
      personalize: title.contains('{name}') || body.contains('{name}'),
    );
  }
}
