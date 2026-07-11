import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/order_model.dart';
import 'home_screen.dart';
import '../constants/app_snackbar.dart';
import '../constants/eta_helper.dart';

// ══════════════════════════════════════════════════════════════
//  ORDER STATUS SCREEN
//  - Fake SVG map with real vendor + user coordinates
//  - Rider PNG animates along path based on order status
//  - Supabase polling every 5s — scooter position auto-updates
//  - Cancel window countdown (2 min)
//  - OTP card on on_the_way status
// ══════════════════════════════════════════════════════════════

class OrderStatusScreen extends StatefulWidget {
  final String orderId;
  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final _supabase = Supabase.instance.client;
  final _audioPlayer = AudioPlayer();

  OrderModel? _order;
  Timer? _pollingTimer; // deprecated
  RealtimeChannel? _realtimeChannel;
  Timer? _cancelTimer;
  bool _isFirstLoad = true;
  bool _orderPlacedSoundPlayed = false;
  bool _isCancelling = false;

  // Vendor location (from vendors table)
  double? _vendorLat;
  double? _vendorLng;
  String _vendorArea = '';
  bool _vendorLoaded = false;

  // User location (from geolocator or stored coords)
  double? _userLat;
  double? _userLng;

  // Distance
  double? _distanceKm;

  // Cancel window
  Duration _cancelTimeLeft = Duration.zero;
  bool _canCancel = false;
  static const _cancelWindowSeconds = 120;

  final List<Map<String, String>> _steps = [
    {
      'status': 'placed',
      'label': 'Order Placed',
      'sublabel': 'Order received!',
      'icon': '📋',
    },
    {
      'status': 'accepted',
      'label': 'Rider Assigned',
      'sublabel': 'Rider is heading to vendor!',
      'icon': '🤝',
    },
    {
      'status': 'preparing',
      'label': 'At Vendor',
      'sublabel': 'Rider reached, food being prepared!',
      'icon': '🏪',
    },
    {
      'status': 'picked_up',
      'label': 'Picked Up',
      'sublabel': 'Rider picked up!',
      'icon': '🛵',
    },
    {
      'status': 'on_the_way',
      'label': 'On the Way',
      'sublabel': 'Rider is on the way!',
      'icon': '📍',
    },
    {
      'status': 'delivered',
      'label': 'Delivered!',
      'sublabel': 'Enjoy your food!',
      'icon': '✅',
    },
  ];

