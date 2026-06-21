// lib/screens/admin/admin_affiliate_ledger_screen.dart
// v1.0 — Affiliate Ledger
// ✅ orders table se affiliate_commission_logged > 0 wale orders fetch karo
// ✅ affiliate_name ke hisaab se group karo
// ✅ Total Orders, Total Commission Owed dikhao
// ✅ "Mark as Paid" button — commission_paid: true mark karo
// ✅ Paid affiliates alag section mein dikhao
// ✅ Light theme: primary #FF6B35, bg #FFF8F0, surface #FFFFFF

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';

class AdminAffiliateLedgerScreen extends StatefulWidget {
  const AdminAffiliateLedgerScreen({super.key});

  @override
  State<AdminAffiliateLedgerScreen> createState() =>
      _AdminAffiliateLedgerScreenState();
}

class _AdminAffiliateLedgerScreenState extends State<AdminAffiliateLedgerScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  // Grouped data: affiliate name → {orders, totalCommission, isPaid}
  List<_AffiliateEntry> _unpaidEntries = [];
  List<_AffiliateEntry> _paidEntries = [];
  bool _isLoading = true;
  late TabController _tabController;

  // Light theme colors (checkout screen se match)
  static const _bgColor = Color(0xFFFFF8F0);
  static const _surfaceColor = Color(0xFFFFFFFF);
  static const _primaryColor = Color(0xFFFF6B35);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textMuted = Color(0xFF6B7280);
  static const _successColor = Color(0xFF16A34A);
  static const _warningColor = Color(0xFFD97706);
  static const _borderColor = Color(0xFFE5E7EB);
  static const _affiliateColor = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLedger();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all orders jahan affiliate commission logged hai
      final data = await _supabase
          .from('orders')
          .select(
            'id, applied_promo_code, affiliate_commission_logged, commission_paid, created_at, total, status',
          )
          .gt('affiliate_commission_logged', 0)
          .order('created_at', ascending: false);

      final orders = List<Map<String, dynamic>>.from(data);

      // affiliate_name fetch karo offers table se (code ke basis pe)
      // Pehle unique codes collect karo
      final codes = orders
          .map((o) => o['applied_promo_code'] as String?)
          .where((c) => c != null && c.isNotEmpty)
          .toSet()
          .toList();

      Map<String, String> codeToAffiliate = {};
      if (codes.isNotEmpty) {
        final offersData = await _supabase
            .from('offers')
            .select('code, affiliate_name')
            .inFilter('code', codes);

        for (final offer in offersData as List) {
          final code = offer['code'] as String? ?? '';
          final name = offer['affiliate_name'] as String? ?? code;
          codeToAffiliate[code] = name.isNotEmpty ? name : code;
        }
      }

      // Group by affiliate name
      final Map<String, _AffiliateEntryBuilder> grouped = {};

      for (final order in orders) {
        final code = order['applied_promo_code'] as String? ?? 'Unknown';
        final affiliateName =
            codeToAffiliate[code] ?? code; // fallback to code if no name
        final commission =
            (order['affiliate_commission_logged'] as num?)?.toDouble() ?? 0;
        final isPaid = order['commission_paid'] as bool? ?? false;
        final orderId = order['id'] as String;
        final orderStatus = order['status'] as String? ?? '';
        final orderTotal = (order['total'] as num?)?.toDouble() ?? 0;
        final createdAt = order['created_at'] as String?;

        final key = affiliateName;
        grouped.putIfAbsent(
          key,
          () => _AffiliateEntryBuilder(name: affiliateName, code: code),
        );

        grouped[key]!.orders.add(
          _OrderEntry(
            orderId: orderId,
            commission: commission,
            isPaid: isPaid,
            orderStatus: orderStatus,
            orderTotal: orderTotal,
            createdAt: createdAt,
          ),
        );
      }

      // Build entries and separate paid/unpaid
      final unpaid = <_AffiliateEntry>[];
      final paid = <_AffiliateEntry>[];

      grouped.forEach((name, builder) {
        final entry = builder.build();
        // Agar koi bhi unpaid order hai toh unpaid mein
        if (entry.unpaidCommission > 0) {
          unpaid.add(entry);
        } else {
          paid.add(entry);
        }
      });

      // Sort by unpaid commission (highest first)
      unpaid.sort((a, b) => b.unpaidCommission.compareTo(a.unpaidCommission));
      paid.sort((a, b) => b.totalCommission.compareTo(a.totalCommission));

      if (mounted) {
        setState(() {
          _unpaidEntries = unpaid;
          _paidEntries = paid;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Load failed: $e', isError: true);
      }
    }
  }

  Future<void> _markAsPaid(_AffiliateEntry entry) async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.payment_rounded,
                    color: _successColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mark as Paid?',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: _textMuted,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: entry.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _affiliateColor,
                      ),
                    ),
                    const TextSpan(text: ' ko '),
                    TextSpan(
                      text: '₹${entry.unpaidCommission.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _successColor,
                        fontSize: 15,
                      ),
                    ),
                    const TextSpan(text: ' UPI se pay kar diya? Confirm karo.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textMuted,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Confirm Paid',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                        ),
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

    if (confirm != true) return;

    // Un sabhi orders ko commission_paid: true mark karo
    // jo is affiliate ke unpaid orders hain
    try {
      final unpaidOrderIds = entry.orders
          .where((o) => !o.isPaid)
          .map((o) => o.orderId)
          .toList();

      if (unpaidOrderIds.isNotEmpty) {
        await _supabase
            .from('orders')
            .update({'commission_paid': true})
            .inFilter('id', unpaidOrderIds);
      }

      _snack('${entry.name} ko paid mark kar diya! ✅');
      await _loadLedger();
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalOwed = _unpaidEntries.fold<double>(
      0,
      (sum, e) => sum + e.unpaidCommission,
    );
    final totalAffiliates = _unpaidEntries.length + _paidEntries.length;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Affiliate Ledger',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadLedger,
            icon: const Icon(Icons.refresh_rounded, color: _primaryColor),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _borderColor),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2.5,
              ),
            )
          : Column(
              children: [
                // ── Summary Stats ──────────────────────────────
                _buildSummaryBar(totalOwed, totalAffiliates),

                // ── Tabs ───────────────────────────────────────
                Container(
                  color: _surfaceColor,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: _primaryColor,
                    unselectedLabelColor: _textMuted,
                    indicatorColor: _primaryColor,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(text: 'Owed (${_unpaidEntries.length})'),
                      Tab(text: 'Paid (${_paidEntries.length})'),
                    ],
                  ),
                ),
                Container(height: 1, color: _borderColor),

                // ── Tab Content ────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1 — Owed (unpaid)
                      _unpaidEntries.isEmpty
                          ? _buildEmptyState(
                              '🎉 Sab Clear!',
                              'Koi pending commission nahi hai.',
                            )
                          : RefreshIndicator(
                              color: _primaryColor,
                              onRefresh: _loadLedger,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  24,
                                ),
                                itemCount: _unpaidEntries.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) => _buildAffiliateCard(
                                  _unpaidEntries[i],
                                  isPaidSection: false,
                                ),
                              ),
                            ),

                      // Tab 2 — Paid
                      _paidEntries.isEmpty
                          ? _buildEmptyState(
                              'Koi Paid Affiliate Nahi',
                              'Abhi tak kisi affiliate ko payment nahi hua.',
                            )
                          : RefreshIndicator(
                              color: _primaryColor,
                              onRefresh: _loadLedger,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  24,
                                ),
                                itemCount: _paidEntries.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) => _buildAffiliateCard(
                                  _paidEntries[i],
                                  isPaidSection: true,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar(double totalOwed, int totalAffiliates) {
    return Container(
      color: _surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _statCard(
            icon: Icons.person_pin_rounded,
            label: 'Total Affiliates',
            value: '$totalAffiliates',
            color: _affiliateColor,
          ),
          const SizedBox(width: 10),
          _statCard(
            icon: Icons.pending_actions_rounded,
            label: 'Pending',
            value: '${_unpaidEntries.length}',
            color: _warningColor,
          ),
          const SizedBox(width: 10),
          _statCard(
            icon: Icons.currency_rupee_rounded,
            label: 'Total Owed',
            value: '₹${totalOwed.toStringAsFixed(0)}',
            color: _primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAffiliateCard(
    _AffiliateEntry entry, {
    required bool isPaidSection,
  }) {
    final displayCommission = isPaidSection
        ? entry.totalCommission
        : entry.unpaidCommission;
    final orderCount = isPaidSection
        ? entry.totalOrders
        : entry.orders.where((o) => !o.isPaid).length;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaidSection
              ? _successColor.withOpacity(0.2)
              : _affiliateColor.withOpacity(0.2),
        ),
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
          // ── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPaidSection
                  ? _successColor.withOpacity(0.04)
                  : _affiliateColor.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isPaidSection
                      ? _successColor.withOpacity(0.15)
                      : _affiliateColor.withOpacity(0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPaidSection
                        ? _successColor.withOpacity(0.1)
                        : _affiliateColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isPaidSection ? _successColor : _affiliateColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _affiliateColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.code,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _affiliateColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPaidSection)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _successColor.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: _successColor,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Paid',
                          style: TextStyle(
                            color: _successColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Stats Row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoChip(
                      icon: Icons.receipt_long_rounded,
                      label: 'Orders',
                      value: '$orderCount',
                      color: _primaryColor,
                    ),
                    const SizedBox(width: 10),
                    _infoChip(
                      icon: Icons.currency_rupee_rounded,
                      label: isPaidSection ? 'Total Paid' : 'Commission Owed',
                      value: '₹${displayCommission.toStringAsFixed(0)}',
                      color: isPaidSection ? _successColor : _warningColor,
                      highlight: !isPaidSection,
                    ),
                    if (!isPaidSection && entry.paidCommission > 0) ...[
                      const SizedBox(width: 10),
                      _infoChip(
                        icon: Icons.check_rounded,
                        label: 'Already Paid',
                        value: '₹${entry.paidCommission.toStringAsFixed(0)}',
                        color: _successColor,
                      ),
                    ],
                  ],
                ),

                // ── Mark as Paid button (only in unpaid tab) ──
                if (!isPaidSection) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsPaid(entry),
                      icon: const Icon(
                        Icons.payments_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Mark as Paid  ₹${entry.unpaidCommission.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Recent Orders list (collapsed) ────────────
                if (entry.orders.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        'Order Details (${entry.totalOrders})',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textMuted,
                        ),
                      ),
                      iconColor: _textMuted,
                      collapsedIconColor: _textMuted,
                      children: [
                        const SizedBox(height: 4),
                        ...entry.orders.take(10).map((o) => _buildOrderRow(o)),
                        if (entry.orders.length > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '+ ${entry.orders.length - 10} more orders',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _textMuted,
                              ),
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
    );
  }

  Widget _buildOrderRow(_OrderEntry order) {
    final shortId = order.orderId.length > 8
        ? order.orderId.substring(order.orderId.length - 8).toUpperCase()
        : order.orderId.toUpperCase();

    final date = order.createdAt != null ? _formatDate(order.createdAt!) : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: order.isPaid ? _successColor.withOpacity(0.04) : _bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: order.isPaid ? _successColor.withOpacity(0.2) : _borderColor,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag, size: 12, color: _textMuted),
          const SizedBox(width: 4),
          Text(
            shortId,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: _textMuted,
            ),
          ),
          const Spacer(),
          Text(
            '₹${order.orderTotal.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: _textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: order.isPaid
                  ? _successColor.withOpacity(0.1)
                  : _warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '₹${order.commission.toStringAsFixed(0)} ${order.isPaid ? '✓' : '⏳'}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: order.isPaid ? _successColor : _warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? color.withOpacity(0.08) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(highlight ? 0.3 : 0.15),
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: highlight ? 15 : 13,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: _textMuted,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '--';
    }
  }

  Widget _buildEmptyState(String title, String sub) {
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
                color: _primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_pin_rounded,
                color: _primaryColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data Models (internal) ────────────────────────────────────

class _OrderEntry {
  final String orderId;
  final double commission;
  final bool isPaid;
  final String orderStatus;
  final double orderTotal;
  final String? createdAt;

  _OrderEntry({
    required this.orderId,
    required this.commission,
    required this.isPaid,
    required this.orderStatus,
    required this.orderTotal,
    this.createdAt,
  });
}

class _AffiliateEntry {
  final String name;
  final String code;
  final List<_OrderEntry> orders;

  _AffiliateEntry({
    required this.name,
    required this.code,
    required this.orders,
  });

  int get totalOrders => orders.length;
  double get totalCommission => orders.fold(0, (sum, o) => sum + o.commission);
  double get unpaidCommission =>
      orders.where((o) => !o.isPaid).fold(0, (sum, o) => sum + o.commission);
  double get paidCommission =>
      orders.where((o) => o.isPaid).fold(0, (sum, o) => sum + o.commission);
}

class _AffiliateEntryBuilder {
  final String name;
  final String code;
  final List<_OrderEntry> orders = [];

  _AffiliateEntryBuilder({required this.name, required this.code});

  _AffiliateEntry build() =>
      _AffiliateEntry(name: name, code: code, orders: orders);
}
