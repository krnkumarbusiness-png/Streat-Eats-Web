import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();

  final _authService = AuthService();
  final _notifService = NotificationService();

  late AnimationController _heroController;
  late AnimationController _formController;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  final String _selectedArea = 'Haldwani';
  String _selectedGender = 'Male';

  final List<String> _areas = [
    'Haldwani',
    'Kathgodam',
    'Banbhoolpura',
    'Lalkuan',
    'Nihalpur',
    'Transport Nagar',
    'Gaujajali',
    'Indira Nagar',
    'Sheetla Nagar',
  ];
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkSession();
  }

  void _initAnimations() {
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic),
        );

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _formFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOut));
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
        );

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _heroController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && mounted) {
      try {
        await _notifService.init();
      } catch (_) {}
      final role = await _authService.getUserRole();
      if (mounted) _navigateByRole(role);
    }
  }

  Future<void> _navigateByRole(String role) async {
    if (!mounted) return;
    await context.read<UserProvider>().fetchUserData();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (r) => false,
    );
  }

  void _switchTab(bool isLogin) {
    HapticFeedback.selectionClick();
    setState(() {
      _isLogin = isLogin;
    });
    _formController.reset();
    _formController.forward();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.error.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      final role = await _authService.getUserRole();
      await _navigateByRole(role);
      try {
        await _notifService.refreshTokenAfterLogin();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      final msg = _authService.parseError(e);
      if (!msg.toLowerCase().contains('cancel')) _showError(msg);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (!mounted) return;
        final role = await _authService.getUserRole();
        await _navigateByRole(role); // ← user home pe pahunch gaya
        // notif background mein silently hoga
        try {
          await _notifService.refreshTokenAfterLogin();
        } catch (_) {}
      } else {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          area: _areaController.text.trim(),
          gender: _selectedGender,
        );
        if (!mounted) return;
        await context.read<UserProvider>().fetchUserData();
        if (!mounted) return;
        try {
          await _notifService.refreshTokenAfterLogin();
        } catch (_) {}
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError(_authService.parseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── HERO SECTION ──────────────────────────────────
              SlideTransition(
                position: _heroSlide,
                child: FadeTransition(opacity: _heroFade, child: _buildHero()),
              ),

              // ── FORM SECTION ──────────────────────────────────
              SlideTransition(
                position: _formSlide,
                child: FadeTransition(
                  opacity: _formFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tab toggle
                          _buildTabToggle(),
                          const SizedBox(height: 24),

                          // Google button
                          _buildGoogleButton(),
                          const SizedBox(height: 16),
                          _buildDivider(),
                          const SizedBox(height: 16),

                          // Email
                          _lbl('Email Address'),
                          const SizedBox(height: 8),
                          _field(
                            controller: _emailController,
                            hint: 'you@email.com',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                            validator: (v) =>
                                v!.isEmpty ? 'Email is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Password
                          _lbl('Password'),
                          const SizedBox(height: 8),
                          _buildPasswordField(),

                          // Forgot password — login only
                          if (_isLogin) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Sign up extra fields
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _lbl('Full Name'),
                            const SizedBox(height: 8),
                            _field(
                              controller: _nameController,
                              hint: 'Your full name',
                              icon: Icons.person_outline_rounded,
                              validator: (v) =>
                                  v!.isEmpty ? 'Name is required' : null,
                            ),
                            const SizedBox(height: 16),
                            _lbl('Mobile Number'),
                            const SizedBox(height: 8),
                            _field(
                              controller: _phoneController,
                              hint: '10-digit number',
                              icon: Icons.phone_outlined,
                              keyboard: TextInputType.phone,
                              validator: (v) => v!.length != 10
                                  ? 'Enter a valid number'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _lbl('Your Area'),
                            const SizedBox(height: 8),
                            _field(
                              controller: _areaController,
                              hint: 'e.g. Tikonia, Haldwani',
                              icon: Icons.location_on_outlined,
                              validator: (v) =>
                                  v!.isEmpty ? 'Area is required' : null,
                            ),
                            const SizedBox(height: 16),
                            _lbl('Gender'),
                            const SizedBox(height: 8),
                            _drop(
                              value: _selectedGender,
                              items: _genders,
                              onChange: (v) =>
                                  setState(() => _selectedGender = v!),
                            ),
                          ],

                          const SizedBox(height: 28),
                          _buildSubmitButton(),
                          const SizedBox(height: 20),
                          _buildSwitchLink(),
                          const SizedBox(height: 28),

                          // Trust badges
                          _buildTrustBadges(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO — IMAGE + TITLE + TAGLINE
  // ─────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0E6),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Image.asset(
          'assets/images/delivery_rider.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
        ),
      ),
    );
  }

  Widget _heroHeading({
    required Key key,
    required String line1,
    required String line2,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line1,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            fontFamily: 'Poppins',
            height: 1.1,
          ),
        ),
        Text(
          line2,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            fontFamily: 'Poppins',
            height: 1.1,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB TOGGLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [_tab('Login', true), _tab('Sign Up', false)]),
    );
  }

  Widget _tab(String label, bool isLoginTab) {
    final active = _isLogin == isLoginTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(isLoginTab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GOOGLE BUTTON
  // ─────────────────────────────────────────────────────────────
  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: (_isLoading || _isGoogleLoading)
            ? null
            : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4285F4),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isLogin ? 'Continue with Google' : 'Sign up with Google',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted.withOpacity(0.8),
              fontFamily: 'Poppins',
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PASSWORD FIELD
  // ─────────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
      validator: (v) => v!.length < 6 ? 'Minimum 6 characters' : null,
      decoration: InputDecoration(
        hintText: 'Enter your password',
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: _bdr(),
        enabledBorder: _bdr(),
        focusedBorder: _bdr(focused: true),
        errorBorder: _bdr(error: true),
        focusedErrorBorder: _bdr(error: true),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUBMIT BUTTON
  // ─────────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isLoading || _isGoogleLoading) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          elevation: 0,
          shadowColor: AppColors.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isLogin ? 'Logging in...' : 'Creating account...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'Login' : 'Create Account',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SWITCH LINK
  // ─────────────────────────────────────────────────────────────
  Widget _buildSwitchLink() {
    return Center(
      child: GestureDetector(
        onTap: () => _switchTab(!_isLogin),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              color: AppColors.textMuted,
            ),
            children: [
              TextSpan(
                text: _isLogin
                    ? 'Don\'t have an account?  '
                    : 'Already have an account?  ',
              ),
              TextSpan(
                text: _isLogin ? 'Sign Up ›' : 'Login ›',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TRUST BADGES — Bottom of screen
  // ─────────────────────────────────────────────────────────────
  Widget _buildTrustBadges() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _badge('🛵', 'Fast Delivery', 'On time'),
          _badgeDivider(),
          _badge('🛡️', 'Safe & Secure', '100% secure'),
          _badgeDivider(),
          _badge('⭐', 'Best Food', 'Top quality'),
        ],
      ),
    );
  }

  Widget _badge(String emoji, String title, String sub) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          sub,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _badgeDivider() {
    return Container(width: 1, height: 40, color: AppColors.border);
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  Widget _lbl(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      fontFamily: 'Poppins',
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: _bdr(),
        enabledBorder: _bdr(),
        focusedBorder: _bdr(focused: true),
        errorBorder: _bdr(error: true),
        focusedErrorBorder: _bdr(error: true),
      ),
    );
  }

  Widget _drop({
    required String value,
    required List<String> items,
    required void Function(String?) onChange,
    Map<String, String>? displayMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surface,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          isExpanded: true,
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    displayMap?[i] ?? i,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  OutlineInputBorder _bdr({bool focused = false, bool error = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: error
            ? AppColors.error
            : focused
            ? AppColors.primary
            : AppColors.border,
        width: focused ? 2 : 1,
      ),
    );
  }
}