  @override
  void initState() {
    super.initState();

    _loadOrder();
    _realtimeChannel = Supabase.instance.client
        .channel('order-status-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) {
            if (mounted) _loadOrder(silent: true);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _cancelTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Load Order ──────────────────────────────────────────────

  Future<void> _loadOrder({bool silent = false}) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .maybeSingle();

      if (response != null && mounted) {
        final order = OrderModel.fromMap(response);
        setState(() {
          _order = order;
          _isFirstLoad = false;
        });

        if (!_orderPlacedSoundPlayed) _playSound();

        // Load vendor location once
        if (!_vendorLoaded && order.vendorId.isNotEmpty) {
          _loadVendorLocation(order.vendorId, order.orderType);
        }

        // Load user location once
        if (_userLat == null) _loadUserLocation();

        // Cancel timer
        if (order.status == 'placed') {
          final placedAt = response['order_placed_at'] != null
              ? DateTime.tryParse(response['order_placed_at'] as String)
              : null;
          if (placedAt != null && _cancelTimer == null) {
            _startCancelCountdown(placedAt);
          }
        } else {
          _cancelTimer?.cancel();
          if (mounted) setState(() => _canCancel = false);
        }
      } else if (mounted) {
        setState(() => _isFirstLoad = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  Future<void> _loadVendorLocation(String vendorId, String orderType) async {
    try {
      final table = orderType == 'sweets' ? 'sweet_vendors' : 'vendors';
      final data = await _supabase
          .from(table)
          .select('latitude, longitude, area')
          .eq('id', vendorId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _vendorLat = (data['latitude'] as num?)?.toDouble();
          _vendorLng = (data['longitude'] as num?)?.toDouble();
          _vendorArea = data['area'] as String? ?? '';
          _vendorLoaded = true;
        });
        _calculateDistance();
      }
    } catch (_) {
      if (mounted) setState(() => _vendorLoaded = true);
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      // Try device GPS first
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 5));
        if (mounted) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          });
          _calculateDistance();
        }
        return;
      }
      // Fallback: Haldwani city center
      if (mounted) {
        setState(() {
          _userLat = 29.2183;
          _userLng = 79.5130;
        });
        _calculateDistance();
      }
    } catch (_) {
      // Fallback
      if (mounted) {
        setState(() {
          _userLat = 29.2183;
          _userLng = 79.5130;
        });
        _calculateDistance();
      }
    }
  }

  void _calculateDistance() {
    if (_vendorLat == null ||
        _vendorLng == null ||
        _userLat == null ||
        _userLng == null) {
      return;
    }
    final meters = Geolocator.distanceBetween(
      _vendorLat!,
      _vendorLng!,
      _userLat!,
      _userLng!,
    );
    if (mounted) setState(() => _distanceKm = meters / 1000);
  }

  // ── Cancel Window ───────────────────────────────────────────

  void _startCancelCountdown(DateTime orderPlacedAt) {
    _cancelTimer?.cancel();
    final now = DateTime.now();
    final elapsed = now.difference(orderPlacedAt).inSeconds;
    final remaining = _cancelWindowSeconds - elapsed;

    if (remaining <= 0) {
      setState(() {
        _canCancel = false;
        _cancelTimeLeft = Duration.zero;
      });
      return;
    }

    setState(() {
      _canCancel = true;
      _cancelTimeLeft = Duration(seconds: remaining);
    });

    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final secs = _cancelTimeLeft.inSeconds - 1;
      if (secs <= 0) {
        _cancelTimer?.cancel();
        setState(() {
          _canCancel = false;
          _cancelTimeLeft = Duration.zero;
        });
      } else {
        setState(() => _cancelTimeLeft = Duration(seconds: secs));
      }
    });
  }

  Future<void> _cancelOrder() async {
    if (!_canCancel || _isCancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Order?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          '${_cancelTimeLeft.inSeconds} seconds left to cancel.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep Order',
              style: TextStyle(
                color: AppColors.primary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
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
              'Cancel Order',
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
    setState(() => _isCancelling = true);
    try {
      await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', widget.orderId);
      _cancelTimer?.cancel();
      setState(() {
        _canCancel = false;
        _isCancelling = false;
      });
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'Order cancelled');
      await _loadOrder();
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        AppSnackBar.showError(context, 'Cancel failed: ${e.toString()}');
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────

  Future<void> _playSound() async {
    _orderPlacedSoundPlayed = true;
    try {
      await _audioPlayer.play(AssetSource('sounds/order_placed.mp3'));
    } catch (_) {}
  }

  int _getStatusIndex(String status) {
    final idx = _steps.indexWhere((s) => s['status'] == status);
    return idx == -1 ? 0 : idx;
  }

  String _getEta() => EtaHelper.getEta(distanceKm: _distanceKm);
  Future<void> _callRider(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      AppSnackBar.showError(context, 'Rider number not available yet');
      return;
    }
    final uri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isFirstLoad
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _order == null
          ? _buildErrorState()
          : _buildBody(_order!),
    );
  }

  Widget _buildBody(OrderModel order) {
    final statusIdx = _getStatusIndex(order.status);
    final isDelivered = order.status == 'delivered';
    final isCancelled = order.status == 'cancelled';
    final isRejected = order.status == 'rejected';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ARRIVING TIMER CARD ─────────────────────────────
          _buildArrivingCard(order),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(
                  order,
                  statusIdx,
                  isDelivered,
                  isCancelled,
                  isRejected,
                ),
                const SizedBox(height: 12),

                // Rider card (show when rider assigned)
                if (order.riderName != null &&
                    order.riderName!.isNotEmpty &&
                    !isDelivered &&
                    !isCancelled &&
                    !isRejected) ...[
                  _buildRiderCard(order.riderName!, order.riderPhone),
                  const SizedBox(height: 12),
                ],

                // Cancel window
                if (_canCancel && order.status == 'placed') ...[
                  _buildCancelWindowCard(),
                  const SizedBox(height: 12),
                ],

                // Timeline
                if (!isCancelled && !isRejected) ...[
                  _buildTimeline(statusIdx),
                  const SizedBox(height: 12),
                ],

                // OTP card
                if (order.status == 'on_the_way' &&
                    order.deliveryOtp != null) ...[
                  _buildOtpCard(order.deliveryOtp!),
                  const SizedBox(height: 12),
                ],

                _buildOrderSummary(order),
                const SizedBox(height: 12),
                _buildAddressCard(order),
                const SizedBox(height: 24),

                if (isDelivered || isCancelled || isRejected)
                  _buildHomeButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Order Status',
            style: AppStyles.screenTitle.copyWith(fontSize: 17),
          ),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  // ── Status Banner ───────────────────────────────────────────

  Widget _buildStatusBanner(
    OrderModel order,
    int statusIdx,
    bool isDelivered,
    bool isCancelled,
    bool isRejected,
  ) {
    final shortId = order.id.substring(order.id.length - 6).toUpperCase();
    Color bannerColor;
    IconData bannerIcon;
    String bannerTitle;
    String bannerSub;

    if (isCancelled) {
      bannerColor = AppColors.error;
      bannerIcon = Icons.cancel_outlined;
      bannerTitle = 'Order Cancelled';
      bannerSub = 'Your order has been cancelled';
    } else if (isRejected) {
      bannerColor = AppColors.error;
      bannerIcon = Icons.do_not_disturb_alt_rounded;
      bannerTitle = 'Order Rejected';
      bannerSub = 'Rider rejected. Please place a new order.';
    } else if (isDelivered) {
      bannerColor = AppColors.success;
      bannerIcon = Icons.check_circle_outline_rounded;
      bannerTitle = 'Delivered! 🎉';
      bannerSub = 'Enjoy your food! Don\'t forget to rate ⭐';
    } else {
      bannerColor = AppColors.primary;
      bannerIcon = Icons.access_time_rounded;
      bannerTitle = _steps[statusIdx]['label']!;
      bannerSub = _steps[statusIdx]['sublabel']!;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(bannerIcon, color: bannerColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: AppStyles.sectionHeader.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  bannerSub,
                  style: AppStyles.bodyText.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  'Order #$shortId',
                  style: AppStyles.labelText.copyWith(
                    color: bannerColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Arriving Timer Card ─────────────────────────────────────

  Widget _buildArrivingCard(OrderModel order) {
    final isDelivered = order.status == 'delivered';
    final isCancelled = order.status == 'cancelled';
    final isRejected = order.status == 'rejected';

    // Delivered/cancelled/rejected hote hi ye card gayab ho jayega
    if (isDelivered || isCancelled || isRejected) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2E2620),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'ARRIVING IN',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEta(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusSubtext(order.status),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusSubtext(String status) {
    switch (status) {
      case 'placed':
        return 'Order received, assigning a rider';
      case 'accepted':
        return 'Rider is heading to the vendor';
      case 'preparing':
        return 'Rider is preparing to pick up';
      case 'picked_up':
        return 'Rider picked up your order';
      case 'on_the_way':
        return 'Rider is on the way to you';
      default:
        return 'Processing your order';
    }
  }

  // ── Rider Card ──────────────────────────────────────────────

  Widget _buildRiderCard(String riderName, String? riderPhone) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rider avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderName,
                  style: AppStyles.cardTitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '4.9 · Your Delivery Partner',
                      style: AppStyles.bodyText.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Call button
          GestureDetector(
            onTap: () => _callRider(riderPhone),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: riderPhone != null && riderPhone.isNotEmpty
                    ? AppColors.success
                    : AppColors.border,
                shape: BoxShape.circle,
                boxShadow: riderPhone != null && riderPhone.isNotEmpty
                    ? [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                Icons.call_rounded,
                color: riderPhone != null && riderPhone.isNotEmpty
                    ? Colors.white
                    : AppColors.textMuted,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cancel Window Card ──────────────────────────────────────

  Widget _buildCancelWindowCard() {
    final secs = _cancelTimeLeft.inSeconds;
    final mins = secs ~/ 60;
    final remSecs = secs % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')}';
    final isUrgent = secs < 30;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.error.withOpacity(0.06)
            : AppColors.warning.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? AppColors.error.withOpacity(0.3)
              : AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUrgent
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isUrgent ? AppColors.error : AppColors.warning,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'remaining',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    color: isUrgent ? AppColors.error : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancel Window Open',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isUrgent ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'You cannot cancel after this!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _isCancelling ? null : _cancelOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              disabledBackgroundColor: AppColors.error.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: _isCancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Timeline ────────────────────────────────────────────────

  Widget _buildTimeline(int currentIdx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Journey',
            style: AppStyles.sectionHeader.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),
          ...List.generate(_steps.length, (i) {
            final isDone = i < currentIdx;
            final isActive = i == currentIdx;
            final isLast = i == _steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.success
                            : isActive
                            ? AppColors.primary
                            : AppColors.border.withOpacity(0.4),
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : Text(
                                _steps[i]['icon']!,
                                style: TextStyle(fontSize: isActive ? 14 : 11),
                              ),
                      ),
                    ),
                    if (!isLast)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 2,
                        height: 28,
                        color: i < currentIdx
                            ? AppColors.success
                            : AppColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[i]['label']!,
                          style: AppStyles.cardTitle.copyWith(
                            fontSize: 13,
                            color: isDone || isActive
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _steps[i]['sublabel']!,
                          style: AppStyles.bodyText.copyWith(
                            fontSize: 11,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Current Status',
                                style: AppStyles.labelText.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── OTP Card ────────────────────────────────────────────────

  Widget _buildOtpCard(String otp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Delivery OTP',
                style: AppStyles.sectionHeader.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share this OTP with your rider to confirm delivery',
            style: AppStyles.bodyText.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: otp.split('').map((digit) {
              return Container(
                width: 52,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: otp));
              AppSnackBar.showSuccess(context, 'OTP copied');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.copy_rounded,
                    color: AppColors.primary,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Copy OTP',
                    style: AppStyles.labelText.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
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

  // ── Order Summary ───────────────────────────────────────────

  Widget _buildOrderSummary(OrderModel order) {
    final isFreeDelivery = order.deliveryCharge == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: AppColors.primary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                order.vendorName,
                style: AppStyles.sectionHeader.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: AppStyles.bodyText.copyWith(fontSize: 12),
                    ),
                  ),
                  Text(
                    '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: AppStyles.bodyText.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 18),
          _sumRow('Subtotal', '₹${order.subtotal.toStringAsFixed(2)}'),
          _sumRow('Platform Fee', '₹${order.platformFee.toStringAsFixed(2)}'),
          _sumRow('Packaging Fee', '₹${order.packagingFee.toStringAsFixed(2)}'),
          _sumRow(
            'Delivery',
            isFreeDelivery
                ? 'FREE'
                : '₹${order.deliveryCharge.toStringAsFixed(2)}',
            valueColor: isFreeDelivery ? AppColors.success : null,
          ),
          const Divider(color: AppColors.border, height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppStyles.cardTitle.copyWith(fontSize: 14)),
              Text(
                '₹${order.total.toStringAsFixed(2)}',
                style: AppStyles.priceText.copyWith(fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.codYellowBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.codYellowIcon.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: AppColors.codYellowIcon,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  order.paymentMethod == 'online'
                      ? 'Paid Online ✓'
                      : 'Cash on Delivery',
                  style: AppStyles.labelText.copyWith(
                    color: AppColors.codYellowIcon,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppStyles.bodyText.copyWith(fontSize: 12)),
          Text(
            value,
            style: AppStyles.bodyText.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Address Card ────────────────────────────────────────────

  Widget _buildAddressCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'Delivery Address',
                style: AppStyles.sectionHeader.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.address,
            style: AppStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
          if (order.landmark.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Landmark: ${order.landmark}',
              style: AppStyles.bodyText.copyWith(fontSize: 11),
            ),
          ],
          if (_distanceKm != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.route_outlined,
                    color: AppColors.primary,
                    size: 12,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_distanceKm!.toStringAsFixed(1)} km · ${_getEta()}',
                    style: AppStyles.labelText.copyWith(
                      color: AppColors.primary,
                      fontSize: 10,
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

  // ── Home Button ─────────────────────────────────────────────

  Widget _buildHomeButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Back to Home',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  // ── Error State ─────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
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
          const SizedBox(height: 14),
          Text(
            'Order not found',
            style: AppStyles.sectionHeader.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Something went wrong. Please go back.',
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Go Back',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }
}
