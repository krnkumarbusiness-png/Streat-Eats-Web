import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationSender {
  static final _supabase = Supabase.instance.client;

  static Map<String, String> _authHeaders() {
    final session = _supabase.auth.currentSession;
    if (session == null) return {};
    return {'Authorization': 'Bearer ${session.accessToken}'};
  }

  static Future<void> _send({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'data': {'user_id': userId, 'type': type, ...?extraData},
        },
        headers: _authHeaders(),
      );
    } catch (_) {}
  }

  static Future<void> sendOrderStatusNotification({
    required String customerId,
    required String orderId,
    required String shortId,
    required String status,
    required String vendorName,
  }) async {
    final messages = <String, (String, String)>{
      'placed': (
        'Order Placed! ✅',
        'Your order #$shortId has been placed successfully.',
      ),
      'accepted': (
        'Rider Assigned! 🤝',
        'A rider is heading to $vendorName to pick up your order.',
      ),
      'preparing': (
        'Being Prepared 👨‍🍳',
        'Your order from $vendorName is being freshly prepared!',
      ),
      'picked_up': (
        'Rider Picked Up 🛵',
        'Your rider has picked up your order and is on the way!',
      ),
      'on_the_way': (
        'Almost There! 🚀',
        'Your order is nearby. Get ready to receive it!',
      ),
      'delivered': (
        'Delivered! 🎉',
        'Your order from $vendorName has been delivered. Enjoy!',
      ),
      'cancelled': (
        'Order Cancelled ❌',
        'Your order #$shortId has been cancelled. Contact us for help.',
      ),
    };
    final msg = messages[status];
    if (msg == null) return;
    await _send(
      userId: customerId,
      title: msg.$1,
      body: msg.$2,
      type: 'order_update',
      extraData: {'order_id': orderId, 'status': status},
    );
  }

  static Future<void> newOrderToAdmin({
    required String adminUserId,
    required String orderShortId,
    required String vendorName,
    required double amount,
  }) async {
    await _send(
      userId: adminUserId,
      title: '🔔 New Order! #$orderShortId',
      body: '$vendorName — ₹${amount.toStringAsFixed(0)} — Assign rider now!',
      type: 'new_order',
      extraData: {'order_short_id': orderShortId},
    );
  }

  static Future<void> orderAcceptedToCustomer({
    required String customerId,
    required String riderName,
    required String orderShortId,
  }) async {
    await _send(
      userId: customerId,
      title: '✅ Rider Assigned!',
      body: '$riderName is picking up your order #$orderShortId 🛵',
      type: 'order_accepted',
      extraData: {'order_short_id': orderShortId},
    );
  }

  static Future<void> orderDeliveredToCustomer({
    required String customerId,
    required String vendorName,
  }) async {
    await _send(
      userId: customerId,
      title: '🎉 Delivered!',
      body: 'Your order from $vendorName has been delivered. Enjoy your food!',
      type: 'delivered',
    );
  }

  static Future<void> orderCancelledToCustomer({
    required String customerId,
    required String orderShortId,
  }) async {
    await _send(
      userId: customerId,
      title: '❌ Order Cancelled',
      body: 'Order #$orderShortId has been cancelled. Contact us for support.',
      type: 'cancelled',
      extraData: {'order_short_id': orderShortId},
    );
  }

  static Future<void> sendCustom({
    required String userId,
    required String title,
    required String body,
  }) async {
    await _send(userId: userId, title: title, body: body, type: 'custom');
  }

  // ✅ NEW — Send OTP notification to customer before delivery
  static Future<void> sendDeliveryOtpToCustomer({
    required String customerId,
    required String orderId,
    required String otp,
  }) async {
    await _send(
      userId: customerId,
      title: '🔐 Your Delivery OTP: $otp',
      body: 'Share this OTP with your rider to complete delivery: $otp',
      type: 'delivery_otp',
      extraData: {'order_id': orderId, 'otp': otp},
    );
  }

  static Future<void> newOrderToRider({
    required String riderId,
    required String orderShortId,
    required double amount,
    required String vendorName,
    double deliveryCharge = 15.0,
  }) async {
    await _send(
      userId: riderId,
      title: '🛵 New Order Available!',
      body:
          '#$orderShortId — $vendorName — ₹${amount.toStringAsFixed(0)} | Earn ₹${deliveryCharge.toStringAsFixed(0)}',
      type: 'new_order_available',
      extraData: {
        'order_short_id': orderShortId,
        'delivery_charge': deliveryCharge.toStringAsFixed(0),
      },
    );
  }

  // Direct FCM token se rider ko notify karo — riders.id bypass
  static Future<void> newOrderToRiderDirect({
    required String fcmToken,
    required String orderShortId,
    required double amount,
    required String vendorName,
    double deliveryCharge = 15.0,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'token': fcmToken,
          'title': '🛵 New Order Available!',
          'body':
              '#$orderShortId — $vendorName — ₹${amount.toStringAsFixed(0)} | Earn ₹${deliveryCharge.toStringAsFixed(0)}',
          'data': {
            'type': 'new_order_available',
            'order_short_id': orderShortId,
            'delivery_charge': deliveryCharge.toStringAsFixed(0),
          },
        },
        headers: _authHeaders(),
      );
    } catch (_) {}
  }

  // ✅ NEW — Rider ne reject kiya → Customer ko notify karo
  static Future<void> orderRejectedToCustomer({
    required String customerId,
    required String reason,
    required String orderShortId,
  }) async {
    await _send(
      userId: customerId,
      title: 'Order #$orderShortId — Rider Unavailable 😔',
      body: reason,
      type: 'order_rejected',
      extraData: {'order_short_id': orderShortId},
    );
  }
}
