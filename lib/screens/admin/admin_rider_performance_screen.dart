// ═══════════════════════════════════════════════════════════
// STREET EATS — Admin Rider Performance Screen
// Step 10 of 16 — Per-rider stats + leaderboard + charts
//
// Features:
//  • Tab 1 — Today: per-rider card with orders, cash, timing
//  • Tab 2 — Leaderboard: weekly rank by orders delivered
//  • Tab 3 — Details: tap any rider → full stats breakdown
//  • Bar chart: avg delivery time per rider (fl_chart)
//  • Performance badge per rider (Top Rider / Good / Average)
//  • Date picker for historical view
//  • Pull-to-refresh on every tab
//  • Light theme (admin panel)
//  • Loading shimmer + error + empty states
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/analytics_service.dart';
// RiderPerformance model yahi hai

// ─────────────────────────────────────────────────────────
// LOCAL COLOR CONSTANTS
// ─────────────────────────────────────────────────────────
class _AC {
  static const Color bg = Color(0xFFF5F6FA);
  static const Color white = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF7A7F9A);
  static const Color orange = Color(0xFFFF6B2B);
  static const Color gold = Color(0xFFFFD700);
  static const Color success = Color(0xFF00C48C);
  static const Color error = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF2979FF);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
}

// ═══════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════
class AdminRiderPerformanceScreen extends StatefulWidget {
  const AdminRiderPerformanceScreen({super.key});

  @override
  State<AdminRiderPerformanceScreen> createState() =>
      _AdminRiderPerformanceScreenState();
}

