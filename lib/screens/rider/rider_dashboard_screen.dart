// lib/screens/rider/rider_dashboard_screen.dart
// Streat Eats — Rider Dashboard
// FIX 1: initState mein NotificationService.onNewOrderForRider callback register
// FIX 2: dispose mein callback unregister — memory leak se bachao

import 'dart:async';
import 'dart:math' show sin;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../models/order_model.dart';
import '../../providers/rider_provider.dart';
import '../../services/rider_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/push_notification_sender.dart';
import '../login_screen.dart';
import 'rider_order_detail_screen.dart';
import 'rider_earnings_screen.dart';
import 'rider_order_history_screen.dart';
import 'rider_profile_screen.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  final _authService = AuthService();
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiderProvider>().fetchRiderProfile();
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _AvailableOrdersTab(),
          RiderEarningsScreen(),
          RiderProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _navItem(0, Icons.delivery_dining_rounded, 'Orders'),
              _navItem(1, Icons.account_balance_wallet_outlined, 'Earnings'),
              _navItem(2, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AVAILABLE ORDERS TAB
// ═══════════════════════════════════════════════════════════
class _AvailableOrdersTab extends StatefulWidget {
  const _AvailableOrdersTab();

  @override
  State<_AvailableOrdersTab> createState() => _AvailableOrdersTabState();
}

class _AvailableOrdersTabState extends State<_AvailableOrdersTab> {
  final _riderService = RiderService();
  final _supabase = Supabase.instance.client;

  final _loopPlayer = AudioPlayer();
  final _acceptPlayer = AudioPlayer();

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _pollingTimer;

  bool _isLoopPlaying = false;
  Set<String> _knownOrderIds = {};
  final Set<String> _locallyRejectedIds = {};

  double _todayEarnings = 0;
  int _todayOrders = 0;
  bool _isTogglingDuty = false;

  static const double _dailyGoal = 300.0;

  @override
  void initState() {
    super.initState();
    _loopPlayer.setReleaseMode(ReleaseMode.loop);
    _fetchOrders();
    _fetchTodayEarnings();
    _startPolling();

    // ── FIX: FCM se order aaye toh dashboard refresh ho ──────────
    // App foreground mein ho ya background se aaye — dono cases handle
    NotificationService.onNewOrderForRider = () {
      if (mounted) {
        _fetchOrders(showLoader: false);
        _checkAdminAssignedOrder(); // ✅ Admin assigned order check
        HapticFeedback.heavyImpact();
      }
    };
  }

  // ── EXISTING _fetchOrders() ke end mein yeh add karo ──────
  // Admin se assigned order check karo — agar rider_id match kare
  // toh RiderOrderDetailScreen pe navigate karo
  Future<void> _checkAdminAssignedOrder() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('orders')
          .select()
          .eq('rider_id', userId)
          .eq('status', 'placed') // placed status mein assigned
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        final orderId = data['id'] as String;
        // Pehle se navigate nahi ho raha toh hi navigate karo
        _pollingTimer?.cancel();
        _stopNewOrderSound();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiderOrderDetailScreen(orderId: orderId),
          ),
        ).then((_) {
          _fetchOrders();
          _fetchTodayEarnings();
          _startPolling();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _loopPlayer.dispose();
    _acceptPlayer.dispose();
    // ── FIX: Memory leak se bachao — callback unregister karo ────
    NotificationService.onNewOrderForRider = null;
    super.dispose();
  }

  // ── Today's earnings fetch ────────────────────────────────
  Future<void> _fetchTodayEarnings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now();
      final todayStart = DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String();
      final todayEnd = DateTime(
        today.year,
        today.month,
        today.day,
        23,
        59,
        59,
      ).toIso8601String();

      final data = await _supabase
          .from('rider_earnings')
          .select('amount, tip_amount')
          .eq('rider_id', userId)
          .gte('earned_at', todayStart)
          .lte('earned_at', todayEnd);

      if (!mounted) return;
      final list = data as List;
      setState(() {
        _todayOrders = list.length;
        _todayEarnings = list.fold(
          0.0,
          (sum, e) =>
              sum +
              ((e['amount'] as num?)?.toDouble() ?? 0) +
              ((e['tip_amount'] as num?)?.toDouble() ?? 0),
        );
      });
    } catch (_) {}
  }

  // ── Duty toggle ───────────────────────────────────────────
  Future<void> _toggleDuty(bool newValue) async {
    if (_isTogglingDuty) return;
    setState(() => _isTogglingDuty = true);
    HapticFeedback.mediumImpact();
    try {
      await _riderService.toggleAvailability(newValue);
      await context.read<RiderProvider>().fetchRiderProfile();
      if (!newValue) _stopNewOrderSound();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Duty toggle failed. Try again.',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingDuty = false);
    }
  }

  Future<void> _startNewOrderSound() async {
    if (_isLoopPlaying) return;
    _isLoopPlaying = true;
    try {
      await _loopPlayer.play(AssetSource('sounds/new_order.mp3'));
    } catch (_) {}
  }

  Future<void> _stopNewOrderSound() async {
    if (!_isLoopPlaying) return;
    _isLoopPlaying = false;
    try {
      await _loopPlayer.stop();
    } catch (_) {}
  }

  Future<void> _playAcceptSound() async {
    try {
      await _acceptPlayer.play(AssetSource('sounds/order_accept.mp3'));
    } catch (_) {}
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchOrders(),
    );
  }

  Future<void> _fetchOrders({bool showLoader = false}) async {
    if (showLoader) setState(() => _isLoading = true);
    try {
      final orders = await _riderService.getAvailableOrders();
      if (mounted) {
        final filteredOrders = orders
            .where((o) => !_locallyRejectedIds.contains(o.id))
            .toList();
        final newIds = filteredOrders.map((o) => o.id).toSet();
        final hasNewOrders =
            newIds.difference(_knownOrderIds).isNotEmpty &&
            _knownOrderIds.isNotEmpty;

        // ✅ FIX: Sirf tab sound bajao jab rider ONLINE ho
        final rider = context.mounted
            ? Provider.of<RiderProvider>(context, listen: false).rider
            : null;
        final isOnline = rider?.isAvailable ?? false;

        if (filteredOrders.isNotEmpty && isOnline) {
          if (hasNewOrders || (!_isLoopPlaying && filteredOrders.isNotEmpty)) {
            _startNewOrderSound();
            HapticFeedback.heavyImpact();
          }
        } else {
          _stopNewOrderSound();
        }

        _knownOrderIds = newIds;
        setState(() {
          _orders = filteredOrders;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // ── Accept Order ──────────────────────────────────────────
  Future<void> _acceptOrder(OrderModel order) async {
    _pollingTimer?.cancel();
    _stopNewOrderSound();
    setState(() => _orders.removeWhere((o) => o.id == order.id));
    try {
      await _riderService.acceptOrder(order.id);
      await _playAcceptSound();

      String riderName = 'Your Rider';
      try {
        final riderId = _supabase.auth.currentUser?.id;
        if (riderId != null) {
          final riderData = await _supabase
              .from('riders')
              .select('full_name')
              .eq('id', riderId)
              .maybeSingle();
          riderName = riderData?['full_name'] as String? ?? 'Your Rider';
        }
      } catch (_) {}

      final shortId = order.id.substring(order.id.length - 6).toUpperCase();
      await PushNotificationSender.orderAcceptedToCustomer(
        customerId: order.userId,
        riderName: riderName,
        orderShortId: shortId,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderOrderDetailScreen(orderId: order.id),
        ),
      ).then((_) {
        _fetchOrders();
        _fetchTodayEarnings();
        _startPolling();
      });
    } catch (e) {
      if (mounted) setState(() => _orders.insert(0, order));
      _startPolling();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ── Reject Order ──────────────────────────────────────────
  Future<void> _rejectOrder(OrderModel order) async {
    _pollingTimer?.cancel();
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Reject Order?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give a reason — customer will be notified.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Area is too far, vehicle issue...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final text = reasonController.text.trim();
              Navigator.pop(
                ctx,
                text.isEmpty ? 'Rider not available right now' : text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Reject & Notify',
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

    if (reason == null) {
      _startPolling();
      return;
    }

    _locallyRejectedIds.add(order.id);
    setState(() => _orders.removeWhere((o) => o.id == order.id));
    if (_orders.isEmpty) _stopNewOrderSound();

    try {
      await _riderService.rejectOrder(order.id, reason: reason);
      try {
        final shortId = order.id.substring(order.id.length - 6).toUpperCase();
        await PushNotificationSender.orderRejectedToCustomer(
          customerId: order.userId,
          reason: reason,
          orderShortId: shortId,
        );
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Order rejected — customer notified',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      _locallyRejectedIds.remove(order.id);
      if (mounted) {
        setState(() => _orders.insert(0, order));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      _startPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RiderProvider>(
      builder: (context, riderProvider, _) {
        final rider = riderProvider.rider;
        final isOnline = rider?.isAvailable ?? false;

        return SafeArea(
          child: Column(
            children: [
              _buildDutyHeader(rider?.fullName ?? 'Rider', isOnline),
              _buildTodayGoalCard(isOnline),
              Expanded(
                child: !isOnline
                    ? _buildOfflineState()
                    : _isLoading
                    ? _buildLoadingState()
                    : _hasError
                    ? _buildErrorState()
                    : _orders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onRefresh: () => _fetchOrders(showLoader: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _orders.length,
                          itemBuilder: (_, i) => _OrderCard(
                            order: _orders[i],
                            onAccept: () => _acceptOrder(_orders[i]),
                            onReject: () => _rejectOrder(_orders[i]),
                            onTimerExpire: () {
                              _locallyRejectedIds.add(_orders[i].id);
                              setState(
                                () => _orders.removeWhere(
                                  (o) => o.id == _orders[i].id,
                                ),
                              );
                              if (_orders.isEmpty) _stopNewOrderSound();
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Duty Toggle Header ────────────────────────────────────
  Widget _buildDutyHeader(String riderName, bool isOnline) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.textMuted.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: isOnline
                    ? AppColors.success.withOpacity(0.35)
                    : AppColors.border,
                width: 2,
              ),
            ),
            child: const Center(
              child: Text('🛵', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey, ${riderName.split(' ').first} 👋',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? AppColors.success
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnline ? 'Online — Accepting Orders' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOnline
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RiderOrderHistoryScreen(),
              ),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isTogglingDuty ? null : () => _toggleDuty(!isOnline),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 64,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success : AppColors.border,
                borderRadius: BorderRadius.circular(17),
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: isOnline ? 0 : 14,
                          right: isOnline ? 14 : 0,
                        ),
                        child: Text(
                          isOnline ? 'ON' : 'OFF',
                          style: TextStyle(
                            color: isOnline
                                ? Colors.white
                                : AppColors.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Poppins',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    left: isOnline ? 30 : 0,
                    top: 0,
                    child: _isTogglingDuty
                        ? Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isOnline
                                    ? Icons.power_rounded
                                    : Icons.power_off_rounded,
                                size: 14,
                                color: isOnline
                                    ? AppColors.success
                                    : AppColors.textMuted,
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
    );
  }

  // ── Today's Goal Card ─────────────────────────────────────
  Widget _buildTodayGoalCard(bool isOnline) {
    final progress = (_todayEarnings / _dailyGoal).clamp(0.0, 1.0);
    final remaining = (_dailyGoal - _todayEarnings).clamp(0, _dailyGoal);
    final isGoalReached = _todayEarnings >= _dailyGoal;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoalReached
              ? [
                  AppColors.success.withOpacity(0.12),
                  AppColors.success.withOpacity(0.06),
                ]
              : [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.primary.withOpacity(0.03),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGoalReached
              ? AppColors.success.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildGoalStat(
                  emoji: '🛵',
                  label: "Today's Orders",
                  value: '$_todayOrders',
                  color: AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _buildGoalStat(
                  emoji: '💰',
                  label: "Today's Earned",
                  value: '₹${_todayEarnings.toStringAsFixed(0)}',
                  color: AppColors.success,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _buildGoalStat(
                  emoji: isGoalReached ? '🏆' : '🎯',
                  label: 'Daily Goal',
                  value: '₹${_dailyGoal.toStringAsFixed(0)}',
                  color: isGoalReached ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isGoalReached ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isGoalReached
                          ? '🎉 Daily goal reached! Keep going!'
                          : '₹${remaining.toStringAsFixed(0)} more to reach your daily goal',
                      style: TextStyle(
                        fontSize: 10,
                        color: isGoalReached
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isGoalReached ? AppColors.success : AppColors.primary,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          if (!isOnline) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 13,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Go Online to start receiving orders',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.warning,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildGoalStat({
    required String emoji,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // ── State Widgets ─────────────────────────────────────────
  Widget _buildOfflineState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('😴', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'You Are Offline',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toggle the switch above to go Online\nand start receiving orders.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontFamily: 'Poppins',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildLoadingState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text(
          'Looking for orders...',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: const Center(
            child: Text('🛵', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'No Orders Right Now',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'New orders will appear here!\nStay active after 5 PM.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontFamily: 'Poppins',
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Auto-refreshing every 5 seconds',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildErrorState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.error,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Connection Error',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check your internet connection',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _fetchOrders(showLoader: true),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text(
            'Try Again',
            style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// ORDER CARD — 30 second countdown timer
// ═══════════════════════════════════════════════════════════
class _OrderCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTimerExpire;

  const _OrderCard({
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onTimerExpire,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
    with SingleTickerProviderStateMixin {
  bool _isAccepting = false;
  Timer? _shakeTimer;
  Timer? _countdownTimer;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  int _secondsLeft = 60;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
    _shakeController.forward().then((_) => _shakeController.reset());
    _shakeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _shakeController.forward().then((_) => _shakeController.reset());
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0 && !_isExpired) {
          _isExpired = true;
          _countdownTimer?.cancel();
          widget.onTimerExpire();
        }
      });
    });
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _countdownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isAccepting || _isExpired) return;
    _countdownTimer?.cancel();
    setState(() => _isAccepting = true);
    widget.onAccept();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isAccepting = false);
  }

  Color get _timerColor {
    if (_secondsLeft > 20) return AppColors.success;
    if (_secondsLeft > 10) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final itemCount = order.items.length;
    final shortId = order.id.substring(order.id.length - 6).toUpperCase();
    final isCod = order.paymentMethod != 'online';
    final timerProgress = _secondsLeft / 60.0;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final shake = sin(_shakeAnim.value * 3 * 3.14159) * 4;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Orange alert top bar ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'New Order! Accept quickly 🔥',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_secondsLeft}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Timer progress bar
            ClipRRect(
              child: LinearProgressIndicator(
                value: timerProgress,
                minHeight: 4,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
              ),
            ),

            // ── Order details ─────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$shortId',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        '₹${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationChip(
                          icon: Icons.store_rounded,
                          label: 'Pickup',
                          value: order.vendorName,
                          color: AppColors.warning,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                      ),
                      Expanded(
                        child: _buildLocationChip(
                          icon: Icons.location_on_rounded,
                          label: 'Delivery',
                          value: order.address,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.shopping_bag_outlined,
                        label: '$itemCount item${itemCount > 1 ? 's' : ''}',
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: isCod
                            ? Icons.money_rounded
                            : Icons.verified_rounded,
                        label: isCod
                            ? 'Collect ₹${order.total.toStringAsFixed(0)}'
                            : 'Prepaid ✓',
                        isHighlight: isCod,
                        highlightColor: isCod
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: Icons.two_wheeler_rounded,
                        label: order.tipAmount > 0
                            ? '₹${order.deliveryCharge.toStringAsFixed(0)} + ₹${order.tipAmount} tip'
                            : '₹${order.deliveryCharge.toStringAsFixed(0)} earn',
                        isHighlight: true,
                      ),
                    ],
                  ),
                  if (order.landmark.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Near: ${order.landmark}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // ── Accept + Reject buttons ───────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: widget.onReject,
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.error,
                          size: 16,
                        ),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_isAccepting || _isExpired)
                            ? null
                            : _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary
                              .withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isAccepting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Accept ✅',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                      ),
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

  Widget _buildLocationChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    final activeColor = highlightColor ?? AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: isHighlight
            ? activeColor.withOpacity(0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isHighlight ? activeColor.withOpacity(0.25) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isHighlight ? activeColor : AppColors.textMuted,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Poppins',
              color: isHighlight ? activeColor : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
