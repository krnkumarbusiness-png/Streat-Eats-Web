import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../constants/colors.dart';
import '../models/order_model.dart';
import 'home_screen.dart';
import 'order_status_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final OrderModel order;
  final List<OrderModel> allOrders;
  const OrderConfirmationScreen({
    super.key,
    required this.order,
    this.allOrders = const [],
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _playSuccessSound();
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/order_success.mp3'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getPaymentLabel() {
    return widget.order.paymentMethod == 'online'
        ? 'Paid Online ✓'
        : 'Cash on Delivery';
  }

  Color _getPaymentColor() {
    return widget.order.paymentMethod == 'online'
        ? AppColors.success
        : AppColors.warning;
  }

  IconData _getPaymentIcon() {
    return widget.order.paymentMethod == 'online'
        ? Icons.smartphone_rounded
        : Icons.money_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final shortId = order.id.substring(order.id.length - 8).toUpperCase();
    final paymentColor = _getPaymentColor();
    final bool isFreeDelivery = order.deliveryCharge == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable Content ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                child: Column(
                  children: [
                    // Animated Illustration
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Image.asset(
                          'assets/images/illus_order_success.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Title
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: const Column(
                        children: [
                          Text(
                            'Order Placed! 🎉',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your order has been placed successfully',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Order Summary Card
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _summaryRow(
                              label: 'Order ID',
                              value: '#$shortId',
                              valueColor: AppColors.primary,
                              bold: true,
                            ),
                            _divider(),
                            _summaryRow(
                              label: 'Vendor',
                              value: order.vendorName,
                              bold: true,
                            ),
                            _divider(),
                            _summaryRow(
                              label: 'Subtotal',
                              value: '₹${order.subtotal.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 4),
                            _summaryRow(
                              label: 'Delivery',
                              value: isFreeDelivery
                                  ? 'FREE'
                                  : '₹${order.deliveryCharge.toStringAsFixed(2)}',
                              valueColor: isFreeDelivery
                                  ? AppColors.success
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            _summaryRow(
                              label: 'Platform Fee',
                              value: '₹${order.platformFee.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 4),
                            _summaryRow(
                              label: 'Packaging Fee',
                              value:
                                  '₹${order.packagingFee.toStringAsFixed(2)}',
                            ),
                            _divider(),
                            _summaryRow(
                              label: 'Total Amount',
                              value: '₹${order.total.toStringAsFixed(2)}',
                              valueColor: AppColors.primary,
                              bold: true,
                              large: true,
                            ),
                            _divider(),

                            // Payment Method
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Payment',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: paymentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: paymentColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getPaymentIcon(),
                                        color: paymentColor,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _getPaymentLabel(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: paymentColor,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            _divider(),
                            _summaryRow(
                              label: 'Est. Time',
                              value: '25–30 minutes',
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Info Banner
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.15),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your rider will call before delivery',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Delivery OTPs — shown when multiple vendors
                    if (widget.allOrders.length > 1) ...[
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery OTPs 🔐',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Each vendor has a separate OTP — share with the rider',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...widget.allOrders.map(
                                (o) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.store_rounded,
                                        color: AppColors.primary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          o.vendorName,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(
                                            0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          o.deliveryOtp ?? '----',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                            letterSpacing: 3,
                                          ),
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
                    ],
                  ],
                ),
              ),
            ),

            // ── Sticky Buttons ──────────────────────────────
            FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderStatusScreen(orderId: order.id),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Track Order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Back to Home',
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
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    Color? valueColor,
    bool bold = false,
    bool large = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: large ? 14 : 13,
              color: AppColors.textMuted,
              fontFamily: 'Poppins',
              fontWeight: large ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 17 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    height: 1,
    color: AppColors.border,
    margin: const EdgeInsets.symmetric(vertical: 2),
  );
}
