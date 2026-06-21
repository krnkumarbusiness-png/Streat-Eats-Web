// ═══════════════════════════════════════════════════════════
// STREAT EATS — Admin Daily Report Screen
// Auto-generated end-of-day summary with WhatsApp share
// Step 13 of 16 — admin_daily_report_screen.dart
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../services/analytics_service.dart';

class AdminDailyReportScreen extends StatefulWidget {
  const AdminDailyReportScreen({super.key});

  @override
  State<AdminDailyReportScreen> createState() => _AdminDailyReportScreenState();
}

class _AdminDailyReportScreenState extends State<AdminDailyReportScreen>
    with TickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────
  final AnalyticsService _analyticsService = AnalyticsService();

  // ── State ──────────────────────────────────────────────
  DailyReport? _report;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  // ── Animation ─────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _loadReport();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  Future<void> _loadReport({DateTime? date}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final report = await _analyticsService.getDailyReport(date: date);
      setState(() {
        _report = report;
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
      _slideController.forward(from: 0);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Pick a different date ──────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadReport(date: picked);
    }
  }

  // ── WhatsApp share ─────────────────────────────────────
  Future<void> _shareViaWhatsApp() async {
    if (_report == null) return;
    final text = _report!.shareText;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Report copy ho gaya! WhatsApp mein paste karo 📋'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateLabel = isToday
        ? 'Aaj ka Report'
        : DateFormat('d MMM yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(dateLabel),
      body: _buildBody(),
      floatingActionButton: _report != null ? _buildShareFAB() : null,
    );
  }

  // ── AppBar ────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(String dateLabel) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textDark,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Report',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            dateLabel,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        // Date picker button
        TextButton.icon(
          onPressed: _pickDate,
          icon: const Icon(
            Icons.calendar_today_rounded,
            size: 15,
            color: AppColors.primary,
          ),
          label: const Text(
            'Date',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Body ──────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_report == null) return _buildEmptyState();
    return _buildContent();
  }

  // ── Content ───────────────────────────────────────────
  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _loadReport(date: _selectedDate),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateBanner(),
                const SizedBox(height: 16),
                _buildRevenueCard(),
                const SizedBox(height: 12),
                _buildOrderStatsRow(),
                const SizedBox(height: 12),
                _buildGrowthCard(),
                const SizedBox(height: 20),
                _buildSectionHeader('🏆 Best Performer'),
                const SizedBox(height: 8),
                _buildRiderCard(),
                const SizedBox(height: 12),
                _buildSectionHeader('🔥 Top Item Today'),
                const SizedBox(height: 8),
                _buildTopItemCard(),
                const SizedBox(height: 12),
                _buildSectionHeader('📋 Preview'),
                const SizedBox(height: 8),
                _buildReportPreviewCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Date Banner ───────────────────────────────────────
  Widget _buildDateBanner() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withOpacity(0.08)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withOpacity(0.25)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isToday ? Icons.wb_sunny_rounded : Icons.calendar_month_rounded,
            color: isToday ? AppColors.primary : AppColors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isToday
                ? '${DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)} — Live Data'
                : DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
            style: TextStyle(
              color: isToday ? AppColors.primary : AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenue Card ──────────────────────────────────────
  Widget _buildRevenueCard() {
    final r = _report!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aaj ka Revenue',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs.${r.grossRevenue.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _revenueChip(
                'Net Profit',
                'Rs.${r.netProfit.toStringAsFixed(0)}',
                Colors.white,
              ),
              const SizedBox(width: 12),
              _revenueChip(
                'Platform Fee',
                'Rs.${r.platformFees.toStringAsFixed(0)}',
                Colors.white70,
              ),
              const SizedBox(width: 12),
              _revenueChip(
                'Avg Order',
                r.totalOrders > 0
                    ? 'Rs.${(r.grossRevenue / r.totalOrders).toStringAsFixed(0)}'
                    : 'Rs.0',
                Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _revenueChip(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Order Stats Row ───────────────────────────────────
  Widget _buildOrderStatsRow() {
    final r = _report!;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.primary,
            label: 'Total Orders',
            value: r.totalOrders.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
            label: 'Delivered',
            value: r.deliveredOrders.toString(),
            subLabel: r.totalOrders > 0
                ? '${((r.deliveredOrders / r.totalOrders) * 100).round()}% success'
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.cancel_rounded,
            iconColor: AppColors.error,
            label: 'Cancelled',
            value: r.cancelledOrders.toString(),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Growth Card ───────────────────────────────────────
  Widget _buildGrowthCard() {
    final r = _report!;
    final ordersGrowth = r.ordersGrowthPercent;
    final revenueGrowth = r.revenueGrowthPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'vs Yesterday',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _growthTile(
                  label: 'Orders',
                  current: r.totalOrders.toString(),
                  yesterday: r.yesterdayOrders.toString(),
                  growthPercent: ordersGrowth,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey.withOpacity(0.15),
              ),
              Expanded(
                child: _growthTile(
                  label: 'Revenue',
                  current: 'Rs.${r.grossRevenue.toStringAsFixed(0)}',
                  yesterday: 'Rs.${r.yesterdayRevenue.toStringAsFixed(0)}',
                  growthPercent: revenueGrowth,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _growthTile({
    required String label,
    required String current,
    required String yesterday,
    required double growthPercent,
  }) {
    final isPositive = growthPercent >= 0;
    final growthColor = isPositive ? AppColors.success : AppColors.error;
    final growthIcon = isPositive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
    final sign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(growthIcon, color: growthColor, size: 14),
              const SizedBox(width: 3),
              Text(
                '$sign${growthPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: growthColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Was $yesterday',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Section Header ────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        letterSpacing: -0.2,
      ),
    );
  }

  // ── Rider Card ────────────────────────────────────────
  Widget _buildRiderCard() {
    final r = _report!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.bestRiderName == 'N/A' ? 'Koi rider nahi' : r.bestRiderName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  r.bestRiderName == 'N/A'
                      ? 'Aaj koi order deliver nahi hua'
                      : '${r.bestRiderOrders} orders delivered today',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (r.bestRiderOrders > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.4),
                ),
              ),
              child: Text(
                '${r.bestRiderOrders} orders',
                style: const TextStyle(
                  color: Color(0xFFB8860B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Top Item Card ─────────────────────────────────────
  Widget _buildTopItemCard() {
    final r = _report!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.topItemName == 'N/A' ? 'Koi data nahi' : r.topItemName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  r.topItemName == 'N/A'
                      ? 'Aaj koi item sell nahi hua'
                      : '${r.topItemCount} times ordered today',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (r.topItemCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Text(
                '${r.topItemCount}x sold',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Report Preview Card ───────────────────────────────
  Widget _buildReportPreviewCard() {
    final r = _report!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.preview_rounded,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'WhatsApp Report Preview',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _shareViaWhatsApp,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            r.shareText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.7,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ── Share FAB ─────────────────────────────────────────
  Widget _buildShareFAB() {
    return FloatingActionButton.extended(
      onPressed: _shareViaWhatsApp,
      backgroundColor: const Color(0xFF25D366),
      elevation: 4,
      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
      label: const Text(
        'WhatsApp pe Share Karo',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  // ── Loading State ─────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
          const SizedBox(height: 16),
          const Text(
            'Report load ho rahi hai...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Error State ───────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😵', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Kuch gadbad ho gayi!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadReport(date: _selectedDate),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Dobara Try Karo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            const Text(
              'Is din ka koi data nahi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Is date pe koi order nahi tha ya app band thi.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
              ),
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text(
                'Aur date choose karo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
