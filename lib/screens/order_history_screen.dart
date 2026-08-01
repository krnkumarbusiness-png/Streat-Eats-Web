import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import 'order_status_screen.dart';
import '../services/review_service.dart';
import 'review_screen.dart';
import '../constants/globals.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<OrderModel> _orders = [];
  Set<String> _reviewedOrderIds = {};
  bool _isLoading = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    CartVisibilityControl.hide();
    _loadOrders();
  }

  @override
  void dispose() {
    CartVisibilityControl.show();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    try {
      final orders = await OrderService().getUserOrders();
      // Delivered orders ke liye reviewed IDs fetch karo
      final deliveredIds = orders
          .where((o) => o.status == 'delivered')
          .map((o) => o.id)
          .toList();
      final reviewed = await ReviewService().getReviewedOrderIds(deliveredIds);
      if (mounted) {
        setState(() {
          _orders = orders;
          _reviewedOrderIds = reviewed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
      case 'rejected': // ✅ rejected bhi red
        return AppColors.error;
      case 'placed':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'placed':
        return 'Order Placed';
      case 'preparing':
        return 'Preparing';
      case 'picked_up':
        return 'Picked Up';
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered ✅';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected': // ✅ NEW
        return 'Rejected ❌';
      default:
        return status;
    }
  }

  // ✅ Is order active? rejected aur cancelled dono inactive hain
  bool _isActive(String status) {
    return status != 'delivered' &&
        status != 'cancelled' &&
        status != 'rejected';
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month]}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Order History', style: AppStyles.screenTitle),
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? _buildShimmer()
          : _errorMsg.isNotEmpty
          ? _buildErrorState()
          : _orders.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _loadOrders,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildOrderCard(_orders[index]),
              ),
            ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final shortId = order.id.substring(order.id.length - 8).toUpperCase();
    final date = _formatDate(order.createdAt);
    final statusColor = _getStatusColor(order.status);
    final isActive = _isActive(order.status);
    final isRejected = order.status == 'rejected';

    // Progress bar ke liye step calculate karo
    int progressStep() {
      switch (order.status) {
        case 'placed':
          return 1;
        case 'preparing':
          return 2;
        case 'picked_up':
          return 3;
        case 'on_the_way':
          return 4;
        case 'delivered':
          return 5;
        default:
          return 0;
      }
    }

    final step = progressStep();
    final totalSteps = 5;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: order.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withOpacity(0.25)
                : order.status == 'delivered'
                ? AppColors.success.withOpacity(0.2)
                : isRejected
                ? AppColors.error.withOpacity(0.2)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP PROGRESS BAR (sirf active orders pe) ──
            if (isActive)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: LinearProgressIndicator(
                  value: step / totalSteps,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                ),
              )
            else
              // Delivered = green bar full, cancelled/rejected = red bar
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: LinearProgressIndicator(
                  value: order.status == 'delivered' ? 1.0 : 0.0,
                  backgroundColor: isRejected || order.status == 'cancelled'
                      ? AppColors.error.withOpacity(0.15)
                      : AppColors.success.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    order.status == 'delivered'
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  minHeight: 4,
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── STATUS + PRICE ROW ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status icon box
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.25),
                          ),
                        ),
                        child: Icon(
                          order.status == 'delivered'
                              ? Icons.check_rounded
                              : order.status == 'cancelled' || isRejected
                              ? Icons.close_rounded
                              : order.status == 'on_the_way'
                              ? Icons.delivery_dining_rounded
                              : order.status == 'picked_up'
                              ? Icons.shopping_bag_rounded
                              : Icons.receipt_long_rounded,
                          color: statusColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusLabel(order.status),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.vendorName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── ITEMS LIST ──
                  if (order.items.isNotEmpty)
                    ...order.items
                        .take(3)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                // Quantity badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.error.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(
                                    '${item.quantity}×',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A1A),
                                      fontFamily: 'Poppins',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                  // More items indicator
                  if (order.items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '+${order.items.length - 3} more items',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),

                  // ── REJECTED MESSAGE ──
                  if (isRejected) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.error,
                            size: 13,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Order was rejected. Please place a new order.',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontFamily: 'Poppins',
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),

                  // ── DATE + ACTION BUTTON ROW ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontFamily: 'Poppins',
                        ),
                      ),

                      // Track Order button (active orders)
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Track Order',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                            ],
                          ),
                        ),

                      // Rate Order / Reviewed (delivered orders)
                      if (order.status == 'delivered')
                        _reviewedOrderIds.contains(order.id)
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.success,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reviewed',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GestureDetector(
                                onTap: () async {
                                  final submitted =
                                      await showModalBottomSheet<bool>(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => ReviewBottomSheet(
                                          orderId: order.id,
                                          vendorId: order.vendorId,
                                          vendorName: order.vendorName,
                                          hasRider:
                                              order.riderName != null &&
                                              order.riderName!.isNotEmpty,
                                        ),
                                      );
                                  if (submitted == true && mounted) {
                                    setState(() {
                                      _reviewedOrderIds.add(order.id);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Rate Order',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/illus_hungry_boy.png',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: AppStyles.sectionHeader.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text('Place your first order!', style: AppStyles.bodyText),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load orders',
            style: AppStyles.sectionHeader.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMsg,
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_sh(w: 100, h: 14), _sh(w: 80, h: 24, r: 20)],
              ),
              const SizedBox(height: 14),
              _sh(w: double.infinity, h: 1),
              const SizedBox(height: 14),
              _sh(w: 180, h: 13),
              const SizedBox(height: 8),
              _sh(w: 240, h: 11),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sh({required double w, required double h, double r = 6}) => Container(
    height: h,
    width: w,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(r),
    ),
  );
}
