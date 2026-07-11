// lib/screens/donation_screen.dart
// v3.0 — Edge Function se Razorpay order create hoga (no hardcoded key)
// ✅ create-razorpay-order Edge Function use hogi
// ✅ Production ready — koi API key Flutter code mein nahi
// ✅ Same flow jo orders mein use hota hai
// ✅ All v2.0 features preserved

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
// razorpay_flutter is Android/iOS only — on web we use RazorpayWebCheckout
import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.js_interop) '../services/razorpay_web_checkout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/razorpay_web_checkout.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen>
    with TickerProviderStateMixin {
  // ── App light theme colors ────────────────────────────────
  static const _bg = Color(0xFFFFF8F0);
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFFFF6B35);
  static const _primaryLight = Color(0xFFFFF1EB);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF3D3D3D);
  static const _textMuted = Color(0xFF6B7280);
  static const _success = Color(0xFF16A34A);
  static const _successLight = Color(0xFFDCFCE7);
  static const _error = Color(0xFFDC2626);
  static const _border = Color(0xFFE5E7EB);
  static const _warmBrown = Color(0xFF92400E);
  static const _warmBrownLight = Color(0xFFFEF3C7);

  // ── State ─────────────────────────────────────────────────
  int? _selectedAmount;
  bool _isCustom = false;
  final _customController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingStats = true;

  // Razorpay order data (Edge Function se aayega)
  String? _razorpayOrderId;
  String? _razorpayKeyId; // Edge Function se milegi — hardcoded nahi

  // Stats from admin (app_settings)
  int _dogsFed = 0;
  double _totalDonated = 0;
  String _donationPageTitle = 'Help Feed Street Dogs 🐾';
  String _donationPageDesc =
      'Thousands of stray dogs in Haldwani go hungry every day. '
      'Your small contribution can bring joy to their lives. '
      'Donate through Street Eats and help our city\'s furry friends! 🐕';

  // _razorpay is null on web — we use RazorpayWebCheckout instead.
  Razorpay? _razorpay;
  late AnimationController _heartController;
  late AnimationController _pawController;
  late Animation<double> _heartAnim;
  late Animation<double> _pawAnim;

  final _supabase = Supabase.instance.client;

  static const _presetAmounts = [10, 15, 20, 30, 40, 50, 100];

  @override
  void initState() {
    super.initState();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _heartAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
    _pawAnim = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _pawController, curve: Curves.easeInOut));

    // Native Razorpay SDK — not used on web
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    }

    _loadStats();
  }

  @override
  void dispose() {
    _heartController.dispose();
    _pawController.dispose();
    _razorpay?.clear(); // null-safe: no-op on web
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select(
            'donation_dogs_fed, donation_total_raised, '
            'donation_title, donation_subtitle',
          )
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _dogsFed = (data['donation_dogs_fed'] as num?)?.toInt() ?? 0;
          _totalDonated =
              (data['donation_total_raised'] as num?)?.toDouble() ?? 0;
          _donationPageTitle =
              data['donation_title'] as String? ?? 'Help Feed Street Dogs 🐾';
          _donationPageDesc =
              data['donation_subtitle'] as String? ?? _donationPageDesc;
          _isLoadingStats = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      debugPrint('DonationScreen: stats load error — $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  int get _finalAmount {
    if (_isCustom) return int.tryParse(_customController.text.trim()) ?? 0;
    return _selectedAmount ?? 0;
  }

  // ── Start Donation — Edge Function ke through ─────────────
  // Exact same pattern jo orders mein use hota hai
  Future<void> _startDonation() async {
    final amount = _finalAmount;

    if (amount <= 0) {
      _snack('Please select or enter an amount 😊', isError: true);
      return;
    }
    if (amount < 5) {
      _snack('Minimum donation amount is ₹5', isError: true);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      // ── Step 1: User info fetch ───────────────────────────
      final user = _supabase.auth.currentUser;
      String userName = 'Street Eats User';
      String userPhone = '';

      if (user != null) {
        try {
          final userData = await _supabase
              .from('users')
              .select('full_name, phone')
              .eq('id', user.id)
              .maybeSingle();
          if (userData != null) {
            userName = userData['full_name'] as String? ?? userName;
            userPhone = userData['phone'] as String? ?? '';
          }
        } catch (_) {}
      }

      // ── Step 2: Pending donation record insert ────────────
      String donationId = 'don_${DateTime.now().millisecondsSinceEpoch}';
      try {
        final row = await _supabase
            .from('donations')
            .insert({
              'amount': amount,
              'status': 'pending',
              'user_id': user?.id,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        donationId = row['id']?.toString() ?? donationId;
      } catch (e) {
        debugPrint('donations insert skipped: $e');
        // Table nahi hai ya error — continue karo
      }

      // ── Step 3: Edge Function call ────────────────────────
      // Same function jo orders mein use hoti hai
      // Sirf type: 'donation' pass karo — Edge Function handle karega
      final response = await _supabase.functions.invoke(
        'create-razorpay-order',
        body: {
          'amount': amount, // rupees mein — Edge Function *100 karega
          'currency': 'INR',
          'type': 'donation', // order se alag identify karne ke liye
          'donation_id': donationId,
          'receipt': donationId,
          'notes': {
            'type': 'dog_donation',
            'donation_id': donationId,
            'app': 'streat_eats',
          },
        },
      );

      // Edge Function error check
      if (response.status != 200) {
        throw Exception('Edge Function error: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;

      // Edge Function se order_id aur key_id milega
      // (same pattern jo checkout mein use hota hai)ss
      final razorpayOrderId = data['razorpay_order_id'] as String?;
      final razorpayKeyId = data['key_id'] as String?;

      if (razorpayOrderId == null || razorpayKeyId == null) {
        throw Exception('Invalid response from Edge Function');
      }

      // State mein store karo — onSuccess mein kaam aayega
      _razorpayOrderId = razorpayOrderId;
      _razorpayKeyId = razorpayKeyId;

      setState(() => _isLoading = false);

      // ── Step 4: Open checkout ────────────────────────────
      final options = {
        'key': razorpayKeyId,
        'order_id': razorpayOrderId,
        'amount': amount * 100,
        'currency': 'INR',
        'name': 'Streat Eats',
        'description': 'Feeding stray dogs in Haldwani 🐕',
        'prefill': {
          'contact': userPhone,
          'name': userName,
          'email': user?.email ?? '',
        },
        'theme': {'color': '#FF6B35'},
        'notes': {'donation_id': donationId, 'type': 'dog_donation'},
      };

      if (kIsWeb) {
        // ── WEB: Razorpay JS Checkout ───────────────────────────
        RazorpayWebCheckout.open(
          options: options,
          onSuccess: (paymentId, orderId, signature) {
            _onPaymentSuccessWeb(paymentId, orderId, signature);
          },
          onError: (code, message) {
            _onPaymentErrorWeb(code, message);
          },
        );
      } else {
        // ── NATIVE: Razorpay Flutter SDK ───────────────────────
        _razorpay!.open(options);
      }
    } catch (e) {
      debugPrint('DonationScreen: _startDonation error — $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Something went wrong. Please try again 🙏', isError: true);
      }
    }
  }

  // ── Razorpay Callbacks ────────────────────────────────────
  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Donation payment success: ${response.paymentId}');

    // DB mein donation status update karo
    try {
      await _supabase
          .from('donations')
          .update({
            'status': 'completed',
            'razorpay_payment_id': response.paymentId,
            'razorpay_order_id': response.orderId ?? _razorpayOrderId,
            'razorpay_signature': response.signature,
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('razorpay_order_id', _razorpayOrderId ?? '');
    } catch (e) {
      debugPrint('Donation DB update failed (payment hua hai): $e');
      // Payment successful hai — dialog dikhao even if DB update fails
    }

    if (!mounted) return;
    _showThankYouDialog();
  }

  void _onPaymentError(PaymentFailureResponse response) {
    debugPrint(
      'Donation payment error: ${response.code} — ${response.message}',
    );
    if (!mounted) return;

    final msg = response.code == Razorpay.PAYMENT_CANCELLED
        ? 'Payment cancelled. You can try again anytime! 😊'
        : 'Payment failed. Please try again 😔';

    _snack(msg, isError: true);
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet: ${response.walletName}');
  }

  // ── WEB-ONLY callbacks (called from RazorpayWebCheckout) ──────
  void _onPaymentSuccessWeb(
    String paymentId,
    String orderId,
    String signature,
  ) {
    _onPaymentSuccess(PaymentSuccessResponse(paymentId, orderId, signature));
  }

  void _onPaymentErrorWeb(int code, String message) {
    _onPaymentError(PaymentFailureResponse(code, message));
  }

  // ── Thank You Dialog ──────────────────────────────────────
  void _showThankYouDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text('🐾', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Thank You! ❤️',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your ₹$_finalAmount donation will help a stray dog eat well today! 🐕\n\nThe street dogs of Haldwani thank you!',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _successLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _success.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      color: _success,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'You just did something great! 🌟',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Go Back Home 🏠',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? _error : _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          elevation: 4,
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHero(),
                    _buildStats(),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildAmountSection(),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildImpactSection(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildDonateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Feed Street Dogs 🐾',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _heartAnim,
            builder: (_, __) => Transform.scale(
              scale: _heartAnim.value,
              child: const Text('❤️', style: TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _pawAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -_pawAnim.value),
              child: const Text('🐕', style: TextStyle(fontSize: 52)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _donationPageTitle,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _donationPageDesc,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🐾', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text(
                  '100% goes directly to feeding dogs',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    if (_isLoadingStats) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _statItem('🐕', '$_dogsFed', 'Dogs Fed'),
            _statDivider(),
            _statItem(
              '💰',
              '₹${_totalDonated.toStringAsFixed(0)}',
              'Total Donated',
            ),
            _statDivider(),
            _statItem('🌟', '100%', 'Goes to Dogs'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: _textMuted,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _statDivider() => Container(width: 1, height: 48, color: _border);

  Widget _buildAmountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How Much Would You Like to Donate? 💝',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Small or big — every donation makes a difference',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presetAmounts.map((amount) {
                final isSelected = !_isCustom && _selectedAmount == amount;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedAmount = amount;
                      _isCustom = false;
                      _customController.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _primary : _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _primary : _border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹$amount',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : _textPrimary,
                          ),
                        ),
                        Text(
                          _amountLabel(amount),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            color: isSelected
                                ? Colors.white.withOpacity(0.85)
                                : _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isCustom = true;
                    _selectedAmount = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isCustom ? _primary : _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCustom ? _primary : _border,
                      width: _isCustom ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Custom',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _isCustom ? Colors.white : _textPrimary,
                        ),
                      ),
                      Text(
                        'Your choice',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          color: _isCustom
                              ? Colors.white.withOpacity(0.85)
                              : _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isCustom) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _customController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: _textMuted,
                ),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_finalAmount > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🐾', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '₹$_finalAmount will feed ${_dogsCanFeed(_finalAmount)} dog${_finalAmount >= 20 ? 's' : ''} one meal!',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImpactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warmBrownLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warmBrown.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🌟', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'What Your Donation Does',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _warmBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _impactRow('₹10', 'One dog gets one meal for the day 🍗'),
          _impactRow('₹20', 'One dog stays happy and fed all day 🎉'),
          _impactRow('₹50', '3 dogs get a full meal 🐕🐕🐕'),
          _impactRow('₹100', 'One dog eats every day for a week 🏠❤️'),
        ],
      ),
    );
  }

  Widget _impactRow(String amount, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            amount,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _warmBrown,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDonateButton() {
    final amount = _finalAmount;
    final hasAmount = amount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_isLoading || !hasAmount) ? null : _startDonation,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withOpacity(0.4),
              elevation: hasAmount ? 4 : 0,
              shadowColor: _primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🐾', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        hasAmount
                            ? 'Donate ₹$amount ❤️'
                            : 'Select an amount first',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _amountLabel(int amount) {
    switch (amount) {
      case 10:
        return '1 meal';
      case 15:
        return '1.5 meals';
      case 20:
        return '2 meals';
      case 30:
        return '3 meals';
      case 40:
        return '4 meals';
      case 50:
        return 'Full day';
      case 100:
        return 'Week\'s food';
      default:
        return '';
    }
  }

  String _dogsCanFeed(int amount) {
    final dogs = (amount / 10).floor();
    return dogs <= 1 ? '1' : '$dogs';
  }
}