class _AdminRiderPerformanceScreenState
    extends State<AdminRiderPerformanceScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _svc = AnalyticsService();
  late TabController _tabController;

  // Today stats
  List<RiderPerformance> _todayPerformance = [];
  bool _todayLoading = true;
  String? _todayError;

  // Leaderboard (this week)
  List<RiderPerformance> _leaderboard = [];
  bool _leaderboardLoading = false;
  String? _leaderboardError;
  bool _leaderboardLoaded = false;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1 && !_leaderboardLoaded) {
          _loadLeaderboard();
        }
      }
    });
    _loadToday();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Loaders ──────────────────────────────────────────────

  Future<void> _loadToday() async {
    setState(() {
      _todayLoading = true;
      _todayError = null;
    });
    try {
      final data = await _svc.getRiderPerformance(date: _selectedDate);
      if (mounted) {
        setState(() {
          _todayPerformance = data;
          _todayLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _todayError = e.toString();
          _todayLoading = false;
        });
      }
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _leaderboardLoading = true;
      _leaderboardError = null;
    });
    try {
      // Leaderboard = weekly data (no date filter → service returns this week)
      final data = await _svc.getRiderPerformance();
      // Sort by weekly orders descending
      data.sort((a, b) => b.ordersThisWeek.compareTo(a.ordersThisWeek));
      if (mounted) {
        setState(() {
          _leaderboard = data;
          _leaderboardLoading = false;
          _leaderboardLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leaderboardError = e.toString();
          _leaderboardLoading = false;
        });
      }
    }
  }

  void _refreshCurrent() {
    switch (_tabController.index) {
      case 0:
        _loadToday();
        break;
      case 1:
        _leaderboardLoaded = false;
        _loadLeaderboard();
        break;
      case 2:
        _loadToday(); // Charts tab uses same today data
        break;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _AC.orange)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadToday();
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ── Summary stats ─────────────────────────────────────
  int get _totalOrdersToday =>
      _todayPerformance.fold(0, (s, r) => s + r.ordersToday);

  double get _avgDeliveryTime {
    if (_todayPerformance.isEmpty) return 0;
    final sum = _todayPerformance.fold(0.0, (s, r) => s + r.avgDeliveryMinutes);
    return sum / _todayPerformance.length;
  }

  String? get _bestRider {
    if (_todayPerformance.isEmpty) return null;
    final top = _todayPerformance.reduce(
      (a, b) => a.ordersToday > b.ordersToday ? a : b,
    );
    return top.riderName;
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AC.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSummaryBanner(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TodayTab(
                  riders: _todayPerformance,
                  isLoading: _todayLoading,
                  error: _todayError,
                  onRefresh: _loadToday,
                ),
                _LeaderboardTab(
                  riders: _leaderboard,
                  isLoading: _leaderboardLoading,
                  error: _leaderboardError,
                  onRefresh: () {
                    _leaderboardLoaded = false;
                    _loadLeaderboard();
                  },
                ),
                _ChartsTab(
                  riders: _todayPerformance,
                  isLoading: _todayLoading,
                  error: _todayError,
                  onRefresh: _loadToday,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _AC.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _AC.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rider Performance',
            style: TextStyle(
              color: _AC.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            _isToday ? 'Today' : DateFormat('d MMM yyyy').format(_selectedDate),
            style: const TextStyle(
              color: _AC.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.calendar_today_rounded,
            color: _AC.orange,
            size: 20,
          ),
          onPressed: _pickDate,
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: _AC.textSecondary,
            size: 22,
          ),
          onPressed: _refreshCurrent,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Summary Banner ────────────────────────────────────────
  Widget _buildSummaryBanner() {
    if (_todayLoading || _todayPerformance.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      color: _AC.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _chip(
            label: 'Active Riders',
            value: '${_todayPerformance.length}',
            color: _AC.info,
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Total Orders',
            value: '$_totalOrdersToday',
            color: _AC.orange,
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Avg Time',
            value: '${_avgDeliveryTime.toStringAsFixed(0)} min',
            color: _avgDeliveryTime <= 30 ? _AC.success : _AC.warning,
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Best Rider',
            value: _bestRider ?? 'N/A',
            color: _AC.gold,
            isText: true,
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required String value,
    required Color color,
    bool isText = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: isText ? 10 : 14,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(
                color: _AC.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TabBar ────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _AC.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _AC.orange,
        unselectedLabelColor: _AC.textSecondary,
        indicatorColor: _AC.orange,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: '📋 Today'),
          Tab(text: '🏆 Leaderboard'),
          Tab(text: '📊 Charts'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 1 — TODAY
// Per-rider cards with full stats for selected date
// ═══════════════════════════════════════════════════════════
class _TodayTab extends StatelessWidget {
  final List<RiderPerformance> riders;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _TodayTab({
    required this.riders,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (riders.isEmpty) {
      return const _EmptyState(
        icon: '🛵',
        title: 'Koi rider active nahi',
        subtitle: 'Is date ke liye koi delivery data nahi mila',
      );
    }

    // Sort by orders today desc
    final sorted = [...riders]
      ..sort((a, b) => b.ordersToday.compareTo(a.ordersToday));

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: sorted.length,
        itemBuilder: (ctx, i) => _RiderCard(rider: sorted[i], rank: i + 1),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 2 — LEADERBOARD
// Weekly ranked list of riders
// ═══════════════════════════════════════════════════════════
class _LeaderboardTab extends StatelessWidget {
  final List<RiderPerformance> riders;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _LeaderboardTab({
    required this.riders,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (riders.isEmpty) {
      return const _EmptyState(
        icon: '🏆',
        title: 'Leaderboard khali hai',
        subtitle: 'Is week abhi koi orders nahi hai',
      );
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: riders.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _LeaderboardPodium(
                riders: riders.length >= 3 ? riders.sublist(0, 3) : riders,
              ),
            );
          }
          final rider = riders[i - 1];
          return _LeaderboardRow(rider: rider, rank: i);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 3 — CHARTS
// Bar charts: avg delivery time + orders per rider
// ═══════════════════════════════════════════════════════════
class _ChartsTab extends StatelessWidget {
  final List<RiderPerformance> riders;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _ChartsTab({
    required this.riders,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (riders.isEmpty) {
      return const _EmptyState(
        icon: '📊',
        title: 'Chart data nahi hai',
        subtitle: 'Pehle riders ko orders assign karo',
      );
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          _DeliveryTimeChart(riders: riders),
          const SizedBox(height: 16),
          _OrdersBarChart(riders: riders),
          const SizedBox(height: 16),
          _OnTimeRateChart(riders: riders),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// RIDER CARD — Today tab main card
// ═══════════════════════════════════════════════════════════
class _RiderCard extends StatefulWidget {
  final RiderPerformance rider;
  final int rank;

  const _RiderCard({required this.rider, required this.rank});

  @override
  State<_RiderCard> createState() => _RiderCardState();
}

class _RiderCardState extends State<_RiderCard> {
  bool _expanded = false;

  Color get _badgeColor {
    switch (widget.rider.performanceBadge) {
      case '🏆 Top Rider':
        return _AC.gold;
      case '⭐ Good':
        return _AC.success;
      case '👍 Average':
        return _AC.info;
      default:
        return _AC.error;
    }
  }

  Color get _onTimeColor {
    if (widget.rider.onTimeRate >= 90) return _AC.success;
    if (widget.rider.onTimeRate >= 75) return _AC.warning;
    return _AC.error;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rider;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _badgeColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Rank + avatar
                      Stack(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _badgeColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                r.riderName.isNotEmpty
                                    ? r.riderName[0].toUpperCase()
                                    : 'R',
                                style: TextStyle(
                                  color: _badgeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _badgeColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _AC.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${widget.rank}',
                                  style: const TextStyle(
                                    color: _AC.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Name + badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.riderName,
                              style: const TextStyle(
                                color: _AC.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                r.performanceBadge,
                                style: TextStyle(
                                  color: _badgeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Orders today
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${r.ordersToday}',
                            style: const TextStyle(
                              color: _AC.orange,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          ),
                          const Text(
                            'aaj',
                            style: TextStyle(
                              color: _AC.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: _AC.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── 4 stat boxes ──────────────────────
                  Row(
                    children: [
                      _statBox(
                        label: 'Avg Time',
                        value: '${r.avgDeliveryMinutes.toStringAsFixed(0)} min',
                        color: r.avgDeliveryMinutes <= 30
                            ? _AC.success
                            : _AC.warning,
                      ),
                      _statBox(
                        label: 'On Time',
                        value: '${r.onTimeRate.toStringAsFixed(0)}%',
                        color: _onTimeColor,
                      ),
                      _statBox(
                        label: 'This Week',
                        value: '${r.ordersThisWeek}',
                        color: _AC.info,
                      ),
                      _statBox(
                        label: 'Earnings',
                        value: 'Rs.${r.totalEarningsWeek.toStringAsFixed(0)}',
                        color: _AC.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Expanded Detail ──────────────────────────
            if (_expanded) ...[
              const Divider(height: 1, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // On-time rate progress bar
                    _ProgressRow(
                      label: 'On-Time Delivery Rate',
                      value: r.onTimeRate / 100,
                      valueLabel: '${r.onTimeRate.toStringAsFixed(1)}%',
                      color: _onTimeColor,
                    ),
                    const SizedBox(height: 10),
                    // Detail rows
                    _detailRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Orders today',
                      value: '${r.ordersToday}',
                    ),
                    _detailRow(
                      icon: Icons.date_range_rounded,
                      label: 'Orders this week',
                      value: '${r.ordersThisWeek}',
                    ),
                    _detailRow(
                      icon: Icons.timer_outlined,
                      label: 'Avg delivery time',
                      value: '${r.avgDeliveryMinutes.toStringAsFixed(1)} min',
                    ),
                    _detailRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'On-time deliveries',
                      value: '${r.onTimeRate.toStringAsFixed(0)}% orders',
                    ),
                    _detailRow(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Earnings this week',
                      value: 'Rs.${r.totalEarningsWeek.toStringAsFixed(0)}',
                      valueColor: _AC.success,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: _AC.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _AC.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _AC.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _AC.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _AC.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LEADERBOARD PODIUM — Top 3 riders
// ═══════════════════════════════════════════════════════════
class _LeaderboardPodium extends StatelessWidget {
  final List<RiderPerformance> riders;
  const _LeaderboardPodium({required this.riders});

  @override
  Widget build(BuildContext context) {
    // Arrange: 2nd, 1st, 3rd
    final first = riders.isNotEmpty ? riders[0] : null;
    final second = riders.length > 1 ? riders[1] : null;
    final third = riders.length > 2 ? riders[2] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_AC.orange.withOpacity(0.08), _AC.gold.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AC.gold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text(
            '🏆 This Week Top Performers',
            style: TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2nd place
              if (second != null)
                _PodiumSlot(
                  rider: second,
                  rank: 2,
                  height: 70,
                  color: _AC.silver,
                  emoji: '🥈',
                ),
              const SizedBox(width: 8),
              // 1st place
              if (first != null)
                _PodiumSlot(
                  rider: first,
                  rank: 1,
                  height: 90,
                  color: _AC.gold,
                  emoji: '🥇',
                ),
              const SizedBox(width: 8),
              // 3rd place
              if (third != null)
                _PodiumSlot(
                  rider: third,
                  rank: 3,
                  height: 55,
                  color: _AC.bronze,
                  emoji: '🥉',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final RiderPerformance rider;
  final int rank;
  final double height;
  final Color color;
  final String emoji;

  const _PodiumSlot({
    required this.rider,
    required this.rank,
    required this.height,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              rider.riderName.isNotEmpty
                  ? rider.riderName[0].toUpperCase()
                  : 'R',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rider.riderName.split(' ').first,
          style: const TextStyle(
            color: _AC.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${rider.ordersThisWeek} orders',
          style: const TextStyle(color: _AC.textSecondary, fontSize: 9),
        ),
        const SizedBox(height: 6),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LEADERBOARD ROW — Rank 4+ list items
// ═══════════════════════════════════════════════════════════
class _LeaderboardRow extends StatelessWidget {
  final RiderPerformance rider;
  final int rank;
  const _LeaderboardRow({required this.rider, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isTop3 ? _AC.orange : _AC.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _AC.orange.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rider.riderName.isNotEmpty
                    ? rider.riderName[0].toUpperCase()
                    : 'R',
                style: const TextStyle(
                  color: _AC.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.riderName,
                  style: const TextStyle(
                    color: _AC.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  rider.performanceBadge,
                  style: const TextStyle(
                    color: _AC.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Orders this week
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${rider.ordersThisWeek}',
                style: const TextStyle(
                  color: _AC.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Text(
                'orders',
                style: TextStyle(color: _AC.textSecondary, fontSize: 10),
              ),
            ],
          ),
          // On-time badge
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rider.onTimeRate >= 90
                  ? _AC.success.withOpacity(0.1)
                  : rider.onTimeRate >= 75
                  ? _AC.warning.withOpacity(0.1)
                  : _AC.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${rider.onTimeRate.toStringAsFixed(0)}%',
              style: TextStyle(
                color: rider.onTimeRate >= 90
                    ? _AC.success
                    : rider.onTimeRate >= 75
                    ? _AC.warning
                    : _AC.error,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DELIVERY TIME BAR CHART
// ═══════════════════════════════════════════════════════════
class _DeliveryTimeChart extends StatelessWidget {
  final List<RiderPerformance> riders;
  const _DeliveryTimeChart({required this.riders});

  @override
  Widget build(BuildContext context) {
    final maxY =
        riders
            .map((r) => r.avgDeliveryMinutes)
            .reduce((a, b) => a > b ? a : b) +
        10;

    return _ChartCard(
      title: '⏱ Avg Delivery Time (min)',
      subtitle: 'Ek order deliver karne mein avg kitna time laga',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 10,
              getDrawingHorizontalLine: (_) => FlLine(
                color: _AC.textSecondary.withOpacity(0.1),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 10,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= riders.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        riders[i].riderName.split(' ').first,
                        style: const TextStyle(
                          color: _AC.textSecondary,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            barGroups: riders.asMap().entries.map((e) {
              final i = e.key;
              final rider = e.value;
              final isGood = rider.avgDeliveryMinutes <= 30;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: rider.avgDeliveryMinutes,
                    color: isGood ? _AC.success : _AC.warning,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: _AC.textSecondary.withOpacity(0.06),
                    ),
                  ),
                ],
              );
            }).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: _AC.textPrimary,
                getTooltipItem: (group, _, rod, __) {
                  final rider = riders[group.x];
                  return BarTooltipItem(
                    '${rider.riderName}\n${rod.toY.toStringAsFixed(1)} min',
                    const TextStyle(
                      color: _AC.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ORDERS BAR CHART (today's orders per rider)
// ═══════════════════════════════════════════════════════════
class _OrdersBarChart extends StatelessWidget {
  final List<RiderPerformance> riders;
  const _OrdersBarChart({required this.riders});

  @override
  Widget build(BuildContext context) {
    final maxY =
        (riders
                    .map((r) => r.ordersToday.toDouble())
                    .reduce((a, b) => a > b ? a : b) +
                2)
            .toDouble();

    return _ChartCard(
      title: '📦 Orders Delivered Today',
      subtitle: 'Har rider ne aaj kitne orders complete kiye',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: _AC.textSecondary.withOpacity(0.1),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 2,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= riders.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        riders[i].riderName.split(' ').first,
                        style: const TextStyle(
                          color: _AC.textSecondary,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            barGroups: riders.asMap().entries.map((e) {
              final i = e.key;
              final rider = e.value;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: rider.ordersToday.toDouble(),
                    gradient: LinearGradient(
                      colors: [_AC.orange, _AC.orange.withOpacity(0.6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: _AC.textSecondary.withOpacity(0.06),
                    ),
                  ),
                ],
              );
            }).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: _AC.textPrimary,
                getTooltipItem: (group, _, rod, __) {
                  final rider = riders[group.x];
                  return BarTooltipItem(
                    '${rider.riderName}\n${rod.toY.toInt()} orders',
                    const TextStyle(
                      color: _AC.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ON-TIME RATE HORIZONTAL BARS
// ═══════════════════════════════════════════════════════════
class _OnTimeRateChart extends StatelessWidget {
  final List<RiderPerformance> riders;
  const _OnTimeRateChart({required this.riders});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: '✅ On-Time Delivery Rate',
      subtitle: '30 min ke andar deliver = on-time. Target: 90%+',
      child: Column(
        children: riders.map((r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProgressRow(
              label: r.riderName,
              value: r.onTimeRate / 100,
              valueLabel: '${r.onTimeRate.toStringAsFixed(0)}%',
              color: r.onTimeRate >= 90
                  ? _AC.success
                  : r.onTimeRate >= 75
                  ? _AC.warning
                  : _AC.error,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: _AC.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value; // 0.0 to 1.0
  final String valueLabel;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: _AC.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: _AC.textSecondary.withOpacity(0.1),
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            valueLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── Shimmer List ──────────────────────────────────────────
class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double h) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value, 0),
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_box(140), _box(140), _box(140)],
    );
  }
}

// ── Error State ───────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: _AC.error.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data load nahi hua',
              style: TextStyle(
                color: _AC.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(color: _AC.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Karo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AC.orange,
                foregroundColor: _AC.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: _AC.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
