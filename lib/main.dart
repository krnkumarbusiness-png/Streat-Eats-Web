import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/colors.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Portrait-lock: mobile only — no-op on web (SystemChrome is native-only)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await dotenv.load(fileName: '.env');

  await Future.wait([
    Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    ),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  ]).timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      debugPrint('Init timeout — continuing anyway');
      return [];
    },
  );
  // FCM background handler and device registration — Android/iOS only.
  // On web these require a firebase-messaging-sw.js service worker (todo).
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    NotificationService().init().catchError((e) {
      debugPrint('FCM init error: $e');
    });
    if (Supabase.instance.client.auth.currentSession != null) {
      NotificationService().refreshTokenIfNeeded().catchError((e) {
        debugPrint('FCM token refresh on app start error: $e');
      });
    }
    await _checkAndRegisterDevice();
  }
  SharedPreferences.getInstance();
  runApp(const StreetEatsApp());
}

class StreetEatsApp extends StatefulWidget {
  const StreetEatsApp({super.key});

  @override
  State<StreetEatsApp> createState() => _StreetEatsAppState();
}

class _StreetEatsAppState extends State<StreetEatsApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => const ResetPasswordScreen(),
              fullscreenDialog: true,
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final cart = CartProvider();
            cart.restoreCart(); // 👈 yahi missing tha
            return cart;
          },
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'Street Eats',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: ThemeData(
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
            onSurface: Colors.black,
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColors.primary,
            selectionColor: AppColors.primary.withOpacity(0.3),
            selectionHandleColor: AppColors.primary,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: AppColors.surface,
            contentTextStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            elevation: 4,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        builder: (context, child) {
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  if (MediaQuery.of(context).size.width > 480)
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                ],
              ),
              // Clip to prevent children from painting outside the constrained box
              clipBehavior: Clip.antiAlias,
              child: child!,
            ),
          );
        },
        home: kIsWeb ? const HomeScreen() : const SplashScreen(),
      ),
    );
  }
}

// ── Top-level function — main() se directly call hoti hai ──────
Future<void> _checkAndRegisterDevice() async {
  try {
    String deviceId = 'unknown';

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } catch (_) {
      return;
    }

    if (deviceId == 'unknown' || deviceId.isEmpty) return;

    final supabase = Supabase.instance.client;

    final existing = await supabase
        .from('device_registrations')
        .select('id, has_used_first_order_code')
        .eq('device_id', deviceId)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('device_registrations').insert({
        'device_id': deviceId,
        'user_id': supabase.auth.currentUser?.id,
        'has_used_first_order_code': false,
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId);
  } catch (_) {
    // Silent fail
  }
}
