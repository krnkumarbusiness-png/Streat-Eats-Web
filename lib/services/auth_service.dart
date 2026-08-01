import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class AuthService {
  final _client = Supabase.instance.client;

  // ── Rate Limiting ─────────────────────────────────────────────
  static final Map<String, List<DateTime>> _attemptLog = {};
  static const int _maxAttempts = 5;
  static const Duration _windowDuration = Duration(minutes: 5);

  bool _isRateLimited(String action) {
    final now = DateTime.now();
    _attemptLog[action] ??= [];
    _attemptLog[action]!.removeWhere(
      (t) => now.difference(t) > _windowDuration,
    );
    if (_attemptLog[action]!.length >= _maxAttempts) return true;
    _attemptLog[action]!.add(now);
    return false;
  }

  Duration? _getRateLimitWait(String action) {
    final log = _attemptLog[action];
    if (log == null || log.isEmpty) return null;
    final oldest = log.first;
    final wait = _windowDuration - DateTime.now().difference(oldest);
    return wait.isNegative ? null : wait;
  }

  // ── Google Sign In ─────────────────────────────────────────────
  GoogleSignIn get _googleSignIn => GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    scopes: ['email', 'profile'],
  );

  Future<AuthResponse> signInWithGoogle({bool isRider = false}) async {
    if (isRider) {
      throw Exception('Riders cannot sign up with Google. Use email/password.');
    }

    if (_isRateLimited('google_signin')) {
      final wait = _getRateLimitWait('google_signin');
      final mins = wait?.inMinutes ?? 5;
      throw Exception(
        'Too many attempts. Please try again after $mins minutes.',
      );
    }

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign in cancelled.');

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception(
          'Google ID token not found. Please check Web Client ID.',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        final email = response.user!.email ?? '';
        final name = googleUser.displayName ?? email.split('@').first;

        final existing = await _client
            .from('users')
            .select('id, role')
            .eq('id', userId)
            .maybeSingle();

        if (existing == null) {
          await _client.from('users').insert({
            'id': userId,
            'full_name': name,
            'phone': '',
            'area': '',
            'gender': 'Other',
            'city': 'Haldwani',
            'role': 'customer',
          });
        }

        await NotificationService().refreshTokenAfterLogin();
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  // ── Email Signup ──────────────────────────────────────────────
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String area,
    required String gender,
    String role = 'customer',
  }) async {
    if (_isRateLimited('signup')) {
      final wait = _getRateLimitWait('signup');
      final mins = wait?.inMinutes ?? 5;
      throw Exception(
        'Too many attempts. Please try again after $mins minutes.',
      );
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await _client.from('users').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'phone': phone,
        'area': area,
        'gender': gender,
        'city': 'Haldwani',
        'role': role,
      });
      await NotificationService().refreshTokenAfterLogin();
    }

    return response;
  }

  // ── Email Login ───────────────────────────────────────────────
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    if (_isRateLimited('login')) {
      final wait = _getRateLimitWait('login');
      final mins = wait?.inMinutes ?? 5;
      throw Exception(
        'Too many attempts. Please try again after $mins minutes.',
      );
    }

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await NotificationService().refreshTokenAfterLogin();
    }

    return response;
  }

  // ── Forgot Password ───────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    if (_isRateLimited('forgot_password')) {
      throw Exception('Too many attempts. Please try again later.');
    }

    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'streeteats://login-callback',
    );
  }

  // ── Reset Password ────────────────────────────────────────────
  Future<void> updatePassword(String newPassword) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Session expired. Please login again.');
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ── Set Password for Google Users ────────────────────────────
  Future<void> setPasswordForGoogleUser(String newPassword) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Please login first.');

    final identities = user.identities ?? [];
    final hasGoogleIdentity = identities.any((i) => i.provider == 'google');

    if (!hasGoogleIdentity) {
      throw Exception(
        'This feature is only for users who signed in with Google.',
      );
    }

    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ── Check if user has password set ───────────────────────────
  bool get currentUserHasPassword {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final identities = user.identities ?? [];
    return identities.any((i) => i.provider == 'email');
  }

  // ── Check if Google User ──────────────────────────────────────
  bool get isGoogleUser {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final identities = user.identities ?? [];
    return identities.any((i) => i.provider == 'google');
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> logout() async {
    // ← Role cache clear karo — next user galat screen na dekhe
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
    } catch (_) {}

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _client
            .from('device_tokens')
            .update({'user_id': null, 'is_active': false})
            .eq('user_id', userId);
      }
    } catch (_) {}

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => _client.auth.currentUser != null;
  Session? get currentSession => _client.auth.currentSession;

  // ── Get User Role — ab SharedPreferences mein cache hota hai ──
  // Fix: App reopen pe rider → user ban jaata tha kyunki
  // network slow hoti thi aur 'customer' default return hota tha.
  // Ab: pehle DB se fetch karo, save karo; fail ho toh cache use karo.
  Future<String> getUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return 'customer';

    final metaRole = user.appMetadata['role'] as String?;
    if (metaRole == 'admin') {
      await _saveRoleLocally('admin');
      return 'admin';
    }

    try {
      final response = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = response?['role'] as String? ?? 'customer';
      await _saveRoleLocally(role);
      return role;
    } catch (_) {
      // Network fail — cached role se sahi screen pe jaao
      return await _getCachedRole();
    }
  }

  Future<void> _saveRoleLocally(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
    } catch (_) {}
  }

  Future<String> _getCachedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role') ?? 'customer';
    } catch (_) {
      return 'customer';
    }
  }

  // ── Parse Error ───────────────────────────────────────────────
  String parseError(dynamic error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('riders cannot sign up with google')) {
      return 'Rider account cannot be created with Google. Please use email and password.';
    }
    if (msg.contains('bahut zyada') ||
        msg.contains('rate limit') ||
        msg.contains('too many')) {
      return error.toString();
    }
    if (msg.contains('google sign in cancelled') ||
        msg.contains('cancelled') ||
        msg.contains('sign_in_canceled') ||
        msg.contains('sign_in_failed')) {
      return 'Google sign in cancel ho gaya.';
    }
    if (msg.contains('google id token nahi mila') ||
        msg.contains('web client id')) {
      return 'Google login configure nahi hai. Developer ko contact karo.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('wrong password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email not verified. Please check your inbox.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'This email is already registered. Please login.';
    }
    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('failed host lookup')) {
      return 'Please check your internet connection and try again.';
    }
    if (msg.contains('weak password') || msg.contains('password should be')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('session expired') || msg.contains('jwt expired')) {
      return 'Session expired. Please login again.';
    }
    if (msg.contains('user not found')) {
      return 'No account found for this email.';
    }

    return 'Error: ${error.toString().replaceAll('Exception: ', '')}';
  }
}
