import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/colors.dart';
import '../../models/order_model.dart';
import '../../services/rider_service.dart';
import 'rider_otp_screen.dart';

class RiderOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const RiderOrderDetailScreen({super.key, required this.orderId});

  @override
  State<RiderOrderDetailScreen> createState() => _RiderOrderDetailScreenState();
}

// ✅ FIX: WidgetsBindingObserver add kiya — app resume pe order refresh hoga
class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen>
    with WidgetsBindingObserver {
  final _riderService = RiderService();
  final _supabase = Supabase.instance.client;

  OrderModel? _order;
  bool _isLoading = true;
  bool _isUpdating = false;
  Timer? _pollingTimer;

  String _customerName = '';
  String _customerPhone = '';
  bool _customerLoading = true;

  // ✅ NEW: Recipient info (for "deliver to someone else" orders)
  String _recipientName = '';
  String _recipientPhone = '';
  bool _isManualAddress = false;

  double? _customerLat;
  double? _customerLng;

  String _vendorArea = '';
  double? _vendorLat;
  double? _vendorLng;
  bool _vendorLoading = true;
  // ✅ NEW: Multi-vendor support
  List<Map<String, dynamic>> _vendorDetails = [];
  bool _multiVendorLoading = true;

  final List<String> _statusSteps = [
    'placed',
    'preparing',
    'picked_up',
    'on_the_way',
    'delivered',
  ];

  final List<Map<String, String>> _stepMeta = [
    {'label': 'Order\nPlaced', 'icon': '📋'},
    {'label': 'At\nVendor', 'icon': '🏪'},
    {'label': 'Picked\nUp', 'icon': '🛵'},
    {'label': 'On the\nWay', 'icon': '📍'},
    {'label': 'Delivered', 'icon': '✅'},
  ];

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Observer register karo — app lifecycle changes track karne ke liye
    WidgetsBinding.instance.addObserver(this);
    _fetchOrder();
    _startPolling();
  }

  @override
  void dispose() {
    // ✅ FIX: Observer aur timer dono dispose karo
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ✅ FIX: Ye method call hoti hai jab app background se foreground aaye
  // Jaise: rider Google Maps se wapas aaya → order automatically refresh hoga
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App wapas foreground mein aayi — order refresh karo silently
      _fetchOrder(silent: true);

      // Agar timer kisi wajah se ruk gaya to restart karo
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _startPolling();
      }
    } else if (state == AppLifecycleState.paused) {
      // App background mein gayi — timer cancel karo battery bachao
      _pollingTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel(); // Purana timer pehle cancel karo
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchOrder(silent: true),
    );
  }

  Future<void> _fetchOrder({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final order = await _riderService.getOrderById(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
        if (order != null) {
          if (_customerName.isEmpty) _loadCustomerInfo(order);
          if (_vendorLoading) _loadVendorInfo(order.vendorId);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ UPDATED: Ab recipient_name, recipient_phone, is_manual_address bhi fetch hoga
  Future<void> _loadCustomerInfo(OrderModel order) async {
    final orderRaw = await _supabase
        .from('orders')
        .select(
          'customer_name, customer_phone, is_manual_address, recipient_name, recipient_phone, customer_lat, customer_lng',
        )
        .eq('id', order.id)
        .maybeSingle();

    final savedName = orderRaw?['customer_name'] as String? ?? '';
    final savedPhone = orderRaw?['customer_phone'] as String? ?? '';
    final isManual = orderRaw?['is_manual_address'] as bool? ?? false;
    final recipientName = orderRaw?['recipient_name'] as String? ?? '';
    final recipientPhone = orderRaw?['recipient_phone'] as String? ?? '';

    if (mounted) {
      setState(() {
        _isManualAddress = isManual;
        _recipientName = recipientName;
        _recipientPhone = recipientPhone;
        _customerLat = (orderRaw?['customer_lat'] as num?)?.toDouble();
        _customerLng = (orderRaw?['customer_lng'] as num?)?.toDouble();
      });
    }

    if (savedName.isNotEmpty || savedPhone.isNotEmpty) {
      if (mounted) {
        setState(() {
          _customerName = savedName.isNotEmpty ? savedName : 'Customer';
          _customerPhone = savedPhone;
          _customerLoading = false;
        });
      }
      return;
    }

    if (order.userId.isEmpty) {
      if (mounted) setState(() => _customerLoading = false);
      return;
    }

    try {
      final data = await _supabase
          .from('users')
          .select('full_name, phone')
          .eq('id', order.userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _customerName = data?['full_name'] as String? ?? 'Customer';
          _customerPhone = data?['phone'] as String? ?? '';
          _customerLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _customerName = 'Customer';
          _customerPhone = '';
          _customerLoading = false;
        });
      }
    }
  }

  Future<void> _loadVendorInfo(String primaryVendorId) async {
    if (primaryVendorId.isEmpty) {
      if (mounted) {
        setState(() {
          _vendorLoading = false;
          _multiVendorLoading = false;
        });
      }
      return;
    }
    try {
      final table = (_order?.orderType == 'sweets')
          ? 'sweet_vendors'
          : 'vendors';

      // ✅ Order items se saare unique vendor IDs nikalo
      final allVendorIds = <String>{primaryVendorId};
      if (_order != null) {
        for (final item in _order!.items) {
          if (item.vendorId.isNotEmpty) allVendorIds.add(item.vendorId);
        }
      }

      final vendorDetailsList = <Map<String, dynamic>>[];

      for (final vid in allVendorIds) {
        try {
          final data = await _supabase
              .from(table)
              .select('id, name, area, latitude, longitude, phone')
              .eq('id', vid)
              .maybeSingle();

          if (data != null) {
            vendorDetailsList.add({
              'id': vid,
              'name': data['name'] as String? ?? _order?.vendorName ?? '',
              'area': data['area'] as String? ?? '',
              'lat': (data['latitude'] as num?)?.toDouble(),
              'lng': (data['longitude'] as num?)?.toDouble(),
              'phone': data['phone'] as String? ?? '',
            });
          }
        } catch (_) {}
      }

      // Legacy single vendor fields bhi update karo (backward compat)
      if (vendorDetailsList.isNotEmpty) {
        final primary = vendorDetailsList.first;
        if (mounted) {
          setState(() {
            _vendorArea = primary['area'] as String? ?? '';
            _vendorLat = primary['lat'] as double?;
            _vendorLng = primary['lng'] as double?;
            _vendorDetails = vendorDetailsList;
            _vendorLoading = false;
            _multiVendorLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _vendorLoading = false;
          _multiVendorLoading = false;
        });
      }
    }
  }

  int _getStatusIndex(String status) {
    final idx = _statusSteps.indexOf(status);
    return idx == -1 ? 0 : idx;
  }

  Map<String, dynamic>? _getNextAction(String currentStatus) {
    switch (currentStatus) {
      case 'placed':
      case 'preparing':
        return {
          'label': 'Reached Vendor 🏪',
          'nextStatus': 'preparing',
          'color': AppColors.warning,
          'isOtp': false,
        };
      case 'picked_up':
        return {
          'label': 'Heading to Customer 🛵',
          'nextStatus': 'on_the_way',
          'color': AppColors.primary,
          'isOtp': false,
        };
      case 'on_the_way':
        return {
          'label': 'Deliver with OTP ✅',
          'nextStatus': 'delivered',
          'color': AppColors.success,
          'isOtp': true,
        };
      default:
        return null;
    }
  }

  Future<void> _updateStatus(
    OrderModel order,
    String nextStatus,
    bool isOtp,
  ) async {
    if (isOtp) {
      _pollingTimer?.cancel();
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RiderOtpScreen(order: order)),
      );
      _fetchOrder();
      _startPolling();
      return;
    }
    setState(() => _isUpdating = true);
    try {
      await _riderService.updateOrderStatus(order.id, nextStatus);
      await _fetchOrder(silent: true);
      if (!mounted) return;
      _snack('Status updated!', AppColors.success);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: ${e.toString()}', AppColors.error);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markPickedUp(String orderId) async {
    setState(() => _isUpdating = true);
    try {
      await _riderService.updateOrderStatus(orderId, 'picked_up');
      await _fetchOrder(silent: true);
      if (!mounted) return;
      _snack('Picked up! Head to customer.', AppColors.success);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: ${e.toString()}', AppColors.error);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    if (phone.isEmpty) return;
    HapticFeedback.mediumImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: phone));
        _snack('Number copied: $phone', AppColors.primary);
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: phone));
      _snack('Number copied: $phone', AppColors.primary);
    }
  }

  // ✅ FIX: Timer pause karo Maps khulne se pehle, wapas aane pe restart
  // Isse order data lost nahi hoga jab rider Maps se wapas aaye
  Future<void> _openMapsWithCoords(double lat, double lng, String label) async {
    HapticFeedback.lightImpact();

    // Maps kholne se pehle timer pause — battery bachao + lifecycle observer handle karega
    _pollingTimer?.cancel();

    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final googleMapsAppUrl = 'google.navigation:q=$lat,$lng&mode=d';

    final appUri = Uri.parse(googleMapsAppUrl);
    final webUri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      final searchUrl =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}';
      await launchUrl(
        Uri.parse(searchUrl),
        mode: LaunchMode.externalApplication,
      );
    }
    // Note: Timer restart didChangeAppLifecycleState > resumed mein hoga automatically
  }

  // ✅ FIX: Same fix — address se Maps kholne pe bhi timer pause
  Future<void> _openMapsWithAddress(String address, String landmark) async {
    HapticFeedback.lightImpact();

    // Maps kholne se pehle timer pause
    _pollingTimer?.cancel();

    final query = landmark.isNotEmpty
        ? '$address, $landmark, Haldwani'
        : '$address, Haldwani';
    final encodedQuery = Uri.encodeComponent(query);

    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$encodedQuery&travelmode=driving';
    final googleMapsAppUrl = 'google.navigation:q=$encodedQuery&mode=d';

    try {
      final appUri = Uri.parse(googleMapsAppUrl);
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
      } else {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      _snack('Could not open Maps. Check your internet.', AppColors.error);
    }
    // Note: Timer restart didChangeAppLifecycleState > resumed mein hoga automatically
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _order == null
          ? _buildNotFound()
          : _buildContent(_order!),
    );
  }

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
      title: const Text(
        'Order Detail',
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
    );
  }

  Widget _buildNotFound() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('😕', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'Order not found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    final statusIdx = _getStatusIndex(order.status);
    final nextAction = _getNextAction(order.status);
    final isDelivered = order.status == 'delivered';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEarningsBanner(order),
                const SizedBox(height: 16),
                _buildStatusTimeline(statusIdx),
                const SizedBox(height: 16),
                _buildVendorCard(order),
                const SizedBox(height: 12),
                _buildCustomerCard(order),
                const SizedBox(height: 12),
                _buildItemsCard(order),
                const SizedBox(height: 12),
                _buildPaymentCard(order),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        if (isDelivered)
          _buildDeliveredBanner(order)
        else ...[
          if (order.status == 'preparing') _buildPickupButton(order),
          if (nextAction != null && order.status != 'preparing')
            _buildActionButton(order, nextAction),
        ],
      ],
    );
  }

  Widget _buildEarningsBanner(OrderModel order) {
    final shortId = order.id.substring(order.id.length - 6).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          // ✅ NAYA — const hata do:
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your earnings for this order',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${order.deliveryCharge.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (order.tipAmount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '+₹${order.tipAmount} tip 🎉',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$shortId',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(int currentIdx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_stepMeta.length, (i) {
              final isDone = i <= currentIdx;
              final isActive = i == currentIdx;
              final isLast = i == _stepMeta.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? isActive
                                        ? AppColors.primary.withOpacity(0.15)
                                        : AppColors.success.withOpacity(0.12)
                                  : AppColors.background,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone
                                    ? isActive
                                          ? AppColors.primary
                                          : AppColors.success
                                    : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _stepMeta[i]['icon']!,
                                style: TextStyle(fontSize: isDone ? 14 : 11),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _stepMeta[i]['label']!,
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Poppins',
                              color: isDone
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 22),
                          color: i < currentIdx
                              ? AppColors.success
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(OrderModel order) {
    final isSweets = _order?.orderType == 'sweets';
    final titlePrefix = isSweets ? '🍬 Sweet Shop' : '🏪 Vendor';

    // ✅ Multi-vendor case: ek se zyada vendors hain
    if (_vendorDetails.length > 1) {
      return _InfoCard(
        title: '$titlePrefix — Pickup Here (${_vendorDetails.length} Stalls)',
        accentColor: AppColors.warning,
        children: _vendorDetails.map((v) {
          final lat = v['lat'] as double?;
          final lng = v['lng'] as double?;
          final area = v['area'] as String? ?? '';
          final name = v['name'] as String? ?? '';
          final phone = v['phone'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stall name
                Row(
                  children: [
                    const Text('🏪', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                if (area.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _InfoRow(label: 'Area', value: area),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(
                        width: 72,
                        child: Text(
                          'Phone',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          phone,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _callNumber(phone),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.warning.withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Direction button for each vendor
                if (lat != null && lng != null)
                  _buildDirectionButton(
                    label: 'Directions to $name',
                    color: AppColors.warning,
                    onTap: () =>
                        _openMapsWithCoords(lat, lng, '$name, $area, Haldwani'),
                  )
                else if (area.isNotEmpty)
                  _buildDirectionButton(
                    label: 'Directions to $name',
                    color: AppColors.warning,
                    onTap: () => _openMapsWithAddress('$name, $area', ''),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // ✅ Single vendor case (original logic — same as before)
    return _InfoCard(
      title: '$titlePrefix — Pickup Here',
      accentColor: AppColors.warning,
      children: [
        _InfoRow(label: 'Stall', value: order.vendorName),
        _InfoRow(
          label: 'Area',
          value: _vendorLoading
              ? 'Loading...'
              : _vendorArea.isNotEmpty
              ? _vendorArea
              : 'Haldwani',
        ),
        if (!_vendorLoading && _vendorLat != null && _vendorLng != null)
          _buildDirectionButton(
            label: 'Get Directions to Vendor',
            color: AppColors.warning,
            onTap: () => _openMapsWithCoords(
              _vendorLat!,
              _vendorLng!,
              '${order.vendorName}, $_vendorArea, Haldwani',
            ),
          )
        else if (!_vendorLoading && _vendorArea.isNotEmpty)
          _buildDirectionButton(
            label: 'Get Directions to Vendor',
            color: AppColors.warning,
            onTap: () =>
                _openMapsWithAddress('${order.vendorName}, $_vendorArea', ''),
          ),
      ],
    );
  }

  // ✅ UPDATED: Customer card ab recipient info bhi dikhata hai
  Widget _buildCustomerCard(OrderModel order) {
    // ✅ Address cleanup: "For: Name\nActual Address" format se name hata do
    String displayAddress = order.address;
    if (_isManualAddress && displayAddress.startsWith('For: ')) {
      final lines = displayAddress.split('\n');
      if (lines.length > 1) {
        displayAddress = lines.sublist(1).join('\n').trim();
      }
    }

    return _InfoCard(
      title: '📍 Customer — Deliver Here',
      accentColor: AppColors.success,
      children: [
        // ✅ NEW: Manual address badge — rider ko pata chale ye GPS nahi hai
        if (_isManualAddress) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.share_location_rounded,
                  color: AppColors.primary,
                  size: 14,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '⚠️ Delivering to a Different Location — Not GPS address',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Orderer info (jo order kiya)
        _InfoRow(
          label: _isManualAddress ? 'Ordered by' : 'Name',
          value: _customerLoading
              ? 'Loading...'
              : _customerName.isNotEmpty
              ? _customerName
              : 'Customer',
        ),

        // Orderer ka phone
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  _isManualAddress ? 'Their No.' : 'Phone',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              Expanded(
                child: _customerLoading
                    ? const Text(
                        'Loading...',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      )
                    : Text(
                        _customerPhone.isNotEmpty ? _customerPhone : 'N/A',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              if (!_customerLoading && _customerPhone.isNotEmpty)
                GestureDetector(
                  onTap: () => _callNumber(_customerPhone),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      // ✅ Grey button — orderer ka phone (secondary)
                      color: _isManualAddress && _recipientPhone.isNotEmpty
                          ? AppColors.textMuted.withOpacity(0.15)
                          : AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: _isManualAddress && _recipientPhone.isNotEmpty
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.call_rounded,
                      color: _isManualAddress && _recipientPhone.isNotEmpty
                          ? AppColors.textMuted
                          : Colors.white,
                      size: 17,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ✅ NEW: Recipient section — sirf tab dikhao jab manual address ho
        if (_isManualAddress) ...[
          const Divider(color: AppColors.border, height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '👤 Deliver To (Recipient)',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 10),

                // Recipient name
                if (_recipientName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 72,
                          child: Text(
                            'Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _recipientName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Name not provided',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFamily: 'Poppins',
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // ✅ Recipient phone — green call button (primary contact)
                if (_recipientPhone.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 72,
                        child: Text(
                          'Call Them',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _recipientPhone,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // ✅ Green button — ye primary call hai rider ke liye
                      GestureDetector(
                        onTap: () => _callNumber(_recipientPhone),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Phone not provided — call the orderer',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'Poppins',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        const Divider(color: AppColors.border, height: 12),
        _InfoRow(label: 'Address', value: displayAddress),
        if (order.landmark.isNotEmpty)
          _InfoRow(label: 'Landmark', value: order.landmark),
        const SizedBox(height: 6),

        _buildDirectionButton(
          label: 'Get Directions to Customer',
          color: AppColors.success,
          onTap: () {
            if (_customerLat != null && _customerLng != null) {
              // GPS coordinates available — most accurate
              _openMapsWithCoords(
                _customerLat!,
                _customerLng!,
                '$_customerName — $displayAddress',
              );
            } else {
              // Old orders fallback — text address se search
              _openMapsWithAddress(displayAddress, order.landmark);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDirectionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_rounded, color: color, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.open_in_new_rounded, color: color, size: 13),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(OrderModel order) {
    return _InfoCard(
      title: '🛍️ Order Items',
      accentColor: AppColors.primary,
      children: order.items.map((item) {
        final portion = item.portion;
        final hasHalf = portion == 'half';
        final hasFull = portion == 'full';
        // Rider ko sirf app price dikhao — vendor price hide
        final displayPrice = item.appPrice > 0 ? item.appPrice : item.price;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasHalf || hasFull) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasHalf
                              ? const Color(0xFF7C3AED)
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          hasHalf ? '🥘 Half Portion' : '🍲 Full Portion',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '₹${(displayPrice * item.quantity).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentCard(OrderModel order) {
    final isOnline = order.paymentMethod == 'online';
    final bool isFreeDelivery = order.deliveryCharge == 0;

    return _InfoCard(
      title: '💵 Payment',
      accentColor: AppColors.primary,
      children: [
        _InfoRow(
          label: 'Subtotal',
          value: '₹${order.subtotal.toStringAsFixed(0)}',
        ),
        if (isFreeDelivery)
          const _InfoRowColored(
            label: 'Delivery',
            value: 'FREE',
            color: AppColors.success,
          )
        else
          _InfoRow(
            label: 'Delivery',
            value: '₹${order.deliveryCharge.toStringAsFixed(0)}',
          ),
        _InfoRow(
          label: 'Platform',
          value: '₹${order.platformFee.toStringAsFixed(0)}',
        ),
        _InfoRow(
          label: 'Packaging',
          value: '₹${order.packagingFee.toStringAsFixed(0)}',
        ),
        if (order.tipAmount > 0)
          _InfoRowColored(
            label: 'Rider Tip',
            value: '+₹${order.tipAmount} 🎉',
            color: AppColors.primary,
          ),
        const Divider(color: AppColors.border, height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isOnline ? 'Total (Paid Online)' : 'Collect Cash',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              '₹${order.total.toStringAsFixed(0)}',
              style: TextStyle(
                color: isOnline ? AppColors.success : AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOnline
                ? AppColors.upiPurple.withOpacity(0.07)
                : AppColors.success.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOnline
                  ? AppColors.upiPurple.withOpacity(0.25)
                  : AppColors.success.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: isOnline ? AppColors.upiPurple : AppColors.success,
                size: 13,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Customer has already paid online. No cash needed.'
                      : 'Collect ₹${order.total.toStringAsFixed(0)} cash. Your ₹${order.deliveryCharge.toStringAsFixed(0)} commission settled on Sunday.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline ? AppColors.upiPurple : AppColors.success,
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(OrderModel order, Map<String, dynamic> nextAction) {
    final isOtp = nextAction['isOtp'] == true;
    final color = nextAction['color'] as Color;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () => _updateStatus(order, nextAction['nextStatus'], isOtp),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    nextAction['label'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupButton(OrderModel order) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _markPickedUp(order.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Picked Up 🛵',
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
    );
  }

  Widget _buildDeliveredBanner(OrderModel order) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        // ✅ NAYA:
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          // ✅ NAYA — const hata do Text se:
          children: [
            const Text('🎉', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              order.tipAmount > 0
                  ? 'Delivered! ₹${order.deliveryCharge.toStringAsFixed(0)} + ₹${order.tipAmount} tip earned! 🎉'
                  : 'Order Delivered! ₹${order.deliveryCharge.toStringAsFixed(0)} earned.',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRowColored extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRowColored({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
