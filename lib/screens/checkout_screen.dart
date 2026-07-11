// lib/screens/checkout_screen.dart
// v4.0 — Manual Location Selection
//
// NEW in v4.0:
//   ✅ "Deliver Here" (GPS saved address) vs "Deliver to Another Location" toggle
//   ✅ Manual address entry — user types full address + landmark
//   ✅ Optional: different recipient name + phone for manual address
//   ✅ Delivery charge shows "Standard Rate" label for manual address
//   ✅ Rider sees full address text in their app (existing Google Maps button works)
//   ✅ Cart address type (GPS/manual) passed to CartProvider
//   ✅ All v3.0 features preserved (packaging fee, donation, offers, razorpay)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// razorpay_flutter is Android/iOS only — on web we use RazorpayWebCheckout
import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.js_interop) '../services/razorpay_web_checkout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../models/delivery_address_model.dart';
import '../services/order_service.dart';
import '../models/order_model.dart';
import '../services/offer_service.dart';
import '../services/razorpay_service.dart';
import '../services/razorpay_web_checkout.dart';
import '../services/location_service.dart';
import 'order_confirmation_screen.dart';
import 'login_screen.dart';
import 'donation_screen.dart';
import 'location_picker_screen.dart';
import 'address_selection_screen.dart';
import '../constants/app_snackbar.dart';
import 'dart:async' show unawaited;

