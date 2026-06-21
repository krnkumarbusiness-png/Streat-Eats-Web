// ═══════════════════════════════════════════════════════════
// STREET EATS — Admin Order Analytics Screen
// Step 8 of 16 — Today / Weekly / Monthly analytics tabs
//
// Features:
//  • Tab 1 — Today: total orders, gross revenue, net profit,
//    avg order value, orders-by-hour bar chart,
//    orders-by-area horizontal bar list
//  • Tab 2 — Weekly: day-wise bar chart, best day highlight,
//    revenue trend, week-over-week growth %
//  • Tab 3 — Monthly: summary cards, best week, growth vs
//    last month, profit margin
//  • fl_chart for all graphs
//  • Pull-to-refresh on every tab
//  • Light theme (admin panel)
//  • Loading shimmer + error + empty states
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';

// ─────────────────────────────────────────────────────────
// LOCAL COLOR PALETTE (light admin theme)
// ─────────────────────────────────────────────────────────
class _AC {
  static const Color bg = Color(0xFFF5F6FA);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF7A7F9A);
  static const Color success = Color(0xFF00C48C);
  static const Color error = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF2979FF);
  static const Color orange = Color(0xFFFF6B2B);
  static const Color gold = Color(0xFFFFD700);
}

// ═══════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════
class AdminOrderAnalyticsScreen extends StatefulWidget {
  const AdminOrderAnalyticsScreen({super.key});

  @override
  State<AdminOrderAnalyticsScreen> createState() =>
      _AdminOrderAnalyticsScreenState();
}

