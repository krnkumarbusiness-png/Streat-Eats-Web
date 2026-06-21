import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/push_notification_sender.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> _order;
  bool _isUpdating = false;

  final Map<String, String> _statusLabels = {
    'placed': 'Order Hua',
    'preparing': 'Ban Raha Hai',
    'picked_up': 'Rider Ne Liya',
    'on_the_way': 'Aa Raha Hai',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  final Map<String, Color> _statusColors = {
    'placed': AppColors.primary,
    'preparing': AppColors.warning,
    'picked_up': AppColors.warning,
    'on_the_way': AppColors.acceptedBlue,
    'delivered': AppColors.success,
    'cancelled': AppColors.error,
  };

  final Map<String, IconData> _statusIcons = {
    'placed': Icons.receipt_long,
    'preparing': Icons.restaurant,
    'picked_up': Icons.inventory_2,
    'on_the_way': Icons.delivery_dining,
    'delivered': Icons.check_circle,
    'cancelled': Icons.cancel,
  };

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '—';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return '—';
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', _order['id']);

      final userId = _order['user_id'] as String? ?? '';
      final vendorName = _order['vendor_name'] as String? ?? '';
      final orderId = _order['id'] as String;
      final shortId = orderId.substring(orderId.length - 6).toUpperCase();

      await PushNotificationSender.sendOrderStatusNotification(
        customerId: userId,
        orderId: orderId,
        shortId: shortId,
        status: newStatus,
        vendorName: vendorName,
      );

      setState(() {
        _order['status'] = newStatus;
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated: ${_statusLabels[newStatus]} ✅'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update failed, try again'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Active Riders Fetch + Reassign Logic ────────────────────
  Future<void> _showChangeRiderModal() async {
    // Active + approved riders fetch karo
    List<Map<String, dynamic>> riders = [];
    bool isFetchingRiders = true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Riders fetch on open
            if (isFetchingRiders) {
              _supabase
                  .from('riders')
                  .select('id, full_name, phone, area, is_available, status')
                  .eq('status', 'approved')
                  .eq('is_available', true)
                  .then((data) {
                    setModalState(() {
                      riders = List<Map<String, dynamic>>.from(data);
                      isFetchingRiders = false;
                    });
                  })
                  .catchError((_) {
                    setModalState(() => isFetchingRiders = false);
                  });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.85,
              minChildSize: 0.4,
              builder: (_, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Change Rider',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current: ${(_order['rider_name'] ?? 'No rider assigned')}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),
                    if (isFetchingRiders)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else if (riders.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.delivery_dining_outlined,
                                color: AppColors.textMuted,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No active riders available right now',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: riders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final rider = riders[i];
                            final isCurrentRider =
                                rider['id'] == _order['rider_id'];
                            return GestureDetector(
                              onTap: isCurrentRider
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      _confirmRiderChange(rider);
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCurrentRider
                                      ? AppColors.primary.withOpacity(0.06)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrentRider
                                        ? AppColors.primary.withOpacity(0.4)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.delivery_dining_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rider['full_name'] ?? 'Rider',
                                            style: const TextStyle(
                                              color: AppColors.textDark,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            rider['phone'] ?? '',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                          if ((rider['area'] ?? '').isNotEmpty)
                                            Text(
                                              rider['area'],
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 11,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrentRider)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'Current',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRiderChange(Map<String, dynamic> newRider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change Rider?',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
            fontSize: 16,
          ),
        ),
        content: Text(
          'Assign this order to ${newRider['full_name']}?\n\nPrevious rider\'s order will be removed and customer will be notified.',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _doRiderReassign(newRider);
  }

  Future<void> _doRiderReassign(Map<String, dynamic> newRider) async {
    setState(() => _isUpdating = true);
    try {
      final oldRiderId = _order['rider_id'] as String?;

      // Step 1: Order update karo naye rider ke saath
      await _supabase
          .from('orders')
          .update({
            'rider_id': newRider['id'],
            'rider_name': newRider['full_name'],
            'rider_phone': newRider['phone'] ?? '',
          })
          .eq('id', _order['id']);

      // Step 2: Purane rider ki dropped_orders count badhao (agar tha)
      if (oldRiderId != null && oldRiderId.isNotEmpty) {
        try {
          final riderData = await _supabase
              .from('riders')
              .select('dropped_orders')
              .eq('id', oldRiderId)
              .maybeSingle();
          final currentDropped =
              (riderData?['dropped_orders'] as num?)?.toInt() ?? 0;
          await _supabase
              .from('riders')
              .update({'dropped_orders': currentDropped + 1})
              .eq('id', oldRiderId);
        } catch (_) {}
      }

      // Step 3: Customer ko push notification bhejo
      final userId = _order['user_id'] as String? ?? '';
      if (userId.isNotEmpty) {
        try {
          await _supabase.functions.invoke(
            'send-notification',
            body: {
              'user_id': userId,
              'title': 'Delivery Rider Changed 🛵',
              'body':
                  'Your delivery rider has been updated. A new rider will reach you shortly!',
              'data': {
                'user_id': userId,
                'type': 'rider_changed',
                'order_id': _order['id'],
              },
            },
          );
        } catch (_) {}
      }

      // Step 4: ✅ NEW — Naye rider ko notification bhejo
      // Rider ka dashboard poll karta hai, but notification se instant alert milega
      try {
        final shortId = (_order['id'] as String)
            .substring((_order['id'] as String).length - 6)
            .toUpperCase();
        await _supabase.functions.invoke(
          'send-notification',
          body: {
            'user_id': newRider['id'],
            'title': '🛵 Order Assigned To You!',
            'body':
                '#$shortId — ${_order['vendor_name'] ?? 'Vendor'} — ₹${(_order['total'] as num?)?.toStringAsFixed(0) ?? '0'} | Check your dashboard!',
            'data': {
              'user_id': newRider['id'],
              'type': 'new_order_available',
              'order_id': _order['id'],
            },
          },
        );
      } catch (_) {}

      setState(() {
        _order['rider_id'] = newRider['id'];
        _order['rider_name'] = newRider['full_name'];
        _order['rider_phone'] = newRider['phone'] ?? '';
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rider changed to ${newRider['full_name']} ✅ — Customer notified',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rider change failed, try again'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showStatusDialog() {
    final currentStatus = _order['status'] as String;
    final statuses = [
      'placed',
      'preparing',
      'picked_up',
      'on_the_way',
      'delivered',
      'cancelled',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Update Order Status', style: AppStyles.sectionHeader),
              const SizedBox(height: 12),
              ...statuses.map((status) {
                final isActive = currentStatus == status;
                final color = _statusColors[status] ?? AppColors.textMuted;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? color.withOpacity(0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      _updateStatus(status);
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _statusIcons[status] ?? Icons.circle,
                        color: color,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      _statusLabels[status] ?? status,
                      style: AppStyles.cardTitle.copyWith(
                        color: isActive ? color : AppColors.textDark,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isActive
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: color,
                            size: 20,
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                  ),
                );
              }),
            ],
          ), // Column
        ), // SingleChildScrollView
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _order['status'] as String;
    final statusColor = _statusColors[status] ?? AppColors.textMuted;
    final statusIcon = _statusIcons[status] ?? Icons.circle;
    final items = _order['items'] as List<dynamic>? ?? [];
    final orderId = _order['id'].toString();
    final shortId = orderId.substring(orderId.length - 8).toUpperCase();

    final paymentMethod = _order['payment_method'] as String? ?? 'cod';
    final paymentStatus = _order['payment_status'] as String? ?? 'cod';
    final isOnline = paymentMethod == 'online';
    final isPaid = paymentStatus == 'paid';

    final subtotal = ((_order['subtotal'] as num?)?.toDouble() ?? 0);
    final platformFee = ((_order['platform_fee'] as num?)?.toDouble() ?? 0);
    final deliveryCharge =
        ((_order['delivery_charge'] as num?)?.toDouble() ?? 0);
    final packagingFee = ((_order['packaging_fee'] as num?)?.toDouble() ?? 0);
    final total = ((_order['total'] as num?)?.toDouble() ?? 0);
    final promoCode = _order['applied_promo_code'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Detail', style: AppStyles.screenTitle),
            Text(
              '#$shortId',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status + Time Card ──────────────────────
              _buildCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusLabels[status] ?? status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(_order['created_at']),
                            style: AppStyles.bodyText,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showStatusDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Change',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Customer Info ───────────────────────────
              _buildSectionCard(
                title: 'Customer Info',
                icon: Icons.person_outline_rounded,
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.person_rounded,
                      'Name',
                      _order['customer_name'] ?? '—',
                    ),
                    _buildInfoRow(
                      Icons.phone_rounded,
                      'Phone',
                      _order['customer_phone'] ?? '—',
                      isPhone: true,
                    ),
                    _buildInfoRow(
                      Icons.location_on_rounded,
                      'Address',
                      _order['address'] ?? '—',
                    ),
                    if ((_order['landmark'] ?? '').toString().isNotEmpty)
                      _buildInfoRow(
                        Icons.flag_rounded,
                        'Landmark',
                        _order['landmark'],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Vendor Info ─────────────────────────────────────────────
              _buildSectionCard(
                title: 'Vendor Info',
                icon: Icons.storefront_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.store_rounded,
                      'Vendor',
                      _order['vendor_name'] ?? '—',
                    ),
                    if ((_order['rider_name'] ?? '').toString().isNotEmpty)
                      _buildInfoRow(
                        Icons.delivery_dining_rounded,
                        'Rider',
                        _order['rider_name'],
                      ),
                    if ((_order['rider_phone'] ?? '').toString().isNotEmpty)
                      _buildInfoRow(
                        Icons.phone_rounded,
                        'Rider Phone',
                        _order['rider_phone'],
                        isPhone: true,
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showChangeRiderModal,
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Change Rider',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Items Ordered ───────────────────────────
              _buildSectionCard(
                title: 'Items Ordered',
                icon: Icons.restaurant_menu_rounded,
                child: Column(
                  children: [
                    ...items.map((item) {
                      final name = item['name'] ?? '';
                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                      final appPrice =
                          (item['app_price'] as num?)?.toDouble() ??
                          (item['price'] as num?)?.toDouble() ??
                          0;
                      final vendorPrice =
                          (item['vendor_price'] as num?)?.toDouble() ?? 0;
                      final portion = item['portion'] as String? ?? '';
                      final hasHalf = portion == 'half';
                      final hasFull = portion == 'full';
                      final margin = appPrice - vendorPrice;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: AppStyles.cardTitle,
                                            ),
                                          ),
                                          if (hasHalf)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                left: 6,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7C3AED),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'HALF',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ),
                                          if (hasFull)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                left: 6,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'FULL',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (vendorPrice > 0) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.error
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: AppColors.error
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                'Cost ₹${vendorPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: AppColors.error,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                          ],
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.success
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              border: Border.all(
                                                color: AppColors.success
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              'App ₹${appPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: AppColors.success,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                          if (vendorPrice > 0) ...[
                                            const SizedBox(width: 5),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'Margin ₹${margin.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${(appPrice * qty).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Bill Summary ────────────────────────────
              _buildSectionCard(
                title: 'Bill Summary',
                icon: Icons.receipt_long_rounded,
                child: Column(
                  children: [
                    _buildBillRow(
                      'Subtotal',
                      '₹${subtotal.toStringAsFixed(0)}',
                    ),
                    if (deliveryCharge > 0)
                      _buildBillRow(
                        'Delivery',
                        '₹${deliveryCharge.toStringAsFixed(0)}',
                      ),
                    if (platformFee > 0)
                      _buildBillRow(
                        'Platform Fee',
                        '₹${platformFee.toStringAsFixed(0)}',
                      ),
                    if (packagingFee > 0)
                      _buildBillRow(
                        'Packaging',
                        '₹${packagingFee.toStringAsFixed(0)}',
                      ),
                    if (((_order['tip_amount'] as num?)?.toInt() ?? 0) > 0)
                      _buildBillRow(
                        'Rider Tip 🎉',
                        '+₹${((_order['tip_amount'] as num?)?.toInt() ?? 0)}',
                        valueColor: AppColors.primary,
                      ),
                    if (promoCode != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_offer_rounded,
                            color: AppColors.success,
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Promo: $promoCode',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Payment Info ────────────────────────────
              _buildSectionCard(
                title: 'Payment',
                icon: Icons.payments_rounded,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? (isPaid
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1))
                            : AppColors.codYellowBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOnline
                            ? Icons.credit_card_rounded
                            : Icons.money_rounded,
                        color: isOnline
                            ? (isPaid ? AppColors.success : AppColors.warning)
                            : AppColors.codYellowIcon,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? 'Online Payment' : 'Cash on Delivery',
                          style: AppStyles.cardTitle,
                        ),
                        Text(
                          isOnline
                              ? (isPaid
                                    ? 'Payment Received ✅'
                                    : 'Payment Pending ⏳')
                              : 'Collect ₹${total.toStringAsFixed(0)} cash',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            color: isOnline
                                ? (isPaid
                                      ? AppColors.success
                                      : AppColors.warning)
                                : AppColors.codYellowIcon,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── OTP ─────────────────────────────────────
              if (_order['delivery_otp'] != null) ...[
                const SizedBox(height: 12),
                _buildCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.upiLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.upiPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivery OTP',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              '${_order['delivery_otp']}',
                              style: const TextStyle(
                                color: AppColors.upiPurple,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: 6,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: '${_order['delivery_otp']}'),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('OTP copied!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.copy_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isPhone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 14),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isPhone ? AppColors.primary : AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
