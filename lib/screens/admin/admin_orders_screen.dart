import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/push_notification_sender.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _filterStatus = 'All';
  String _dateFilter = 'Today'; // NEW

  final List<String> _statuses = [
    'All',
    'placed',
    'preparing',
    'picked_up',
    'on_the_way',
    'delivered',
    'cancelled',
  ];

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
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

    return _orders.where((o) {
      // ── Date filter ──
      final createdRaw = o['created_at'];
      if (createdRaw != null) {
        final created = DateTime.tryParse(createdRaw.toString())?.toLocal();
        if (created != null) {
          if (_dateFilter == 'Today' && created.isBefore(todayStart)) {
            return false;
          }
          if (_dateFilter == 'Yesterday' &&
              (created.isBefore(yesterdayStart) ||
                  !created.isBefore(todayStart))) {
            return false;
          }
          if (_dateFilter == 'This Week' && created.isBefore(weekStart)) {
            return false;
          }
          // 'All Time' = no date filter
        }
      }
      // ── Status filter ──
      if (_filterStatus != 'All' && o['status'] != _filterStatus) return false;
      return true;
    }).toList();
  }

  Future<void> _updateStatus(
    String orderId,
    String newStatus,
    String userId,
    String vendorName,
  ) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      final shortId = orderId.substring(orderId.length - 6).toUpperCase();
      await PushNotificationSender.sendOrderStatusNotification(
        customerId: userId,
        orderId: orderId,
        shortId: shortId,
        status: newStatus,
        vendorName: vendorName,
      );

      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status: ${_statusLabels[newStatus]} — Notification sent ✅',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Update failed, please try again'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showStatusDialog(Map<String, dynamic> order) {
    final currentStatus = order['status'] as String;
    final userId = order['user_id'] as String? ?? '';
    final vendorName = order['vendor_name'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
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
            const Text('Update Order Status', style: AppStyles.sectionHeader),
            const SizedBox(height: 4),
            Text(
              'Order #${order['id'].toString().substring(order['id'].toString().length - 8).toUpperCase()}',
              style: AppStyles.bodyText,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Customer ko automatic notification jayegi',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Poppins',
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._statuses.where((s) => s != 'All').map((status) {
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
                    color: isActive ? color.withOpacity(0.4) : AppColors.border,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    _updateStatus(order['id'], status, userId, vendorName);
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
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: isActive
                      ? Icon(Icons.check_circle_rounded, color: color, size: 20)
                      : const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Live Orders', style: AppStyles.screenTitle),
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : _filteredOrders.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadOrders,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _filteredOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _buildOrderCard(_filteredOrders[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final revenue = _filteredOrders
        .where((o) => o['status'] == 'delivered')
        .fold<double>(0, (sum, o) {
          final t = o['total'];
          return sum +
              (t is num ? t.toDouble() : double.tryParse(t.toString()) ?? 0);
        });

    final total = _filteredOrders.length;
    final active = _filteredOrders
        .where((o) => !['delivered', 'cancelled'].contains(o['status']))
        .length;
    final delivered = _filteredOrders
        .where((o) => o['status'] == 'delivered')
        .length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _buildStatCard(
            'Total',
            '$total',
            Icons.list_alt_rounded,
            AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            'Active',
            '$active',
            Icons.bolt_rounded,
            AppColors.primary,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            'Done',
            '$delivered',
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            'Revenue',
            '₹${revenue.toStringAsFixed(0)}',
            Icons.currency_rupee_rounded,
            AppColors.revenueCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final dateOptions = ['Today', 'Yesterday', 'This Week', 'All Time'];
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Container(height: 1, color: AppColors.border),
          // ── Date Filter Row ──
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: dateOptions.length,
              itemBuilder: (_, i) {
                final d = dateOptions[i];
                final isSelected = _dateFilter == d;
                return GestureDetector(
                  onTap: () => setState(() => _dateFilter = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(height: 1, color: AppColors.border),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statuses.length,
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final isSelected = _filterStatus == s;
                final color = s == 'All'
                    ? AppColors.textDark
                    : (_statusColors[s] ?? AppColors.textMuted);
                return GestureDetector(
                  onTap: () => setState(() => _filterStatus = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (s == 'All' ? AppColors.textDark : color)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s == 'All' ? 'All' : (_statusLabels[s] ?? s),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final shortId = order['id']
        .toString()
        .substring(order['id'].toString().length - 8)
        .toUpperCase();
    final status = order['status'] as String;
    final statusColor = _statusColors[status] ?? AppColors.textMuted;
    final statusIcon = _statusIcons[status] ?? Icons.circle;
    final items = order['items'] as List<dynamic>? ?? [];
    final itemsText = items
        .map((i) => '${i['name']} x${i['quantity']}')
        .join(', ');

    // ✅ Payment info
    final paymentMethod = order['payment_method'] as String? ?? 'cod';
    final paymentStatus = order['payment_status'] as String? ?? 'cod';
    final isOnline = paymentMethod == 'online';
    final isPaid = paymentStatus == 'paid';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
      ),
      child: Container(
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
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: statusColor.withOpacity(0.15)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag, color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    shortId,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ✅ COD / Paid Online badge — header mein
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? (isPaid
                                ? AppColors.success.withOpacity(0.12)
                                : AppColors.warning.withOpacity(0.12))
                          : AppColors.codYellowBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOnline
                            ? (isPaid
                                  ? AppColors.success.withOpacity(0.4)
                                  : AppColors.warning.withOpacity(0.4))
                            : AppColors.codYellowIcon.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline
                              ? (isPaid
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_rounded)
                              : Icons.money_rounded,
                          size: 10,
                          color: isOnline
                              ? (isPaid ? AppColors.success : AppColors.warning)
                              : AppColors.codYellowIcon,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isOnline
                              ? (isPaid ? 'Paid ✓' : 'Online Pending')
                              : 'COD',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
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
                  ),

                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showStatusDialog(order),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            _statusLabels[status] ?? status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            color: statusColor,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          order['vendor_name'] ?? '',
                          style: AppStyles.cardTitle,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${order['total']}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Customer name
                  if ((order['customer_name'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.textMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order['customer_name'] ?? '',
                            style: AppStyles.bodyText,
                          ),
                          const SizedBox(width: 8),
                          if ((order['customer_phone'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Text(
                              order['customer_phone'] ?? '',
                              style: AppStyles.bodyText.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${order['address'] ?? ''}${order['landmark'] != null && order['landmark'].toString().isNotEmpty ? ' · ${order['landmark']}' : ''}',
                          style: AppStyles.bodyText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.restaurant_menu_outlined,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          itemsText,
                          style: AppStyles.bodyText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // OTP
                  if (order['delivery_otp'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.upiLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.upiPurple.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.upiPurple,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Delivery OTP: ${order['delivery_otp']}',
                            style: const TextStyle(
                              color: AppColors.upiPurple,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Mystery Gift
                  if ((order['mystery_gift_item'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF6B2B).withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎁', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            'Gift: ${order['mystery_gift_item']}',
                            style: const TextStyle(
                              color: Color(0xFFFF6B2B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text('No Orders Yet', style: AppStyles.sectionHeader),
            const SizedBox(height: 8),
            Text(
              _filterStatus == 'All'
                  ? 'Koi order abhi tak nahi aaya'
                  : '${_statusLabels[_filterStatus]} mein koi order nahi',
              style: AppStyles.bodyText,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadOrders,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Refresh Karo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
