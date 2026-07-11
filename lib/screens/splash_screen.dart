// lib/screens/splash_screen.dart
// v6.0 — Full illustration splash (reference UI matched)
// ✅ Full-screen rider illustration — no circle crop
// ✅ Logo icon + "Streat Eats" title top section
// ✅ Animated progress bar loading indicator (reference jaisa)
// ✅ "Loading deliciousness... ❤️" text
// ✅ All navigation logic preserved from v5.0
// ✅ Role caching fix preserved

// dart:io removed — not used in this file (web-incompatible)
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/version_service.dart';
import 'home_screen.dart';
import 'force_update_screen.dart';

// ─── Brand colors (inline so splash is self-contained) ───────
class _C {
  static const primary = Color(0xFFFF6B35);
  static const background = Color(0xFFFFF8F0);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF3D3D3D);
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Stagger controllers
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _titleController;
  late AnimationController _taglineController;
  late AnimationController _imageController;
  late AnimationController _loadingController;
  late AnimationController _progressController;

  late Animation<double> _bgFade;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;

  late Animation<double> _taglineFade;

  late Animation<Offset> _imageSlide;
  late Animation<double> _imageFade;
  late Animation<double> _imageScale;

  late Animation<double> _loadingFade;

  // Progress bar — animates from 0 to 1 over ~1800ms
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
    Future.delayed(
      const Duration(milliseconds: 2400),
      _checkVersionAndNavigate,
    );
  }

  void _setupAnimations() {
    // Background fade
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bgFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeOut));

    // Logo icon bounce
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Title slide up
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
        );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Tagline fade
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );

    // Rider image slide up + scale
    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _imageSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _imageController, curve: Curves.easeOutCubic),
        );
    _imageFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _imageController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );
    _imageScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _imageController, curve: Curves.easeOutCubic),
    );

    // Loading section fade
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadingFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeOut),
    );

    // Progress bar — smooth fill
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _progress = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startSequence() async {
    _bgController.forward();

    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _titleController.forward();

    await Future.delayed(const Duration(milliseconds: 480));
    _taglineController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _imageController.forward();

    await Future.delayed(const Duration(milliseconds: 900));
    _loadingController.forward();
    _progressController.forward();
  }

  // ─── All navigation logic preserved from v5.0 ─────────────────

  Future<void> _checkVersionAndNavigate() async {
    if (!mounted) return;

    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw const SocketException('timeout'),
      );
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        _showNoInternetError();
        return;
      }
    } on SocketException catch (_) {
      _showNoInternetError();
      return;
    }

    try {
      final versionService = VersionService();
      final result = await versionService.checkVersion();

      if (!mounted) return;

      if (result.isForceUpdate) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ForceUpdateScreen(
              message: result.message,
              apkUrl: result.apkUrl,
            ),
          ),
        );
        return;
      }

      if (result.isSoftUpdate) {
        _showSoftUpdateDialog(result.message, result.apkUrl);
      }

      await _navigate();
    } catch (e) {
      debugPrint('Version check error: $e');
      await _navigate();
    }
  }

  void _showNoInternetError() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const _NoInternetScreen()),
    );
  }

  void _showSoftUpdateDialog(String message, String apkUrl) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: _C.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Text('🎉 ', style: TextStyle(fontSize: 20)),
              Text(
                'Update Available!',
                style: TextStyle(
                  color: _C.textPrimary,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Text(
            message.isNotEmpty
                ? message
                : 'A new version is available! Update now for the latest features.',
            style: const TextStyle(
              color: _C.textSecondary,
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Later',
                style: TextStyle(color: _C.textMuted, fontFamily: 'Poppins'),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (apkUrl.isNotEmpty) {
                  final uri = Uri.parse(apkUrl);
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  } catch (_) {}
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Update Now',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      _goTo(const HomeScreen());
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _goTo(const HomeScreen());
      return;
    }

    try {
      final userData = await supabase
          .from('users')
          .select('is_blocked')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final isBlocked = userData?['is_blocked'] as bool? ?? false;
      if (isBlocked) {
        _goTo(const HomeScreen());
        return;
      }

      _goTo(const HomeScreen());
    } catch (e) {
      debugPrint('Splash navigate error: $e');
      if (!mounted) return;
      _goTo(const HomeScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _titleController.dispose();
    _taglineController.dispose();
    _imageController.dispose();
    _loadingController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _C.background,
      body: FadeTransition(
        opacity: _bgFade,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── MIDDLE: Rider illustration — centered ──
              Expanded(
                child: AnimatedBuilder(
                  animation: _imageController,
                  builder: (_, child) => SlideTransition(
                    position: _imageSlide,
                    child: FadeTransition(
                      opacity: _imageFade,
                      child: Transform.scale(
                        scale: _imageScale.value,
                        child: child,
                      ),
                    ),
                  ),
                  child: Center(
                    // ✅ Center wrap kiya
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Image.asset(
                        'assets/images/illus_splash_rider.jpg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // ── BOTTOM: Loading icon + progress bar + text ──
              FadeTransition(
                opacity: _loadingFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: Column(
                    children: [
                      // Small delivery icon (reference jaisa)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🛵', style: TextStyle(fontSize: 18)),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Animated progress bar
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (_, __) => Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _C.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _progress.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _C.primary,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: _C.primary.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // "Loading deliciousness... ❤️" — reference jaisa
                      const Text(
                        'Loading deliciousness... ❤️',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _C.textMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NO INTERNET SCREEN — preserved from v5.0
// ─────────────────────────────────────────────────────────────
class _NoInternetScreen extends StatelessWidget {
  const _NoInternetScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.primary.withOpacity(0.25),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: _C.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  color: _C.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please check your connection and try again.',
                style: TextStyle(
                  color: _C.textMuted,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Streat Eats — Street Food, Delivered Fast! 🍽️',
                style: TextStyle(
                  color: _C.textMuted,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
