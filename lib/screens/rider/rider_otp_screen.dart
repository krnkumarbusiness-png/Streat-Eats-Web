import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../models/order_model.dart';
import '../../services/rider_service.dart';
import '../../services/push_notification_sender.dart';
import 'rider_dashboard_screen.dart';

class RiderOtpScreen extends StatefulWidget {
  final OrderModel order;
  const RiderOtpScreen({super.key, required this.order});

  @override
  State<RiderOtpScreen> createState() => _RiderOtpScreenState();
}

class _RiderOtpScreenState extends State<RiderOtpScreen> {
  final _riderService = RiderService();
  final _supabase = Supabase.instance.client;
  final _audioPlayer = AudioPlayer();

  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isError = false;
  String _errorMsg = '';

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text.trim()).join();

  Future<void> _verifYOtp() async {
    final entered = _enteredOtp;
    if (entered.length < 4) {
      setState(() {
        _isError = true;
        _errorMsg = 'Poora 4-digit OTP daalo';
      });
      return;
    }
    setState(() {
      _isVerifying = true;
      _isError = false;
    });

    // ✅ Method level pe declare karo — _showSuccessDialog ko pass karna hai
    double actualDeliveryCharge = 0;
    int actualTip = 0;

    try {
      final response = await _supabase
          .from('orders')
          .select('delivery_otp, status')
          .eq('id', widget.order.id)
          .single();

      final rawOtp = response['delivery_otp'];
      if (rawOtp == null) {
        setState(() {
          _isError = true;
          _errorMsg = 'OTP nahi mila. Admin se contact karo.';
          _isVerifying = false;
        });
        return;
      }

      final String savedOtp = rawOtp.toString().trim();
      final String inputOtp = entered.trim();

      if (savedOtp != inputOtp) {
        setState(() {
          _isError = true;
          _errorMsg = 'Galat OTP! Customer se dobara poocho.';
          _isVerifying = false;
        });
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        HapticFeedback.vibrate();
        return;
      }

      // ✅ OTP sahi — delivered mark karo
      await _supabase
          .from('orders')
          .update({
            'status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.order.id);

      // ✅ Cash register sound
      await _audioPlayer.play(AssetSource('sounds/cash_register.mp3'));

      // ✅ Customer ko delivery notification
      await PushNotificationSender.orderDeliveredToCustomer(
        customerId: widget.order.userId,
        vendorName: widget.order.vendorName,
      );

      // ✅ Earning record — delivery_charge + tip dynamically fetch karo
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Order se actual delivery charge aur tip fetch karo
        try {
          final orderData = await _supabase
              .from('orders')
              .select('delivery_charge, tip_amount')
              .eq('id', widget.order.id)
              .maybeSingle();
          actualDeliveryCharge =
              (orderData?['delivery_charge'] as num?)?.toDouble() ?? 0.0;
          actualTip = (orderData?['tip_amount'] as num?)?.toInt() ?? 0;
        } catch (_) {}

        await _supabase.from('rider_earnings').insert({
          'rider_id': userId,
          'order_id': widget.order.id,
          'amount': actualDeliveryCharge,
          'tip_amount': actualTip,
          'is_paid': false,
          'earned_at': DateTime.now().toIso8601String(),
        });
        try {
          final riderData = await _supabase
              .from('riders')
              .select('total_earnings')
              .eq('id', userId)
              .maybeSingle();
          final currentEarnings =
              (riderData?['total_earnings'] as num?)?.toDouble() ?? 0.0;
          await _supabase
              .from('riders')
              .update({
                'total_earnings':
                    currentEarnings + actualDeliveryCharge + actualTip,
              })
              .eq('id', userId);
        } catch (_) {}
      }

      if (!mounted) return;
      _showSuccessDialog(earned: actualDeliveryCharge + actualTip);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _errorMsg = 'Error: ${e.toString()}';
        _isVerifying = false;
      });
    }
  }

  void _showSuccessDialog({double earned = 0}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              const Text(
                'Delivery Complete!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '₹${earned.toStringAsFixed(0)} add ho gaya!\nSunday ko UPI pe milega.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Text(
                  '+₹${earned.toStringAsFixed(0)} Earned 💰',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderDashboardScreen(),
                    ),
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Dashboard Pe Jao',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Poppins',
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

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 3) _focusNodes[index + 1].requestFocus();
      if (index == 3) FocusScope.of(context).unfocus();
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
    if (_isError) setState(() => _isError = false);
  }

  @override
  Widget build(BuildContext context) {
    final shortId = widget.order.id
        .substring(widget.order.id.length - 6)
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delivery OTP',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text('🔐', style: TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Delivery OTP Daalo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Customer se 4-digit OTP lo aur\nyahan enter karo delivery confirm karne ke liye',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
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
                    const Text('🛍️', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.order.vendorName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Order #$shortId  •  ₹${widget.order.total.toStringAsFixed(0)} cash',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.order.tipAmount > 0
                          ? '₹${widget.order.deliveryCharge.toStringAsFixed(0)}+₹${widget.order.tipAmount}tip'
                          : '₹${widget.order.deliveryCharge.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 64,
                    height: 68,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isError
                            ? AppColors.error
                            : _controllers[index].text.isNotEmpty
                            ? AppColors.primary
                            : AppColors.border,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => _onOtpChanged(value, index),
                    ),
                  );
                }),
              ),
              if (_isError) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _errorMsg,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifYOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    disabledBackgroundColor: AppColors.success.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Confirm Delivery ✅',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '⚠️ OTP sirf customer ke phone pe hai.\nBina OTP ke delivery confirm nahi hogi.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