// ── Address mode ─────────────────────────────────────────────
enum _AddressMode { myLocation, otherLocation }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ── My Location (GPS) controllers ────────────────────────────
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();

  // ── Other Location (manual) controllers ─────────────────────
  final _otherAddressController = TextEditingController();
  final _otherLandmarkController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  // ── Other controllers ─────────────────────────────────────────
  final _offerController = TextEditingController();
  final _nameController = TextEditingController();

  final _orderService = OrderService();
  final _offerService = OfferService();
  final _supabase = Supabase.instance.client;

  // _razorpay is null on web — we use RazorpayWebCheckout instead.
  Razorpay? _razorpay;

  bool _isLoading = false;
  bool _showPaymentLoading = false;
  String _loadingMessage = 'Placing your order...';
  bool _isEditingAddress = false;
  bool _isValidatingOffer = false;
  OfferResult? _appliedOffer;
  String? _offerError;

  String _selectedPayment = 'cod';
  String? _pendingOrderId;
  List<OrderModel> _pendingOrders =
      []; // Multi-vendor: online payment ke saare orders track karne ke liye

  int _userTotalOrders = 0;
  bool _userDataLoaded = false;

  // ── v4.0: Address mode ───────────────────────────────────────
  _AddressMode _addressMode = _AddressMode.myLocation;
  bool _showRecipientFields = false; // toggle for "Different contact?" section

  // ── v4.1: Map-picked precise coordinates ───────────────────
  double? _myPickedLat;
  double? _myPickedLng;
  double? _otherPickedLat;
  double? _otherPickedLng;

  // v3.0 — Donation state
  int _selectedDonationAmount = 0;
  bool _showDonationSection = false;
  List<int> _donationPresets = [10, 20, 30, 50];
  List<Map<String, dynamic>> _firstOrderCoupons = [];

  static const double _codLimit = 199.0;
  static const int _onlineDiscount = 0;
  static const double _otherPlatformDelivery = 35.0;
  static const double _otherPlatformFee = 7.0;

  static const _bgColor = Color(0xFFFFF8F0);
  static const _surfaceColor = Color(0xFFFFFFFF);
  static const _primaryColor = Color(0xFFFF6B35);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF3D3D3D);
  static const _textMuted = Color(0xFF6B7280);
  static const _successColor = Color(0xFF16A34A);
  static const _errorColor = Color(0xFFDC2626);
  static const _warningColor = Color(0xFFD97706);
  static const _borderColor = Color(0xFFE5E7EB);

  double _otherPlatformTotal(CartProvider cart) =>
      cart.subtotal + _otherPlatformDelivery + _otherPlatformFee;

  double _savedAmount(CartProvider cart) {
    final saved = _otherPlatformTotal(cart) - cart.total;
    return saved < 0 ? 0 : saved;
  }

  @override
  void initState() {
    super.initState();
    // Native Razorpay SDK — not used on web
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        Navigator.pop(context);
        _showLoginPrompt(context);
        return;
      }

      final userProvider = context.read<UserProvider>();
      final savedName = userProvider.userData?['full_name'] as String? ?? '';
      if (savedName.isNotEmpty) _nameController.text = savedName;

      final savedAddress = userProvider.savedAddress;
      final savedLandmark = userProvider.savedLandmark;
      if (savedAddress.isNotEmpty) {
        _addressController.text = savedAddress;
        _landmarkController.text = savedLandmark;
        setState(() => _isEditingAddress = false);
      } else {
        setState(() => _isEditingAddress = true);
      }

      // ✅ Saved GPS coordinates fetch karo — taaki delivery charge
      // shuru se hi accurate dikhe, sirf map khol ke confirm karne par nahi
      try {
        final savedCoords = await _supabase
            .from('users')
            .select('last_lat, last_lng')
            .eq('id', user.id)
            .maybeSingle();
        final savedLat = (savedCoords?['last_lat'] as num?)?.toDouble();
        final savedLng = (savedCoords?['last_lng'] as num?)?.toDouble();
        if (savedLat != null && savedLng != null && mounted) {
          setState(() {
            _myPickedLat = savedLat;
            _myPickedLng = savedLng;
          });
        }
      } catch (_) {}

      // v4.0: sync CartProvider with current GPS address
      _syncGpsAddressToCart();

      // ✅ Saved coordinates se delivery estimate recalculate karo
      if (_myPickedLat != null && _myPickedLng != null) {
        await _recalculateDeliveryEstimate(
          lat: _myPickedLat!,
          lng: _myPickedLng!,
        );
      }

      await Future.wait([
        _fetchUserOrderCount(),
        _loadDonationSettings(),
        _loadFirstOrderCoupons(),
      ]);
    });
  }

  // ── v4.0: Sync GPS address to CartProvider ───────────────────
  void _syncGpsAddressToCart() {
    if (_addressMode == _AddressMode.myLocation &&
        _addressController.text.isNotEmpty) {
      final addr = DeliveryAddress(
        type: AddressType.gps,
        address: _addressController.text.trim(),
        landmark: _landmarkController.text.trim(),
        // distanceKm comes from vendor in CartProvider legacy behavior
      );
      context.read<CartProvider>().setDeliveryAddress(addr);
    }
  }

  // ── v4.0: Sync manual address to CartProvider ─────────────────
  void _syncManualAddressToCart() {
    if (_addressMode == _AddressMode.otherLocation &&
        _otherAddressController.text.isNotEmpty) {
      final addr = DeliveryAddress(
        type: AddressType.manual,
        address: _otherAddressController.text.trim(),
        landmark: _otherLandmarkController.text.trim(),
        recipientName: _recipientNameController.text.trim().isEmpty
            ? null
            : _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim().isEmpty
            ? null
            : _recipientPhoneController.text.trim(),
      );
      context.read<CartProvider>().setDeliveryAddress(addr);
    }
  }

  // ── v4.2 FIX: Exact pin se live delivery charge recalculate karo ──
  // Cart mein saare vendors ke against farthest distance nikal ke
  // CartProvider ko batao — taaki order summary mein dikhne wala
  // amount actual charge se match kare
  Future<void> _recalculateDeliveryEstimate({
    required double lat,
    required double lng,
  }) async {
    if (!mounted) return;
    final cart = context.read<CartProvider>();
    final vendorsInCart = cart.vendors;
    if (vendorsInCart.isEmpty) return;
    double maxDistKm = 0;
    for (final v in vendorsInCart) {
      if (v.latitude == 0 && v.longitude == 0) continue;
      final meters = LocationService().distanceBetween(
        lat,
        lng,
        v.latitude,
        v.longitude,
      );
      final km = meters / 1000;
      if (km > maxDistKm) maxDistKm = km;
    }
    if (maxDistKm > 0) {
      cart.setConfirmedDeliveryDistance(maxDistKm);
    }
  }

  // ── v4.2: Address Selection screen kholo — search/current/saved/add new ──
  Future<void> _openLocationPicker({required bool isOtherMode}) async {
    HapticFeedback.lightImpact();
    final double? currentLat = isOtherMode ? _otherPickedLat : _myPickedLat;
    final double? currentLng = isOtherMode ? _otherPickedLng : _myPickedLng;

    final result = await Navigator.push<PickedLocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSelectionScreen(
          currentLat: currentLat,
          currentLng: currentLng,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (isOtherMode) {
        _otherPickedLat = result.lat;
        _otherPickedLng = result.lng;
        _otherAddressController.text = result.address;
      } else {
        _myPickedLat = result.lat;
        _myPickedLng = result.lng;
        _addressController.text = result.address;
        _isEditingAddress = false;
      }
    });

    if (isOtherMode) {
      _syncManualAddressToCart();
    } else {
      _syncGpsAddressToCart();
    }

    // ✅ Exact pin confirm hone ke baad delivery charge live recalculate karo
    await _recalculateDeliveryEstimate(lat: result.lat, lng: result.lng);
  }

  Future<void> _fetchUserOrderCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('users')
          .select('total_orders_count')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        final count = (data?['total_orders_count'] as num?)?.toInt() ?? 0;
        setState(() {
          _userTotalOrders = count;
          _userDataLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _userDataLoaded = true);
    }
  }

  Future<void> _loadDonationSettings() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('donation_checkout_enabled, donation_checkout_presets')
          .limit(1)
          .maybeSingle();
      if (data != null && mounted) {
        final enabled = data['donation_checkout_enabled'] as bool? ?? false;
        final presetsRaw = data['donation_checkout_presets'] as String?;
        List<int> presets = [10, 20, 30, 50];
        if (presetsRaw != null && presetsRaw.isNotEmpty) {
          try {
            presets = presetsRaw
                .split(',')
                .map((e) => int.tryParse(e.trim()) ?? 0)
                .where((e) => e > 0)
                .toList();
          } catch (_) {}
        }
        setState(() {
          _showDonationSection = enabled;
          _donationPresets = presets;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFirstOrderCoupons() async {
    try {
      final data = await _supabase
          .from('offers')
          .select(
            'coupon_code, description, delivery_discount_type, platform_fee_discount_type, packaging_fee_discount_type',
          )
          .eq('is_active', true)
          .eq('order_number_target', 1)
          .limit(3);
      if (mounted) {
        setState(
          () => _firstOrderCoupons = List<Map<String, dynamic>>.from(data),
        );
      }
    } catch (_) {}
  }

  bool _isCodAllowed(double cartTotal) {
    if (cartTotal > _codLimit) return false;
    return true;
  }

  @override
  void dispose() {
    _razorpay?.clear(); // null-safe: no-op on web
    _addressController.dispose();
    _landmarkController.dispose();
    _otherAddressController.dispose();
    _otherLandmarkController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _offerController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showAppClosedDialog(
    TimeOfDay openTime,
    TimeOfDay closeTime,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0x14000000),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primaryColor.withOpacity(0.08),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.25),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/illus_sleeping_chef.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'We\'re Closed Right Now',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Streat Eats opens daily from\n${openTime.format(context)} to ${closeTime.format(context)}.\nOrders can only be placed during this time.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: _primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${openTime.format(context)}  –  ${closeTime.format(context)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Payment success: ${response.paymentId}');
    if (_pendingOrderId == null) return;
    setState(() => _isLoading = true);
    try {
      // ✅ Saare vendor orders ko paid mark karo — sirf first wala nahi
      for (final o in _pendingOrders) {
        await _supabase
            .from('orders')
            .update({
              'payment_status': 'paid',
              'payment_method': 'online',
              'status': 'placed',
              'razorpay_payment_id': response.paymentId,
              'razorpay_order_id': response.orderId,
              'razorpay_signature': response.signature,
            })
            .eq('id', o.id);
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.rpc(
          'increment_order_count',
          params: {'user_id': userId},
        );
      }

      // ✅ Payment confirm ho gaya — AB admin + riders ko notify karo
      // (insert time pe online orders ke liye ye intentionally skip kiya tha)
      for (final o in _pendingOrders) {
        unawaited(
          _orderService.notifyAdminAndRiders(
            orderId: o.id,
            vendorName: o.vendorName,
            amount: o.total.toDouble(),
            deliveryCharge: o.deliveryCharge.toDouble(),
          ),
        );
      }

      final order = await _orderService.getOrderById(_pendingOrderId!);
      if (!mounted) return;

      context.read<CartProvider>().clearCart();
      _pendingOrderId = null;
      _pendingOrders = [];
      setState(() => _isLoading = false);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(order: order),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Order confirm error: ${e.toString()}', isError: true);
    }
  }

  void _onPaymentError(PaymentFailureResponse response) async {
    debugPrint('Payment error: ${response.code} — ${response.message}');
    // ✅ Saare vendor orders cancel karo — sirf first nahi, warna baaki
    // vendor orders 'awaiting_payment' mein hamesha ke liye atak jaate
    for (final o in _pendingOrders) {
      try {
        await _supabase
            .from('orders')
            .update({'status': 'cancelled', 'payment_status': 'failed'})
            .eq('id', o.id);
      } catch (_) {}
    }
    _pendingOrderId = null;
    _pendingOrders = [];
    if (!mounted) return;
    setState(() => _isLoading = false);
    _snack('Payment failed. Please try again.', isError: true);
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

  void _snack(String msg, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    if (isError) {
      AppSnackBar.showError(context, msg);
    } else if (isWarning) {
      AppSnackBar.showWarning(context, msg);
    } else {
      AppSnackBar.showSuccess(context, msg);
    }
  }

  double _getFinalTotal(CartProvider cart) {
    final offerDiscount = _appliedOffer?.totalDiscount ?? 0;
    final baseTotal = (cart.total - offerDiscount).clamp(1.0, double.infinity);
    return (baseTotal + _selectedDonationAmount).clamp(1.0, double.infinity);
  }

  // Cash round off — ab COD aur Online dono payment methods pe
  // equally apply hota hai, taaki total har jagah same dikhe
  double _getCashRoundOff(double finalTotal) {
    final rounded = finalTotal.roundToDouble();
    return rounded - finalTotal; // positive = user ko faida, negative = extra
  }

  double _getRoundedTotal(double finalTotal) {
    return finalTotal.roundToDouble();
  }

  // ── v4.0: Get active delivery address ────────────────────────
  // Returns the address string and landmark for order placement
  ({String address, String landmark, String? recipientPhone})
  _getActiveAddress() {
    if (_addressMode == _AddressMode.myLocation) {
      return (
        address: _addressController.text.trim(),
        landmark: _landmarkController.text.trim(),
        recipientPhone: null,
      );
    } else {
      return (
        address: _otherAddressController.text.trim(),
        landmark: _otherLandmarkController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim().isEmpty
            ? null
            : _recipientPhoneController.text.trim(),
      );
    }
  }

  Future<void> _applyOffer() async {
    final code = _offerController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _offerError = 'Enter an offer code first';
        _appliedOffer = null;
      });
      return;
    }
    setState(() {
      _isValidatingOffer = true;
      _offerError = null;
      _appliedOffer = null;
    });
    final cart = context.read<CartProvider>();

    final result = await _offerService.validateOffer(
      code: code,
      cartSubtotal: cart.subtotal,
      deliveryCharge: cart.deliveryCharge,
      platformFee: cart.platformFee,
      packagingFee: cart.packagingFee,
    );
    if (!mounted) return;
    if (result.isValid) {
      HapticFeedback.lightImpact();
      setState(() {
        _appliedOffer = result;
        _offerError = null;
        _isValidatingOffer = false;
      });
    } else {
      setState(() {
        _offerError = result.errorMessage;
        _appliedOffer = null;
        _isValidatingOffer = false;
      });
    }
  }

  void _removeOffer() => setState(() {
    _appliedOffer = null;
    _offerError = null;
    _offerController.clear();
  });

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Login Required',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        content: const Text(
          'Please login or create an account to place your order.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: _textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Later',
              style: TextStyle(color: _textMuted, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Login',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileIncompleteAlert({
    required bool nameMissing,
    required bool phoneMissing,
  }) async {
    final nameController = TextEditingController(
      text: nameMissing
          ? ''
          : (context.read<UserProvider>().userData?['full_name'] ?? ''),
    );
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        final message = nameMissing && phoneMissing
            ? 'Please add your name and phone number before placing an order.'
            : nameMissing
            ? 'Please add your name before placing an order.'
            : 'Your phone number is missing. Please contact support.';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: _surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: _textMuted,
                    height: 1.5,
                  ),
                ),
                if (nameMissing) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: _textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Your Full Name',
                      labelStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: _textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: _primaryColor,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textMuted, fontFamily: 'Poppins'),
                ),
              ),
              if (nameMissing)
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            _snack('Please enter your name', isError: true);
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final userId = _supabase.auth.currentUser?.id;
                            if (userId != null) {
                              await _supabase
                                  .from('users')
                                  .update({'full_name': name})
                                  .eq('id', userId);
                              if (mounted) {
                                await context
                                    .read<UserProvider>()
                                    .fetchUserData();
                                _nameController.text = name;
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            _snack(
                              'Failed to save name. Try again.',
                              isError: true,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                )
              else
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationRequiredDialog(bool serviceEnabled) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAE8E4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFD97706),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Required',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: Color(0xFF1A1814),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                serviceEnabled
                    ? 'Please allow location access to place an order. We need it to calculate delivery distance.'
                    : 'Please turn on your device location to place an order.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9E9893),
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEAE8E4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF9E9893),
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ls = LocationService();
                        if (!serviceEnabled) {
                          await ls.openLocationSettings();
                        } else {
                          final perm = await ls.isPermanentlyDenied();
                          if (perm) {
                            await ls.openAppSettings();
                          } else {
                            await ls.requestPermission();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B2B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        serviceEnabled ? 'Allow Access' : 'Open Settings',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    // ✅ APP OPEN/CLOSE CHECK
    setState(() => _loadingMessage = 'Checking store hours...');
    try {
      final settings = await _supabase
          .from('app_settings')
          .select('is_timing_enabled, open_time, close_time')
          .limit(1)
          .maybeSingle();

      final isOpen = await _orderService.isAppOpen();
      if (!isOpen) {
        final nextOpenStr = await _orderService.getNextOpenTime();
        final nextParts = nextOpenStr.split(':');
        final nextOpenTime = TimeOfDay(
          hour: int.tryParse(nextParts[0]) ?? 17,
          minute: int.tryParse(nextParts.length > 1 ? nextParts[1] : '0') ?? 0,
        );
        TimeOfDay closeTime = const TimeOfDay(hour: 21, minute: 0);
        try {
          final slotsRaw = settings?['time_slots'] as List?;
          if (slotsRaw != null) {
            for (final slot in slotsRaw) {
              final openStr = slot['open'] as String? ?? '';
              final closeStr = slot['close'] as String? ?? '';
              if (openStr == nextOpenStr && closeStr.isNotEmpty) {
                final cp = closeStr.split(':');
                closeTime = TimeOfDay(
                  hour: int.tryParse(cp[0]) ?? 21,
                  minute: int.tryParse(cp.length > 1 ? cp[1] : '0') ?? 0,
                );
                break;
              }
            }
          }
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _showPaymentLoading = false;
        });
        await _showAppClosedDialog(nextOpenTime, closeTime);
        return;
      }
    } catch (_) {
      // DB error pe order block mat karo
    }

    // v4.0: Location check only needed for GPS mode
    if (_addressMode == _AddressMode.myLocation) {
      setState(() => _loadingMessage = 'Checking your location...');
      final locationService = LocationService();
      final serviceEnabled = await locationService.isLocationServiceEnabled();
      final hasPermission = await locationService.hasPermission();
      if (!serviceEnabled || !hasPermission) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _showPaymentLoading = false;
        });
        _showLocationRequiredDialog(serviceEnabled);
        return;
      }
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showLoginPrompt(context);
      return;
    }

    final userProvider = context.read<UserProvider>();
    final customerName = userProvider.userData?['full_name'] as String? ?? '';
    final userPhone = userProvider.userData?['phone'] as String? ?? '';
    final nameMissing = customerName.trim().isEmpty;
    final phoneMissing = userPhone.trim().isEmpty;

    if (nameMissing || phoneMissing) {
      await _showProfileIncompleteAlert(
        nameMissing: nameMissing,
        phoneMissing: phoneMissing,
      );
      final updatedName =
          context.read<UserProvider>().userData?['full_name'] as String? ?? '';
      final updatedPhone =
          context.read<UserProvider>().userData?['phone'] as String? ?? '';
      if (updatedName.trim().isEmpty || updatedPhone.trim().isEmpty) return;
    }

    // v4.0: Validate active address
    final activeAddr = _getActiveAddress();
    if (activeAddr.address.isEmpty) {
      _snack('Please enter delivery address', isError: true);
      return;
    }

    // v4.0: For "other location", validate other address fields
    if (_addressMode == _AddressMode.otherLocation) {
      if (_otherAddressController.text.trim().isEmpty) {
        _snack('Please enter the delivery address', isError: true);
        return;
      }
      // ✅ v4.1: Recipient orders ke liye map pin mandatory — GPS use nahi hoga
      if (_otherPickedLat == null || _otherPickedLng == null) {
        _snack(
          'Please select the exact delivery location on map',
          isError: true,
        );
        return;
      }
      // Validate recipient phone if provided
      if (_recipientPhoneController.text.trim().isNotEmpty) {
        final phone = _recipientPhoneController.text.trim().replaceAll(' ', '');
        if (phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
          _snack(
            'Enter a valid 10-digit recipient phone number',
            isError: true,
          );
          return;
        }
      }
    }

    final cart = context.read<CartProvider>();
    final finalTotal = _getFinalTotal(cart);
    if (finalTotal < 1) {
      _snack('Order amount is invalid. Try removing the offer.', isError: true);
      return;
    }

    if (_selectedPayment == 'cod' && !_isCodAllowed(cart.total)) {
      _snack(
        'COD is only available for orders up to ₹$_codLimit. Please pay online.',
        isWarning: true,
      );
      setState(() {
        _showPaymentLoading = false;
        _selectedPayment = 'online';
      });
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _loadingMessage = _selectedPayment == 'online'
          ? 'Opening payment gateway...'
          : 'Placing your order...';
    });

    try {
      final finalUserPhone = userProvider.userData?['phone'] as String? ?? '';
      final finalCustomerName =
          userProvider.userData?['full_name'] as String? ?? '';
      final userId = _supabase.auth.currentUser?.id;

      setState(() => _loadingMessage = 'Saving your details...');
      // v4.0: Save address based on mode
      if (_addressMode == _AddressMode.myLocation && userId != null) {
        // ✅ v4.1: Map-pinned location > GPS — jo bhi sabse accurate mile use karo
        double? savedLat = _myPickedLat;
        double? savedLng = _myPickedLng;
        if (savedLat == null || savedLng == null) {
          try {
            final locationService = LocationService();
            final pos = await locationService.getCurrentPosition();
            savedLat = pos?.latitude;
            savedLng = pos?.longitude;
          } catch (_) {}
        }

        await _supabase
            .from('users')
            .update({
              'delivery_address': activeAddr.address,
              'delivery_landmark': activeAddr.landmark,
              if (savedLat != null) 'last_lat': savedLat,
              if (savedLng != null) 'last_lng': savedLng,
            })
            .eq('id', userId);
        userProvider.updateDeliveryAddress(
          activeAddr.address,
          activeAddr.landmark,
        );
      }

      // v4.0: Build full address string for rider
      // Manual address: include recipient name if provided
      String orderAddress = activeAddr.address;
      String orderLandmark = activeAddr.landmark;

      if (_addressMode == _AddressMode.otherLocation &&
          _recipientNameController.text.trim().isNotEmpty) {
        orderAddress =
            'For: ${_recipientNameController.text.trim()}\n$orderAddress';
      }

      // v4.0: Determine contact phone for this order
      // If manual address has a recipient phone, use that for rider contact
      final contactPhone = activeAddr.recipientPhone ?? finalUserPhone;

      final offerDiscount = (_appliedOffer?.totalDiscount ?? 0).round();
      final paymentDiscount = _selectedPayment == 'online'
          ? _onlineDiscount
          : 0;
      final offerCode = _appliedOffer != null
          ? _offerController.text.trim().toUpperCase()
          : null;
      final totalDiscount = offerDiscount + paymentDiscount;

      // ── Shift check — koi vendor current shift mein off to nahi? ──
      for (final vendor in cart.vendors) {
        if (!vendor.isCurrentShiftActive) {
          setState(() {
            _isLoading = false;
            _showPaymentLoading = false;
          });
          _snack(
            '${vendor.name} is not available in this shift. Please remove their items and try again.',
            isError: true,
          );
          return;
        }
      }

      // ── Multi-vendor: har vendor ke liye alag order ────────────────
      final vendorGroups = <String, List<CartItem>>{};
      for (final ci in cart.items.values) {
        vendorGroups.putIfAbsent(ci.vendor.id, () => []).add(ci);
      }

      setState(() => _loadingMessage = 'Placing your order...');
      final placedOrders = <OrderModel>[];
      final vendors = cart.vendors;

      // ✅ v4.1: Map-selected coordinates — recipient mode mandatory hai
      final double? orderCustomerLat =
          _addressMode == _AddressMode.otherLocation
          ? _otherPickedLat
          : _myPickedLat;
      final double? orderCustomerLng =
          _addressMode == _AddressMode.otherLocation
          ? _otherPickedLng
          : _myPickedLng;

      for (final vendor in vendors) {
        final vendorItems = vendorGroups[vendor.id] ?? [];
        if (vendorItems.isEmpty) continue;

        // Temporary single-vendor cart simulate karo
        final singleVendorOrder = await _orderService.placeOrderForVendor(
          vendor: vendor,
          items: vendorItems,
          cart: cart,
          address: orderAddress,
          landmark: orderLandmark,
          userPhone: contactPhone,
          onlineDiscount: vendors.indexOf(vendor) == 0 ? totalDiscount : 0,
          // ✅ FIX: Promo code ka delivery-specific discount alag se pass karo
          // taaki rider ki earning discounted delivery charge se match kare
          deliveryDiscount: vendors.indexOf(vendor) == 0
              ? (_appliedOffer?.deliveryDiscount ?? 0).round()
              : 0,
          // Platform fee sirf pehle order pe lagao
          applyPlatformFee: vendors.indexOf(vendor) == 0,
          customerLat: orderCustomerLat,
          customerLng: orderCustomerLng,
          paymentMethod: _selectedPayment,
        );
        placedOrders.add(singleVendorOrder);
      }

      final order = placedOrders.first; // Confirmation ke liye pehla order

      // v4.0: Save address type + recipient info to order for rider reference
      // ✅ v4.1: customer_lat/lng ab placeOrderForVendor insert ke time hi
      // accurate save ho jata hai (map-pin se) — dobara GPS fetch ki zaroorat nahi
      final isManualAddress = _addressMode == _AddressMode.otherLocation;

      try {
        for (final o in placedOrders) {
          await _supabase
              .from('orders')
              .update({
                'is_manual_address': isManualAddress,
                'address_type': isManualAddress ? 'manual' : 'gps',
                'recipient_name':
                    isManualAddress &&
                        _recipientNameController.text.trim().isNotEmpty
                    ? _recipientNameController.text.trim()
                    : null,
                'recipient_phone':
                    isManualAddress &&
                        _recipientPhoneController.text.trim().isNotEmpty
                    ? _recipientPhoneController.text.trim()
                    : null,
              })
              .eq('id', o.id);
        }
      } catch (_) {}

      if (_appliedOffer != null && _appliedOffer!.offerId != null) {
        await _offerService.recordOfferUse(
          offerId: _appliedOffer!.offerId!,
          orderId: order.id,
        );
      }
      // First order flag update
      if (_appliedOffer != null) {
        try {
          final offerData = await _supabase
              .from('offers')
              .select('is_first_order_offer')
              .eq('code', _offerController.text.trim().toUpperCase())
              .maybeSingle();
          if (offerData?['is_first_order_offer'] == true) {
            await _supabase
                .from('users')
                .update({'has_placed_first_order': true})
                .eq('id', _supabase.auth.currentUser!.id);
          }
        } catch (_) {}
      }
      if (_appliedOffer != null) {
        final appliedCode = _offerController.text.trim().toUpperCase();
        try {
          final offerData = await _supabase
              .from('offers')
              .select('commission_per_order')
              .eq('code', appliedCode)
              .maybeSingle();
          final commission =
              (offerData?['commission_per_order'] as num?)?.toDouble() ?? 0;
          await _supabase
              .from('orders')
              .update({
                'applied_promo_code': appliedCode,
                'affiliate_commission_logged': commission,
              })
              .eq('id', order.id);
        } catch (_) {}
      }

      if (_selectedDonationAmount > 0) {
        try {
          await _supabase
              .from('orders')
              .update({'donation_amount': _selectedDonationAmount})
              .eq('id', order.id);
          await _supabase.from('donations').insert({
            'amount': _selectedDonationAmount,
            'status': 'pending',
            'user_id': userId,
            'order_id': order.id,
            'type': 'checkout_donation',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      // ✅ FIX: pehle sirf order.id (pehla vendor) update hota tha — multi-vendor
      // cart mein baaki vendors ke orders 'cod'/'placed' pe hi stuck reh jaate the
      // ✅ Checkout pe jo exact rounded total dikhaya gaya tha, wahi
      // primary order ke 'total' field mein overwrite karo. Without this,
      // order_service apna alag total calculate karta tha (no rounding,
      // no donation) — isi wajah se Order Status/Confirmation screen pe
      // mismatch dikhta tha checkout ke total se.
      final roundedFinalTotal = _getRoundedTotal(finalTotal);
      for (final o in placedOrders) {
        await _supabase
            .from('orders')
            .update({
              'payment_method': _selectedPayment,
              'payment_status': _selectedPayment == 'online'
                  ? 'pending'
                  : 'cod',
              'status': _selectedPayment == 'online'
                  ? 'awaiting_payment'
                  : 'placed',
              'order_placed_at': DateTime.now().toIso8601String(),
              'tip_amount': cart.tipAmount,
              // Offer/discount label only on first order — discount was
              // only applied to that vendor at insert time
              if (o.id == order.id) 'offer_code': offerCode,
              if (o.id == order.id) 'offer_discount': offerDiscount,
              if (o.id == order.id) 'online_payment_discount': paymentDiscount,
              // Primary order's total = exact amount shown at checkout
              if (o.id == order.id) 'total': roundedFinalTotal,
            })
            .eq('id', o.id);
      }
      // Online flow ke liye saare orders track karo — payment success/fail
      // ke time inhi ko update + notify karna hai
      _pendingOrders = placedOrders;

      // ── COD FLOW ──────────────────────────────────────────────
      if (_selectedPayment == 'cod') {
        setState(() => _loadingMessage = 'Almost done! 🎉');

        // Admin + rider already notified per-vendor inside
        // OrderService.placeOrderForVendor() above — no need again here
        if (userId != null) {
          unawaited(
            _supabase.rpc('increment_order_count', params: {'user_id': userId}),
          );
        }

        cart.clearCart();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _showPaymentLoading = false;
        });
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(
              order: placedOrders.first,
              allOrders: placedOrders,
            ),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      // ── ONLINE FLOW ───────────────────────────────────────────
      final rzpData = await RazorpayService.createOrder(
        orderId: order.id,
        amount: _getRoundedTotal(finalTotal),
      );

      if (rzpData == null) {
        await _supabase
            .from('orders')
            .update({'status': 'cancelled', 'payment_status': 'failed'})
            .eq('id', order.id);
        throw Exception('Payment gateway error. Please try COD.');
      }

      final keyId = rzpData['key_id'];
      final rzpOrderId = rzpData['razorpay_order_id'];
      final rzpAmount = rzpData['amount'];

      if (keyId == null || rzpOrderId == null) {
        await _supabase
            .from('orders')
            .update({'status': 'cancelled', 'payment_status': 'failed'})
            .eq('id', order.id);
        throw Exception('Invalid payment data. Please try COD.');
      }

      _pendingOrderId = order.id;
      setState(() {
        _isLoading = false;
        _showPaymentLoading = false;
      });

      // ── PAYMENT TRIGGER ─────────────────────────────────────────
      final payOptions = {
        'key': keyId,
        'order_id': rzpOrderId,
        'amount': rzpAmount,
        'currency': 'INR',
        'name': 'Streat Eats',
        'description':
            'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
        'prefill': {'contact': finalUserPhone, 'name': finalCustomerName},
        'theme': {'color': '#FF6B35'},
      };

      if (kIsWeb) {
        // ── WEB: Razorpay JS Checkout ──────────────────────────────
        // Same order data, but opens via the JS SDK instead of native plugin.
        RazorpayWebCheckout.open(
          options: payOptions,
          onSuccess: (paymentId, orderId, signature) {
            // Wrap in a fake PaymentSuccessResponse-compatible call
            _onPaymentSuccessWeb(paymentId, orderId, signature);
          },
          onError: (code, message) {
            _onPaymentErrorWeb(code, message);
          },
        );
      } else {
        // ── NATIVE: Razorpay Flutter SDK ───────────────────────────
        _razorpay!.open(payOptions);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showPaymentLoading = false;
        });
        _snack('Order failed: ${e.toString()}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final userProvider = context.watch<UserProvider>();
    final userData = userProvider.userData;
    final offerDiscount = (_appliedOffer?.totalDiscount ?? 0).round();
    final paymentDiscount = _selectedPayment == 'online' ? _onlineDiscount : 0;
    final finalTotal = _getFinalTotal(cart);
    final deliveryCharge = cart.deliveryCharge;
    final isFreeDelivery = deliveryCharge == 0;
    final packagingFee = cart.packagingFee;
    final isManualMode = _addressMode == _AddressMode.otherLocation;

    final codAllowed = _isCodAllowed(cart.total);
    if (!codAllowed && _selectedPayment == 'cod') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedPayment == 'cod') {
          setState(() => _selectedPayment = 'online');
        }
      });
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── v4.0: ADDRESS MODE SELECTOR ────────────
                        _sectionLabel('DELIVERY ADDRESS'),
                        const SizedBox(height: 12),
                        _buildAddressModeSelector(),
                        const SizedBox(height: 14),

                        // My Location section
                        if (_addressMode == _AddressMode.myLocation) ...[
                          if (!_isEditingAddress &&
                              _addressController.text.isNotEmpty)
                            _buildSavedAddressCard()
                          else
                            _buildAddressEditFields(),
                        ],

                        // Other Location section
                        if (_addressMode == _AddressMode.otherLocation)
                          _buildOtherLocationFields(),

                        const SizedBox(height: 24),
                        _sectionLabel('CONTACT'),
                        const SizedBox(height: 12),
                        _buildContactSection(userData),
                        const SizedBox(height: 24),
                        _sectionLabel('PAYMENT METHOD'),
                        const SizedBox(height: 12),
                        _buildPaymentSelector(cart.total),

                        const SizedBox(height: 24),
                        _sectionLabel('OFFER CODE'),
                        const SizedBox(height: 12),
                        // ── First order coupon suggestion ──
                        if (_appliedOffer == null &&
                            _userDataLoaded &&
                            _userTotalOrders == 0)
                          _buildCouponSuggestionBanner(),
                        if (_appliedOffer == null &&
                            _userDataLoaded &&
                            _userTotalOrders == 0)
                          const SizedBox(height: 10),
                        if (_appliedOffer != null)
                          _buildAppliedOfferCard()
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _offerController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter offer code',
                                    hintStyle: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 13,
                                      fontFamily: 'Poppins',
                                      letterSpacing: 0,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.local_offer_outlined,
                                      color: _textMuted,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: _surfaceColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: _borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: _offerError != null
                                            ? _errorColor
                                            : _borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: _primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(14),
                                    errorText: _offerError,
                                    errorStyle: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: _errorColor,
                                    ),
                                  ),
                                  onSubmitted: (_) => _applyOffer(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isValidatingOffer
                                      ? null
                                      : _applyOffer,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                  child: _isValidatingOffer
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Apply',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_showDonationSection) ...[
                          const SizedBox(height: 24),
                          _buildDonationSection(),
                        ],

                        const SizedBox(height: 24),
                        _sectionLabel('ORDER SUMMARY'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Column(
                            children: [
                              ...cart.items.values.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.item.name} × ${item.quantity}',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            color: _textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '₹${item.totalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(color: _borderColor, height: 20),
                              _summaryRow(
                                'Subtotal',
                                '₹${cart.subtotal.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 6),
                              // v4.0: Manual address = show "Standard Rate" label
                              // ── Delivery — multi-vendor breakdown ──
                              if (cart.uniqueVendorCount > 1) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isManualMode
                                          ? 'Delivery (Standard Rate)'
                                          : 'Delivery',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: _textMuted,
                                      ),
                                    ),
                                    Text(
                                      isFreeDelivery
                                          ? 'FREE'
                                          : '₹${deliveryCharge.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isFreeDelivery
                                            ? _successColor
                                            : _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                ...cart.vendors.map((v) {
                                  final vCharge = cart.calculateDeliveryCharge(
                                    isManualMode
                                        ? 4.5 // manual fallback same as CartProvider
                                        : (v.distanceKm ?? 0),
                                  );
                                  final isFree = vCharge <= 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const SizedBox(width: 12),
                                            const Icon(
                                              Icons
                                                  .subdirectory_arrow_right_rounded,
                                              size: 13,
                                              color: _textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              v.name,
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 11,
                                                color: _textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          isFree
                                              ? 'FREE'
                                              : '₹${vCharge.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isFree
                                                ? _successColor
                                                : _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (isManualMode) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    '* Exact charge based on your location',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: _textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ] else ...[
                                _feeRowWithDiscount(
                                  label: isManualMode
                                      ? 'Delivery (Standard Rate)'
                                      : 'Delivery',
                                  original: deliveryCharge,
                                  discount:
                                      _appliedOffer?.deliveryDiscount ?? 0,
                                  isFreeIfZero: true,
                                ),
                                if (isManualMode) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    '* Exact charge based on your location',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: _textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                              const SizedBox(height: 6),
                              _feeRowWithDiscount(
                                label: 'Platform Fee',
                                original: cart.platformFee,
                                discount:
                                    _appliedOffer?.platformFeeDiscount ?? 0,
                              ),
                              const SizedBox(height: 6),
                              _feeRowWithDiscount(
                                label: 'Packaging Fee',
                                original: packagingFee,
                                discount:
                                    _appliedOffer?.packagingFeeDiscount ?? 0,
                              ),
                              if (cart.tipAmount > 0) ...[
                                const SizedBox(height: 6),
                                _summaryRow(
                                  'Rider Tip 🛵',
                                  '+ ₹${cart.tipAmount}',
                                  valueColor: _successColor,
                                ),
                              ],
                              if (offerDiscount > 0) ...[
                                const SizedBox(height: 6),
                                _summaryRow(
                                  'Offer (${_offerController.text.toUpperCase()})',
                                  '- ₹$offerDiscount',
                                  valueColor: _successColor,
                                ),
                              ],
                              if (paymentDiscount > 0) ...[
                                const SizedBox(height: 6),
                                _summaryRow(
                                  'Online Discount',
                                  '- ₹$paymentDiscount',
                                  valueColor: _successColor,
                                ),
                              ],

                              if (_selectedDonationAmount > 0) ...[
                                const SizedBox(height: 6),
                                _summaryRow(
                                  'Dog Donation 🐾',
                                  '+ ₹$_selectedDonationAmount',
                                  valueColor: const Color(0xFF92400E),
                                ),
                              ],
                              const Divider(color: _borderColor, height: 20),
                              // ── Savings box — sirf tab dikhao jab koi discount ho ──
                              Builder(
                                builder: (_) {
                                  // Total item-level discount calculate karo
                                  double itemSavings = 0;
                                  for (final ci in cart.items.values) {
                                    if (ci.item.isDiscounted &&
                                        ci.item.originalPrice != null) {
                                      itemSavings +=
                                          (ci.item.originalPrice! -
                                              ci.item.appPrice) *
                                          ci.quantity;
                                    }
                                  }
                                  // Other platforms vs our total
                                  // (other platforms full original price
                                  // charge karte, discount nahi dete)
                                  final otherPlatformSubtotal =
                                      cart.subtotal + itemSavings;
                                  final otherPlatformTotal =
                                      otherPlatformSubtotal +
                                      _otherPlatformDelivery +
                                      _otherPlatformFee;
                                  final ourTotal = finalTotal;
                                  final platformSavings =
                                      otherPlatformTotal - ourTotal;
                                  final totalSaved = platformSavings > 0
                                      ? platformSavings
                                      : itemSavings;
                                  if (totalSaved <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: _successColor.withOpacity(
                                            0.07,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _successColor.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'You saved ₹${totalSaved.toStringAsFixed(0)} on this order 🎉',
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: _successColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if ((_appliedOffer?.totalDiscount ??
                                                    0) >
                                                0) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.local_offer_rounded,
                                                    size: 12,
                                                    color: _successColor,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'Coupon saved you ₹${_appliedOffer!.totalDiscount.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 11,
                                                      color: _successColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (platformSavings > 0) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Other platforms would have charged ₹${otherPlatformTotal.toStringAsFixed(0)} for this same order',
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 11,
                                                  color: _successColor,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                },
                              ),
                              // ── Grand Total → Round Off → Total to Pay ──
                              // Fixed order so the user clearly sees the raw
                              // total first, then how round-off changed it
                              _summaryRow(
                                'Grand Total',
                                '₹${finalTotal.toStringAsFixed(2)}',
                              ),
                              if (_getCashRoundOff(finalTotal) != 0) ...[
                                const SizedBox(height: 6),
                                _summaryRow(
                                  'Cash Round Off',
                                  _getCashRoundOff(finalTotal) >= 0
                                      ? '+₹${_getCashRoundOff(finalTotal).toStringAsFixed(2)}'
                                      : '-₹${_getCashRoundOff(finalTotal).abs().toStringAsFixed(2)}',
                                  valueColor: _getCashRoundOff(finalTotal) >= 0
                                      ? _successColor
                                      : _errorColor,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total to Pay',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '₹${_getRoundedTotal(finalTotal).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 13,
                                      color: _textMuted.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _selectedPayment == 'online'
                                            ? 'Payment securely processed by Razorpay'
                                            : 'Your order is safe with us',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          color: _textMuted.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                _buildPlaceOrderButton(finalTotal),
              ],
            ),
          ),
        ),
        if (_showPaymentLoading) _buildPaymentLoadingOverlay(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // v4.0 NEW WIDGETS — Address Mode
  // ═══════════════════════════════════════════════════════════

  Widget _buildPaymentLoadingOverlay() {
    return Material(
      color: const Color(0xFFFFF8F0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B35).withOpacity(0.10),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.30),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('🍔', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                color: const Color(0xFFFF6B35),
                strokeWidth: 3.5,
                backgroundColor: const Color(0xFFFF6B35).withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedPayment == 'online'
                  ? 'Secure payment powered by Razorpay'
                  : 'Please wait a moment...',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.20),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: Color(0xFFFF6B35),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Streat Eats — Ghar Baithe Street Ka Swad',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle selector: My Location vs Other Location
  Widget _buildAddressModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_addressMode == _AddressMode.myLocation) return;
                HapticFeedback.selectionClick();
                setState(() => _addressMode = _AddressMode.myLocation);
                _syncGpsAddressToCart();
                if (_myPickedLat != null && _myPickedLng != null) {
                  _recalculateDeliveryEstimate(
                    lat: _myPickedLat!,
                    lng: _myPickedLng!,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: _addressMode == _AddressMode.myLocation
                      ? _primaryColor
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(13),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: _addressMode == _AddressMode.myLocation
                          ? Colors.white
                          : _textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'My Location',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _addressMode == _AddressMode.myLocation
                            ? Colors.white
                            : _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_addressMode == _AddressMode.otherLocation) return;
                HapticFeedback.selectionClick();
                setState(() => _addressMode = _AddressMode.otherLocation);
                _syncManualAddressToCart();
                if (_otherPickedLat != null && _otherPickedLng != null) {
                  _recalculateDeliveryEstimate(
                    lat: _otherPickedLat!,
                    lng: _otherPickedLng!,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: _addressMode == _AddressMode.otherLocation
                      ? _primaryColor
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(13),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.share_location_rounded,
                      size: 16,
                      color: _addressMode == _AddressMode.otherLocation
                          ? Colors.white
                          : _textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Other Location',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _addressMode == _AddressMode.otherLocation
                            ? Colors.white
                            : _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Other location fields — address + landmark + optional recipient info
  Widget _buildOtherLocationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF0369A1),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Rider will use the address you enter here. Google Maps button in rider app will open this address.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFF0369A1),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Full address (required)
        _buildTextField(
          controller: _otherAddressController,
          hint: 'Full address — house no., street, area',
          icon: Icons.location_on_outlined,
          maxLines: 2,
          onChanged: (_) => _syncManualAddressToCart(),
        ),
        const SizedBox(height: 10),

        // Landmark (optional but recommended)
        _buildTextField(
          controller: _otherLandmarkController,
          hint: 'Landmark (e.g. near State Bank ATM)',
          icon: Icons.pin_drop_outlined,
          onChanged: (_) => _syncManualAddressToCart(),
        ),
        const SizedBox(height: 10),
        _buildMapPickerButton(isOtherMode: true),
        const SizedBox(height: 14),

        // Recipient toggle
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showRecipientFields = !_showRecipientFields);
          },
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _showRecipientFields
                      ? _primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _showRecipientFields ? _primaryColor : _borderColor,
                    width: 2,
                  ),
                ),
                child: _showRecipientFields
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
              const SizedBox(width: 8),
              const Text(
                'Delivering to someone else? (optional)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Recipient fields (animated expand)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                _buildTextField(
                  controller: _recipientNameController,
                  hint: 'Recipient name (e.g. Priya, Mom)',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _recipientPhoneController,
                  hint: 'Recipient phone (rider will call this)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                ),
                const SizedBox(height: 6),
                const Text(
                  '* If provided, rider will call this number instead of yours',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: _textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _showRecipientFields
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EXISTING WIDGETS (unchanged from v3.0)
  // ═══════════════════════════════════════════════════════════

  Widget _buildContactSection(Map<String, dynamic>? userData) {
    final phone = userData?['phone'] as String? ?? '';
    final hasPhone = phone.trim().isNotEmpty;

    if (hasPhone) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_outlined, color: _primaryColor, size: 20),
            const SizedBox(width: 12),
            Text(
              '+91 $phone',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _successColor.withOpacity(0.3)),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _successColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warningColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.phone_missed_outlined,
              color: _warningColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone number missing!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Rider calls before delivery',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showAddPhoneBottomSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Add Now',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPhoneBottomSheet() {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add Phone Number',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Rider calls before delivery',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                        letterSpacing: 1,
                      ),
                      decoration: InputDecoration(
                        hintText: '9876543210',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          color: _textMuted.withOpacity(0.5),
                          letterSpacing: 1,
                        ),
                        prefixText: '+91  ',
                        prefixStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: _primaryColor,
                          size: 22,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: _bgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _primaryColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _errorColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone number required';
                        }
                        final digits = v.trim().replaceAll(' ', '');
                        if (digits.length != 10 ||
                            !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                          return 'Enter a valid 10-digit number (starts with 6-9)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isSaving = true);
                                try {
                                  final userId = _supabase.auth.currentUser?.id;
                                  if (userId == null) return;
                                  final phone = phoneController.text
                                      .trim()
                                      .replaceAll(' ', '');
                                  await _supabase
                                      .from('users')
                                      .update({'phone': phone})
                                      .eq('id', userId);
                                  if (mounted) {
                                    await context
                                        .read<UserProvider>()
                                        .fetchUserData();
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _snack('Phone number added successfully!');
                                } catch (e) {
                                  setSheetState(() => isSaving = false);
                                  _snack(
                                    'Save failed. Try again.',
                                    isError: true,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _primaryColor.withOpacity(
                            0.5,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDonationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF92400E).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🐾', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feed a Street Dog?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      'A small help with your order',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DonationScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Know More',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDonationAmount = 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedDonationAmount == 0
                        ? const Color(0xFF92400E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedDonationAmount == 0
                          ? const Color(0xFF92400E)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _selectedDonationAmount == 0
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              ..._donationPresets.map((amount) {
                final isSelected = _selectedDonationAmount == amount;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDonationAmount = amount);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _primaryColor : _borderColor,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      '₹$amount',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : _textPrimary,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          if (_selectedDonationAmount > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🐕', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '₹$_selectedDonationAmount will feed a dog today!',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
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

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: _textMuted,
    ),
  );

  Widget _buildPaymentSelector(double cartTotal) {
    final codAllowed = _isCodAllowed(cartTotal);
    final isHighValue = cartTotal > _codLimit;

    return Column(
      children: [
        if (isHighValue) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _warningColor.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _warningColor,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'COD is only available for orders up to ₹$_codLimit. Please pay online.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        _paymentOption(
          value: 'cod',
          icon: Icons.money_rounded,
          title: 'Cash on Delivery',
          subtitle: codAllowed
              ? 'Pay in cash when order arrives'
              : 'Available for orders up to ₹$_codLimit',
          badgeText: null,
          bgColor: const Color(0xFFFFFBEB),
          iconColor: _warningColor,
          borderColor: _warningColor,
          disabled: !codAllowed,
        ),
        const SizedBox(height: 10),
        _paymentOption(
          value: 'online',
          icon: Icons.smartphone_rounded,
          title: 'Pay Online',
          subtitle: 'UPI, Cards, Net Banking — via Razorpay',
          badgeText: null,
          bgColor: const Color(0xFFF5F3FF),
          iconColor: const Color(0xFF7C3AED),
          borderColor: const Color(0xFF7C3AED),
          disabled: false,
        ),
      ],
    );
  }

  Widget _paymentOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required String? badgeText,
    required Color bgColor,
    required Color iconColor,
    required Color borderColor,
    required bool disabled,
  }) {
    final isSelected = _selectedPayment == value;
    return GestureDetector(
      onTap: disabled
          ? () => _snack(
              value == 'cod'
                  ? 'COD not available for orders above ₹$_codLimit'
                  : '',
              isWarning: true,
            )
          : () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPayment = value);
            },
      child: Opacity(
        opacity: disabled ? 0.55 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : _surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? borderColor.withOpacity(0.55) : _borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? iconColor.withOpacity(0.15) : _bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? iconColor : _textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _successColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        if (disabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _textMuted.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Locked',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? iconColor : _borderColor,
                      width: 2,
                    ),
                    color: isSelected ? iconColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponSuggestionBanner() {
    if (_firstOrderCoupons.isEmpty) return const SizedBox.shrink();
    final offers = _firstOrderCoupons;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withOpacity(0.08),
            const Color(0xFF16A34A).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: _primaryColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First Order? Save More! 🎉',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Tap a code below to apply instantly',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Coupon chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: offers.map((offer) {
              final code = offer['coupon_code'] as String? ?? '';
              final desc = offer['description'] as String? ?? '';

              // Benefit text build karo
              final benefits = <String>[];
              if ((offer['delivery_discount_type'] as String?) == 'flat' ||
                  (offer['delivery_discount_type'] as String?) == 'free') {
                benefits.add('Delivery off');
              }
              if ((offer['platform_fee_discount_type'] as String?) == 'free') {
                benefits.add('No platform fee');
              }
              if ((offer['packaging_fee_discount_type'] as String?) == 'free') {
                benefits.add('No packaging fee');
              }
              final benefitText = benefits.isNotEmpty
                  ? benefits.join(' • ')
                  : desc.isNotEmpty
                  ? desc
                  : 'Special discount';

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _offerController.text = code;
                  _applyOffer();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _primaryColor.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        size: 13,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            code,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _primaryColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            benefitText,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppliedOfferCard() {
    final offer = _appliedOffer!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _successColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _successColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _successColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: _successColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _offerController.text.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _successColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _successColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '- ₹${offer.totalDiscount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: _successColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (offer.description != null &&
                    offer.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    offer.description!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: _removeOffer,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: _errorColor,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAddressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_rounded, color: _primaryColor, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Saved Address',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openLocationPicker(isOtherMode: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _primaryColor.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _addressController.text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: _textPrimary,
              height: 1.4,
            ),
          ),
          if (_landmarkController.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _landmarkController.text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: _textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressEditFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _addressController,
          hint: 'Enter your full address',
          icon: Icons.home_outlined,
          maxLines: 2,
          onChanged: (_) => _syncGpsAddressToCart(),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _landmarkController,
          hint: 'Nearby landmark (e.g. near SBI ATM)',
          icon: Icons.location_on_outlined,
          onChanged: (_) => _syncGpsAddressToCart(),
        ),
        const SizedBox(height: 10),
        _buildMapPickerButton(isOtherMode: false),
        if (context.read<UserProvider>().savedAddress.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              final up = context.read<UserProvider>();
              _addressController.text = up.savedAddress;
              _landmarkController.text = up.savedLandmark;
              setState(() => _isEditingAddress = false);
              _syncGpsAddressToCart();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back_rounded, color: _primaryColor, size: 14),
                SizedBox(width: 4),
                Text(
                  'Use saved address',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: _surfaceColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Checkout',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPickerButton({required bool isOtherMode}) {
    final hasPinSet = isOtherMode
        ? (_otherPickedLat != null && _otherPickedLng != null)
        : (_myPickedLat != null && _myPickedLng != null);
    return GestureDetector(
      onTap: () => _openLocationPicker(isOtherMode: isOtherMode),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: hasPinSet
              ? _successColor.withOpacity(0.08)
              : _primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasPinSet
                ? _successColor.withOpacity(0.4)
                : _primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasPinSet ? Icons.check_circle_rounded : Icons.map_rounded,
              color: hasPinSet ? _successColor : _primaryColor,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasPinSet
                    ? 'Exact location pinned on map ✓'
                    : 'Select Exact Location on Map',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasPinSet ? _successColor : _primaryColor,
                ),
              ),
            ),
            Text(
              hasPinSet ? 'Change' : 'Open Map',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: hasPinSet ? _successColor : _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _textMuted,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
        prefixIcon: Icon(icon, color: _textMuted, size: 20),
        filled: true,
        fillColor: _surfaceColor,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _feeRowWithDiscount({
    required String label,
    required double original,
    required double discount,
    bool isFreeIfZero = false,
  }) {
    final hasDiscount = discount > 0;
    final afterDiscount = (original - discount).clamp(0.0, double.infinity);
    final isFinalFree = afterDiscount == 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _textMuted,
          ),
        ),
        Row(
          children: [
            // Original amount — strikethrough red jab discount ho
            if (hasDiscount && original > 0)
              Text(
                '₹${original.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFDC2626), // red — clearly visible
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Color(0xFFDC2626),
                  decorationThickness: 2.0,
                ),
              ),
            if (hasDiscount && original > 0) const SizedBox(width: 6),
            // Final amount after discount
            Text(
              isFinalFree
                  ? (isFreeIfZero && original == 0 ? 'FREE' : 'FREE')
                  : '₹${afterDiscount.toStringAsFixed(0)}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isFinalFree
                    ? _successColor
                    : (hasDiscount ? _successColor : _textPrimary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton(double finalTotal) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: _surfaceColor,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedPayment == 'online')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 12,
                    color: _textMuted.withOpacity(0.6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Secured by Razorpay',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: _textMuted.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isLoading = true;
                        _showPaymentLoading = true;
                        _loadingMessage = 'Starting...';
                      });
                      _placeOrder();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _selectedPayment == 'online'
                          ? 'Pay ₹${_getRoundedTotal(finalTotal).toStringAsFixed(0)} Online →'
                          : 'Place Order — ₹${_getRoundedTotal(finalTotal).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
