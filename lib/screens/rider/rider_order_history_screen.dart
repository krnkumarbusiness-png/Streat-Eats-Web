import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../models/order_model.dart';
import 'rider_order_detail_screen.dart';

class RiderOrderHistoryScreen extends StatefulWidget {
  const RiderOrderHistoryScreen({super.key});

  @override
  State<RiderOrderHistoryScreen> createState() =>
      _RiderOrderHistoryScreenState();
}

class _RiderOrderHistoryScreenState extends State<RiderOrderHistoryScreen> {
  final _supabase = Supabase.instance.client;

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Active', 'Today', 'This Week'];

  static const _activeStatuses = ['preparing', 'picked_up', 'on_the_way'];
  static const _allRiderStatuses = [
    'preparing',
    'picked_up',
    'on_the_way',
    'delivered',
  ];

  final Map<String, String> _statusLabels = {
    'preparing': 'Preparing',
    'picked_up': 'Picked Up',
    'on_the_way': 'On the Way',
    'delivered': 'Delivered',
  };

  final Map<String, Color> _statusColors = {
    'preparing': AppColors.warning,
    'picked_up': AppColors.warning,
    'on_the_way': AppColors.acceptedBlue,
    'delivered': AppColors.success,
  };

  final Map<String, IconData> _statusIcons = {
    'preparing': Icons.restaurant_rounded,
    'picked_up': Icons.inventory_2_rounded,
    'on_the_way': Icons.delivery_dining_rounded,
    'delivered': Icons.check_circle_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final data = await _supabase
          .from('orders')
          .select()
          .eq('rider_id', userId)
          .inFilter('status', _allRiderStatuses)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = (data as List).map((e) => OrderModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<OrderModel> get _filteredOrders {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Active':
        return _orders
            .where((o) => _activeStatuses.contains(o.status))
            .toList();
      // NAYA
      case 'Today':
        return _orders.where((o) {
          final d = o.createdAt.toLocal();
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final startDay = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day,
        );
        return _orders
            .where((o) => o.createdAt.toLocal().isAfter(startDay))
            .toList();
      default:
        return _orders;
    }
  }

  // SAHI
  double get _totalEarnings => _orders
      .where((o) => o.status == 'delivered')
      .fold(0.0, (sum, o) => sum + o.deliveryCharge + o.tipAmount);

  double get _todayEarnings {
    final today = DateTime.now();
    return _orders
        .where(
          (o) =>
              o.status == 'delivered' &&
              o.createdAt.toLocal().year == today.year &&
              o.createdAt.toLocal().month == today.month &&
              o.createdAt.toLocal().day == today.day,
        )
        .fold(0.0, (sum, o) => sum + o.deliveryCharge + o.tipAmount);
  }

  int get _activeOrdersCount =>
      _orders.where((o) => _activeStatuses.contains(o.status)).length;

  @override
  Widget build(BuildContext context) {
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
          'My Orders',
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
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : Column(
              children: [
                _buildStatsRow(),
                _buildFilterChips(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadOrders,
                    child: _filteredOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filteredOrders.length,
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
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          _statCard(
            'Total',
            '${_orders.length}',
            Icons.receipt_long_rounded,
            AppColors.primary,
          ),
          const SizedBox(width: 8),
          _statCard(
            'Active',
            '$_activeOrdersCount',
            Icons.delivery_dining_rounded,
            AppColors.warning,
          ),
          const SizedBox(width: 8),
          _statCard(
            'Delivered',
            '${_orders.where((o) => o.status == 'delivered').length}',
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
          const SizedBox(width: 8),
          _statCard(
            "Today's ₹",
            '₹${_todayEarnings.toStringAsFixed(0)}',
            Icons.currency_rupee_rounded,
            AppColors.revenueCyan,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 8,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          ..._filters.map((f) {
            final isSelected = _selectedFilter == f;
            Color chipColor = AppColors.primary;
            if (f == 'Active') chipColor = AppColors.warning;

            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? chipColor : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? chipColor : AppColors.border,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: chipColor.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f == 'Active' && _activeOrdersCount > 0) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      f,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (f == 'Active' && _activeOrdersCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.3)
                              : AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_activeOrdersCount',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Text(
              '₹${_totalEarnings.toStringAsFixed(0)} earned',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 10,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Order Card — NOW CLICKABLE ─────────────────────────────────
  Widget _buildOrderCard(OrderModel order) {
    final shortId = order.id.substring(order.id.length - 6).toUpperCase();
    final dateStr = DateFormat(
      'dd MMM, hh:mm a',
    ).format(order.createdAt.toLocal());
    final itemCount = order.items.length;
    final status = order.status;
    final statusColor = _statusColors[status] ?? AppColors.textMuted;
    final statusIcon = _statusIcons[status] ?? Icons.circle;
    final isDelivered = status == 'delivered';
    final isActive = _activeStatuses.contains(status);

    return GestureDetector(
      // ✅ FIXED — now navigates to order detail
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiderOrderDetailScreen(orderId: order.id),
          ),
        ).then((_) => _loadOrders()); // refresh on return
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? statusColor.withOpacity(0.4)
                : AppColors.success.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? statusColor.withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Active order top banner
            if (isActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  border: Border(
                    bottom: BorderSide(color: statusColor.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      'In Progress — ${_statusLabels[status] ?? status}',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const Spacer(),
                    // Tap hint for active orders
                    Text(
                      'Tap to view →',
                      style: TextStyle(
                        color: statusColor.withOpacity(0.6),
                        fontSize: 10,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: ID + Status + Commission
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabels[status] ?? status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isDelivered)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            order.tipAmount > 0
                                ? '+₹${(order.deliveryCharge + order.tipAmount).toStringAsFixed(0)}'
                                : '+₹${order.deliveryCharge.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.warning.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            '₹${order.deliveryCharge.toStringAsFixed(0)} pending',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Row 2: Pickup → Delivery
                  Row(
                    children: [
                      Expanded(
                        child: _locationChip(
                          Icons.store_rounded,
                          'Pickup',
                          order.vendorName,
                          AppColors.warning,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textMuted,
                          size: 14,
                        ),
                      ),
                      Expanded(
                        child: _locationChip(
                          Icons.location_on_rounded,
                          'Delivery',
                          order.address,
                          AppColors.success,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Row 3: Date + Items + Amount
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$itemCount item${itemCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isDelivered
                            ? '₹${order.total.toStringAsFixed(0)} collected'
                            : '₹${order.total.toStringAsFixed(0)} order',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
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
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: const Center(
                child: Text('🛵', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _selectedFilter == 'All'
                  ? 'Koi Order Nahi'
                  : '$_selectedFilter mein koi order nahi',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'Active'
                  ? 'Abhi koi active order nahi hai'
                  : 'Accept kiye orders yahan dikhenge!',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontFamily: 'Poppins',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedFilter != 'All') ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _selectedFilter = 'All'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: const Text(
                    'Sab orders dekho',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