class _AdminOrderAnalyticsScreenState extends State<AdminOrderAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _svc = AnalyticsService();
  late TabController _tabController;

  // Today state
  TodayAnalytics? _todayData;
  List<HourlyOrder> _hourlyOrders = [];
  List<AreaOrder> _areaOrders = [];
  bool _todayLoading = true;
  String? _todayError;

  // Weekly state
  List<DailyAnalytics> _weeklyData = [];
  bool _weeklyLoading = true;
  String? _weeklyError;

  // Monthly state
  MonthlyAnalytics? _monthlyData;
  bool _monthlyLoading = true;
  String? _monthlyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case 0:
            if (_todayData == null) _loadToday();
            break;
          case 1:
            if (_weeklyData.isEmpty) _loadWeekly();
            break;
          case 2:
            if (_monthlyData == null) _loadMonthly();
            break;
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

  // ─── Loaders ─────────────────────────────────────────────
  Future<void> _loadToday() async {
    setState(() {
      _todayLoading = true;
      _todayError = null;
    });
    try {
      final results = await Future.wait([
        _svc.getTodayAnalytics(),
        _svc.getOrdersByHour(),
        _svc.getOrdersByArea(),
      ]);
      if (mounted) {
        setState(() {
          _todayData = results[0] as TodayAnalytics;
          _hourlyOrders = results[1] as List<HourlyOrder>;
          _areaOrders = results[2] as List<AreaOrder>;
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

  Future<void> _loadWeekly() async {
    setState(() {
      _weeklyLoading = true;
      _weeklyError = null;
    });
    try {
      final data = await _svc.getWeeklyAnalytics();
      if (mounted) {
        setState(() {
          _weeklyData = data;
          _weeklyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weeklyError = e.toString();
          _weeklyLoading = false;
        });
      }
    }
  }

  Future<void> _loadMonthly() async {
    setState(() {
      _monthlyLoading = true;
      _monthlyError = null;
    });
    try {
      final data = await _svc.getMonthlyAnalytics();
      if (mounted) {
        setState(() {
          _monthlyData = data;
          _monthlyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _monthlyError = e.toString();
          _monthlyLoading = false;
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
        _loadWeekly();
        break;
      case 2:
        _loadMonthly();
        break;
    }
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AC.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TodayTab(
                  data: _todayData,
                  hourly: _hourlyOrders,
                  area: _areaOrders,
                  isLoading: _todayLoading,
                  error: _todayError,
                  onRefresh: _loadToday,
                ),
                _WeeklyTab(
                  data: _weeklyData,
                  isLoading: _weeklyLoading,
                  error: _weeklyError,
                  onRefresh: _loadWeekly,
                ),
                _MonthlyTab(
                  data: _monthlyData,
                  isLoading: _monthlyLoading,
                  error: _monthlyError,
                  onRefresh: _loadMonthly,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
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
      title: const Text(
        'Order Analytics',
        style: TextStyle(
          color: _AC.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
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

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _AC.orange,
        unselectedLabelColor: _AC.textSecondary,
        indicatorColor: _AC.orange,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'Weekly'),
          Tab(text: 'Monthly'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TODAY TAB
// ═══════════════════════════════════════════════════════════
class _TodayTab extends StatelessWidget {
  final TodayAnalytics? data;
  final List<HourlyOrder> hourly;
  final List<AreaOrder> area;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _TodayTab({
    required this.data,
    required this.hourly,
    required this.area,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (data == null) {
      return const _EmptyState(message: 'Aaj ka data nahi mila');
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // ── 4 stat cards ──────────────────────────────────
          _SectionLabel(label: 'Aaj ka Summary'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Orders',
                  value: '${data!.totalOrders}',
                  icon: Icons.receipt_long_rounded,
                  color: _AC.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Gross Revenue',
                  value: 'Rs.${data!.grossRevenue.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee_rounded,
                  color: _AC.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Net Profit',
                  value: 'Rs.${data!.netProfit.toStringAsFixed(0)}',
                  icon: Icons.trending_up_rounded,
                  color: _AC.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Avg Order',
                  value: 'Rs.${data!.avgOrderValue.toStringAsFixed(0)}',
                  icon: Icons.bar_chart_rounded,
                  color: _AC.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Platform fee row
          _InfoRow(
            label: 'Platform Fees',
            value: 'Rs.${data!.platformFees.toStringAsFixed(0)}',
          ),
          _InfoRow(
            label: 'Vendor Cost',
            value: 'Rs.${data!.totalVendorCost.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 20),

          // ── Orders by Hour chart ───────────────────────────
          if (hourly.isNotEmpty) ...[
            _SectionLabel(label: 'Orders by Hour (5 PM – 9 PM)'),
            const SizedBox(height: 12),
            _HourlyBarChart(data: hourly),
            const SizedBox(height: 20),
          ],

          // ── Orders by Area ─────────────────────────────────
          if (area.isNotEmpty) ...[
            _SectionLabel(label: 'Orders by Area'),
            const SizedBox(height: 10),
            ...area.map(
              (a) => _AreaRow(area: a, maxOrders: area.first.orderCount),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// WEEKLY TAB
// ═══════════════════════════════════════════════════════════
class _WeeklyTab extends StatelessWidget {
  final List<DailyAnalytics> data;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _WeeklyTab({
    required this.data,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  DailyAnalytics? get _bestDay {
    if (data.isEmpty) return null;
    return data.reduce((a, b) => a.totalOrders > b.totalOrders ? a : b);
  }

  int get _totalWeekOrders => data.fold(0, (s, d) => s + d.totalOrders);
  double get _totalWeekRevenue => data.fold(0.0, (s, d) => s + d.grossRevenue);
  double get _totalWeekProfit => data.fold(0.0, (s, d) => s + d.netProfit);

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (data.isEmpty) {
      return const _EmptyState(message: 'Is week ka data nahi hai abhi');
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // ── Week summary cards ─────────────────────────────
          _SectionLabel(label: 'Is Hafte ka Summary'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Orders',
                  value: '$_totalWeekOrders',
                  icon: Icons.receipt_long_rounded,
                  color: _AC.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Revenue',
                  value: 'Rs.${_totalWeekRevenue.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee_rounded,
                  color: _AC.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Net Profit',
                  value: 'Rs.${_totalWeekProfit.toStringAsFixed(0)}',
                  icon: Icons.trending_up_rounded,
                  color: _AC.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Best day highlight ─────────────────────────────
          if (_bestDay != null) _BestDayCard(day: _bestDay!),
          const SizedBox(height: 20),

          // ── Orders bar chart ───────────────────────────────
          _SectionLabel(label: 'Din-wise Orders'),
          const SizedBox(height: 12),
          _WeeklyBarChart(data: data),
          const SizedBox(height: 20),

          // ── Revenue line chart ─────────────────────────────
          _SectionLabel(label: 'Revenue Trend'),
          const SizedBox(height: 12),
          _WeeklyLineChart(data: data),
          const SizedBox(height: 20),

          // ── Day breakdown table ────────────────────────────
          _SectionLabel(label: 'Din-wise Breakdown'),
          const SizedBox(height: 10),
          _DayBreakdownTable(data: data),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// MONTHLY TAB
// ═══════════════════════════════════════════════════════════
class _MonthlyTab extends StatelessWidget {
  final MonthlyAnalytics? data;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _MonthlyTab({
    required this.data,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (data == null) {
      return const _EmptyState(message: 'Is mahine ka data nahi hai abhi');
    }

    final d = data!;
    final isGrowthPositive = d.growthPercent >= 0;

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // ── Main stat cards ────────────────────────────────
          _SectionLabel(label: 'Is Mahine ka Summary'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Orders',
                  value: '${d.totalOrders}',
                  icon: Icons.receipt_long_rounded,
                  color: _AC.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Revenue',
                  value: 'Rs.${d.grossRevenue.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee_rounded,
                  color: _AC.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Net Profit',
                  value: 'Rs.${d.netProfit.toStringAsFixed(0)}',
                  icon: Icons.trending_up_rounded,
                  color: _AC.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Best Week',
                  value: 'Week ${d.bestWeekNumber.toInt()}',
                  icon: Icons.star_rounded,
                  color: _AC.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Growth vs last month ───────────────────────────
          _SectionLabel(label: 'Pichle Mahine se Compare'),
          const SizedBox(height: 10),
          _GrowthCard(
            currentOrders: d.totalOrders,
            lastOrders: d.lastMonthOrders,
            currentRevenue: d.grossRevenue,
            lastRevenue: d.lastMonthRevenue,
            growthPercent: d.growthPercent,
            isPositive: isGrowthPositive,
          ),
          const SizedBox(height: 20),

          // ── Profit margin card ─────────────────────────────
          _SectionLabel(label: 'Profit Margin'),
          const SizedBox(height: 10),
          _ProfitMarginCard(
            grossRevenue: d.grossRevenue,
            netProfit: d.netProfit,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CHART WIDGETS
// ═══════════════════════════════════════════════════════════

// ── Hourly Bar Chart ─────────────────────────────────────
class _HourlyBarChart extends StatelessWidget {
  final List<HourlyOrder> data;
  const _HourlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data
        .map((e) => e.orderCount.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxY + 2).ceilToDouble(),
          minY: 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${rod.toY.toInt()} orders',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[idx].hourLabel,
                      style: const TextStyle(
                        color: _AC.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: _AC.textSecondary, fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: _AC.textSecondary.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            data.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].orderCount.toDouble(),
                  color: _AC.orange,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Weekly Bar Chart ─────────────────────────────────────
class _WeeklyBarChart extends StatelessWidget {
  final List<DailyAnalytics> data;
  const _WeeklyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data
        .map((e) => e.totalOrders.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final bestOrders = data
        .map((e) => e.totalOrders)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxY + 2).ceilToDouble(),
          minY: 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${rod.toY.toInt()} orders\nRs.${data[group.x].grossRevenue.toStringAsFixed(0)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[idx].dayName.length >= 3
                          ? data[idx].dayName.substring(0, 3)
                          : data[idx].dayName,
                      style: const TextStyle(
                        color: _AC.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: _AC.textSecondary, fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: _AC.textSecondary.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            data.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].totalOrders.toDouble(),
                  // Best day = gold, rest = orange
                  color: data[i].totalOrders == bestOrders
                      ? _AC.gold
                      : _AC.orange,
                  width: 26,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Weekly Revenue Line Chart ─────────────────────────────
class _WeeklyLineChart extends StatelessWidget {
  final List<DailyAnalytics> data;
  const _WeeklyLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data
        .map((e) => e.grossRevenue)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      'Rs.${s.y.toStringAsFixed(0)}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[idx].dayName.length >= 3
                          ? data[idx].dayName.substring(0, 3)
                          : data[idx].dayName,
                      style: const TextStyle(
                        color: _AC.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: _AC.textSecondary.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.length,
                (i) => FlSpot(i.toDouble(), data[i].grossRevenue),
              ),
              isCurved: true,
              color: _AC.success,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: _AC.success,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _AC.success.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REUSABLE CARD WIDGETS
// ═══════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _AC.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Area Row ──────────────────────────────────────────────
class _AreaRow extends StatelessWidget {
  final AreaOrder area;
  final int maxOrders;

  const _AreaRow({required this.area, required this.maxOrders});

  @override
  Widget build(BuildContext context) {
    final ratio = maxOrders > 0 ? area.orderCount / maxOrders : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  area.area,
                  style: const TextStyle(
                    color: _AC.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${area.orderCount} orders',
                style: const TextStyle(
                  color: _AC.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rs.${area.revenue.toStringAsFixed(0)}',
                style: const TextStyle(color: _AC.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: _AC.textSecondary.withOpacity(0.1),
            color: _AC.orange,
            borderRadius: BorderRadius.circular(4),
            minHeight: 5,
          ),
        ],
      ),
    );
  }
}

// ── Best Day Card ─────────────────────────────────────────
class _BestDayCard extends StatelessWidget {
  final DailyAnalytics day;
  const _BestDayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_AC.orange, _AC.orange.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Best Day This Week',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.dayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${day.totalOrders} orders',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Rs.${day.grossRevenue.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Day Breakdown Table ───────────────────────────────────
class _DayBreakdownTable extends StatelessWidget {
  final List<DailyAnalytics> data;
  const _DayBreakdownTable({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Din',
                    style: TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Orders',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Revenue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Profit',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(data.length, (i) {
            final d = data[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          d.dayName,
                          style: const TextStyle(
                            color: _AC.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${d.totalOrders}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _AC.info,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Rs.${d.grossRevenue.toStringAsFixed(0)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _AC.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Rs.${d.netProfit.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: _AC.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < data.length - 1)
                  const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Growth Card ───────────────────────────────────────────
class _GrowthCard extends StatelessWidget {
  final int currentOrders;
  final int lastOrders;
  final double currentRevenue;
  final double lastRevenue;
  final double growthPercent;
  final bool isPositive;

  const _GrowthCard({
    required this.currentOrders,
    required this.lastOrders,
    required this.currentRevenue,
    required this.lastRevenue,
    required this.growthPercent,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final growthColor = isPositive ? _AC.success : _AC.error;
    final growthIcon = isPositive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          // Growth badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: growthColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(growthIcon, color: growthColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$sign${growthPercent.toStringAsFixed(1)}% vs last month',
                      style: TextStyle(
                        color: growthColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Comparison rows
          Row(
            children: [
              _CompareColumn(
                label: 'Is Mahine',
                orders: currentOrders,
                revenue: currentRevenue,
                highlight: true,
              ),
              Container(
                width: 1,
                height: 60,
                color: _AC.textSecondary.withOpacity(0.15),
              ),
              _CompareColumn(
                label: 'Pichla Mahina',
                orders: lastOrders,
                revenue: lastRevenue,
                highlight: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareColumn extends StatelessWidget {
  final String label;
  final int orders;
  final double revenue;
  final bool highlight;

  const _CompareColumn({
    required this.label,
    required this.orders,
    required this.revenue,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? _AC.orange : _AC.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$orders',
            style: TextStyle(
              color: highlight ? _AC.textPrimary : _AC.textSecondary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'orders',
            style: const TextStyle(color: _AC.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs.${revenue.toStringAsFixed(0)}',
            style: TextStyle(
              color: highlight ? _AC.orange : _AC.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profit Margin Card ────────────────────────────────────
class _ProfitMarginCard extends StatelessWidget {
  final double grossRevenue;
  final double netProfit;

  const _ProfitMarginCard({
    required this.grossRevenue,
    required this.netProfit,
  });

  double get _margin => grossRevenue > 0 ? (netProfit / grossRevenue) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    final marginColor = _margin >= 30
        ? _AC.success
        : _margin >= 20
        ? _AC.warning
        : _AC.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profit Margin',
                style: TextStyle(
                  color: _AC.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_margin.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: marginColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_margin / 100).clamp(0.0, 1.0),
              backgroundColor: _AC.textSecondary.withOpacity(0.1),
              color: marginColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revenue Rs.${grossRevenue.toStringAsFixed(0)} → Profit Rs.${netProfit.toStringAsFixed(0)}',
            style: const TextStyle(color: _AC.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: _AC.textSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _AC.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _AC.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STATE WIDGETS
// ═══════════════════════════════════════════════════════════

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

  Widget _shimmerBox(double height) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
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
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _shimmerBox(24),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _shimmerBox(90)),
            const SizedBox(width: 10),
            Expanded(child: _shimmerBox(90)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _shimmerBox(90)),
            const SizedBox(width: 10),
            Expanded(child: _shimmerBox(90)),
          ],
        ),
        const SizedBox(height: 20),
        _shimmerBox(200),
        const SizedBox(height: 20),
        _shimmerBox(160),
      ],
    );
  }
}

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
                foregroundColor: Colors.white,
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

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 56,
            color: _AC.textSecondary.withOpacity(0.35),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: _AC.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
