import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

// ── Background Handler ────────────────────────────────────────
// On web this is handled by firebase-messaging-sw.js (not this function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Web does not support this background handler path.
  if (kIsWeb) return;

  final localNotif = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotif.initialize(
    const InitializationSettings(android: androidSettings),
  );

  const channel = AndroidNotificationChannel(
    'street_eats_high',
    'Streat Eats Notifications',
    description: 'Order updates and offers from Streat Eats',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
    enableLights: true,
  );

  final androidPlugin = localNotif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(channel);

  final notifTitle =
      message.data['title'] ?? message.notification?.title ?? 'Streat Eats';
  final notifBody = message.data['body'] ?? message.notification?.body ?? '';

  if (notifTitle.isEmpty && notifBody.isEmpty) return;

  await localNotif.show(
    message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    notifTitle,
    notifBody,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'street_eats_high',
        'Streat Eats Notifications',
        channelDescription: 'Order updates and offers from Streat Eats',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(notifBody),
      ),
    ),
  );
}

class NotificationService {
  final _supabase = Supabase.instance.client;
  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  // ── Singleton ─────────────────────────────────────────────
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Track karo ki init ho chuka hai — baar baar mat karo
  bool _initialized = false;

  // ── INIT ─────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return; // Already init ho chuka hai — skip
    _initialized = true;

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Android-only: notification channels and local notifications setup
    if (!kIsWeb) {
      const channel = AndroidNotificationChannel(
        'street_eats_high',
        'Streat Eats Notifications',
        description: 'Order updates and offers from Streat Eats',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
      );

      final androidPlugin = _localNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(channel);

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      await _localNotif.initialize(
        const InitializationSettings(android: androidSettings),
      );
    }

    // Token refresh listener — jab bhi FCM naya token de
    _fcm.onTokenRefresh.listen((token) async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _saveTokenToDb(token, userId);
      }
    });

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (!kIsWeb) {
        await _showLocalNotification(message);
      }
    });

    // Background tap — notification tap karke app khole
    // Note: koi special navigation abhi set nahi hai, future mein
    // chaho to yahan order_status_screen pe navigate kar sakte ho
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) async {},
    );
  }

  // ── Local Notification Show ───────────────────────────────
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notifTitle =
        message.data['title'] ?? message.notification?.title ?? 'Streat Eats';
    final notifBody = message.data['body'] ?? message.notification?.body ?? '';

    if (notifTitle.isEmpty && notifBody.isEmpty) return;

    final androidDetails = AndroidNotificationDetails(
      'street_eats_high',
      'Streat Eats Notifications',
      channelDescription: 'Order updates and offers from Streat Eats',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(notifBody),
    );

    await _localNotif.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      notifTitle,
      notifBody,
      NotificationDetails(android: androidDetails),
    );
  }

  // ── Core: Token ko DB mein save karo ─────────────────────
  // Yeh SINGLE function hai jo actual save karta hai
  // Dono tables ke chakkar nahi — sirf device_tokens
  Future<void> _saveTokenToDb(String token, String userId) async {
    try {
      // Pehle is user ke saare purane tokens delete karo
      await _supabase.from('device_tokens').delete().eq('user_id', userId);

      // Sirf ek fresh token insert karo
      await _supabase.from('device_tokens').insert({
        'fcm_token': token,
        'user_id': userId,
        'is_active': true,
        'user_type': 'customer',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('FCM token saved ✅ customer: $userId');
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  // ── PUBLIC: App start pe call karo (agar session already hai) ──
  // Login/signup wale refreshTokenAfterLogin() jaisa delete-fresh nahi karta —
  // sirf check karta hai ki DB mein active token hai ya nahi, nahi hai to save karta hai
  // Isse FCM token kabhi silently stale nahi rahega, chahe user kabhi logout na kare
  Future<void> refreshTokenIfNeeded() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('FCM refreshTokenIfNeeded: userId null — skipping');
      return;
    }
    try {
      final existing = await _supabase
          .from('device_tokens')
          .select('fcm_token')
          .eq('user_id', userId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      // Token already DB mein active hai — sirf current FCM token le ke
      // sync kar do (taaki token rotate ho gaya ho to bhi pakad le)
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('FCM refreshTokenIfNeeded: token null — skipping');
        return;
      }
      if (existing == null) {
        debugPrint(
          'FCM refreshTokenIfNeeded: no active token in DB — saving fresh',
        );
      }
      await _saveTokenToDb(token, userId);
    } catch (e) {
      debugPrint('FCM refreshTokenIfNeeded error: $e');
    }
  }

  // ── PUBLIC: Login/Signup ke baad yeh call karo ───────────
  // Pehla token delete karta hai taaki fresh token mile
  // Phir naya token save karta hai
  Future<void> refreshTokenAfterLogin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('FCM refreshToken: userId null — skipping');
      return;
    }

    String? token;

    // Step 1: Fresh token lene ki koshish karo
    try {
      await _fcm.deleteToken();
      token = await _fcm.getToken();
    } catch (e) {
      debugPrint('FCM deleteToken failed, getting token directly: $e');
      // deleteToken fail ho toh directly getToken try karo
      try {
        token = await _fcm.getToken();
      } catch (e2) {
        debugPrint('FCM getToken also failed: $e2');
        return;
      }
    }

    // ✅ FIX: token null bhi ho sakta hai (exception ke bina bhi) —
    // save se pehle explicit null check taaki type mismatch na ho
    if (token == null) {
      debugPrint('FCM refreshTokenAfterLogin: token null — skipping save');
      return;
    }

    await _saveTokenToDb(token, userId);
  }

  // ── Notifications Fetch ───────────────────────────────────
  Future<List<NotificationModel>> getNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List)
          .map((n) => NotificationModel.fromMap(n))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteNotification(String notifId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notifId)
        .eq('user_id', userId);
  }

  Future<void> deleteAllNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('notifications').delete().eq('user_id', userId);
  }

  Future<int> getUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAllRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> markRead(String notifId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notifId);
    } catch (_) {}
  }

  Stream<int> getUnreadStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);
    try {
      return _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .map((data) => data.where((n) => n['is_read'] == false).length);
    } catch (_) {
      return Stream.value(0);
    }
  }
}
