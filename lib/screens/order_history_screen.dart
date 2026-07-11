import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import 'order_status_screen.dart';
import '../constants/app_snackbar.dart';
import '../services/review_service.dart';
import 'review_screen.dart';

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
    _loadOrders();
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
    final isRejected = order.status == 'rejected'; // ✅ NEW

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
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ID + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#$shortId',
                    style: AppStyles.cardTitle.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getStatusLabel(order.status),
                      style: AppStyles.labelText.copyWith(
                        color: statusColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),

              // Vendor + Date
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.vendorName,
                      style: AppStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(date, style: AppStyles.bodyText.copyWith(fontSize: 11)),
                ],
              ),

              const SizedBox(height: 8),

              // Items
              Text(
                order.items.isEmpty
                    ? 'Loading items...'
                    : order.items
                          .map((i) => '${i.name} ×${i.quantity}')
                          .join(', '),
                style: AppStyles.bodyText.copyWith(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // ✅ Rejected message
              if (isRejected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.2)),
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
                          'Your order was rejected by the rider. Please place a new order.',
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

              // Total + Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${order.total.toStringAsFixed(0)}',
                    style: AppStyles.priceText,
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.radar,
                            color: AppColors.primary,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Track Order',
                            style: AppStyles.labelText.copyWith(
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (order.status == 'delivered')
                    _reviewedOrderIds.contains(order.id)
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.success.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reviewed',
                                  style: AppStyles.labelText.copyWith(
                                    color: AppColors.success,
                                    fontSize: 11,
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
                                AppSnackBar.showSuccess(
                                  context,
                                  'Thank you for your review! ⭐',
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Rate Order',
                                    style: AppStyles.labelText.copyWith(
                                      color: Colors.white,
                                      fontSize: 11,
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
