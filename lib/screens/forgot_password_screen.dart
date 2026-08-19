import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../constants/app_snackbar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_authService.parseError(e));
    }
  }

  void _showError(String msg) {
    AppSnackBar.showError(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _emailSent ? _buildSuccessState() : _buildFormState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Password Reset',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered email. We\'ll send a password reset link.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Poppins',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Email Address',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'you@email.com',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: _bdr(),
              enabledBorder: _bdr(),
              focusedBorder: _bdr(focused: true),
              errorBorder: _bdr(error: true),
              focusedErrorBorder: _bdr(error: true),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Back to Login',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.success,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Email Sent! 📧',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_emailController.text.trim()} reset link has been sent.\nCheck your inbox — it may sometimes go to spam.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: 'Poppins',
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'After clicking the link, the password reset screen will open directly in the app.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontFamily: 'Poppins',
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Go to Login',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _emailSent = false),
          child: const Text(
            'Resend',
            style: TextStyle(
              color: AppColors.textMuted,
              fontFamily: 'Poppins',
              fontSize: 13,
            ),
          ),
        ),
      ],
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
