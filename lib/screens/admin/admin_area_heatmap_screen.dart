// ═══════════════════════════════════════════════════════════
// STREET EATS — Admin Area Heatmap Screen
// Step 12 of 16 — Order density by area, NO maps API
//
// Features:
//  • Color-coded area cards (hot / active / low / untapped)
//  • Total orders + revenue + avg delivery time per area
//  • Intensity bar — visual density indicator
//  • "Never Ordered" areas — marketing targets
//  • Sort by: Orders / Revenue / Delivery Time
//  • Summary stats banner at top
//  • Pull-to-refresh
//  • Light theme (admin panel)
//  • Loading shimmer + error + empty states
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';

// ─────────────────────────────────────────────────────────
// LOCAL COLORS
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
  static const Color purple = Color(0xFF7C4DFF);
  static const Color grey = Color(0xFFA0A8C0);
}

// Intensity → color mapping
extension IntensityColor on AreaHeatmap {
  Color get intensityColorValue {
    switch (intensity) {
      case 'high':
        return _AC.error;
      case 'medium':
        return _AC.orange;
      case 'low':
        return _AC.success;
      default:
        return _AC.grey; // untapped / new
    }
  }

  String get intensityEmoji {
    switch (intensity) {
      case 'high':
        return '🔥';
      case 'medium':
        return '⚡';
      case 'low':
        return '📍';
      default:
        return '🆕';
    }
  }
}

// ─────────────────────────────────────────────────────────
// SORT ENUM
// ─────────────────────────────────────────────────────────
enum _SortBy { orders, revenue, deliveryTime }

// ═══════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════
class AdminAreaHeatmapScreen extends StatefulWidget {
  const AdminAreaHeatmapScreen({super.key});

  @override
  State<AdminAreaHeatmapScreen> createState() => _AdminAreaHeatmapScreenState();
}

class _AdminAreaHeatmapScreenState extends State<AdminAreaHeatmapScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _svc = AnalyticsService();
  late TabController _tabController;

  List<AreaHeatmap> _areas = [];
  bool _isLoading = true;
  String? _error;
  _SortBy _sortBy = _SortBy.orders;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _svc.getAreaHeatmap();
      if (mounted) {
        setState(() {
          _areas = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ── Sorted list ───────────────────────────────────────────
  List<AreaHeatmap> get _sortedAreas {
    final sorted = [..._areas];
    switch (_sortBy) {
      case _SortBy.orders:
        sorted.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
        break;
      case _SortBy.revenue:
        sorted.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
        break;
      case _SortBy.deliveryTime:
        sorted.sort((a, b) => a.avgDeliveryMin.compareTo(b.avgDeliveryMin));
        break;
    }
    return sorted;
  }

  // Active areas only (ordered at least once)
  List<AreaHeatmap> get _activeAreas =>
      _sortedAreas.where((a) => a.totalOrders > 0).toList();

  // Untapped areas (never ordered)
  List<AreaHeatmap> get _untappedAreas =>
      _sortedAreas.where((a) => a.totalOrders == 0).toList();

  // Summary stats
  int get _totalOrders => _areas.fold(0, (s, a) => s + a.totalOrders);

  double get _totalRevenue => _areas.fold(0.0, (s, a) => s + a.totalRevenue);

  double get _avgDelivery {
    final active = _areas.where((a) => a.avgDeliveryMin > 0).toList();
    if (active.isEmpty) return 0;
    return active.fold(0.0, (s, a) => s + a.avgDeliveryMin) / active.length;
  }

  String? get _hotArea {
    if (_areas.isEmpty) return null;
    final hot = _areas.reduce((a, b) => a.totalOrders > b.totalOrders ? a : b);
    return hot.area;
  }

  int get _maxOrders => _areas.isEmpty
      ? 1
      : _areas.map((a) => a.totalOrders).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AC.bg,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const _ShimmerList()
          : _error != null
          ? _buildError()
          : Column(
              children: [
                _buildSummaryBanner(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildHeatmapTab(), _buildChartTab()],
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
      title: const Text(
        'Area Heatmap',
        style: TextStyle(
          color: _AC.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        // Sort button
        PopupMenuButton<_SortBy>(
          icon: const Icon(Icons.sort_rounded, color: _AC.orange, size: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (val) => setState(() => _sortBy = val),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _SortBy.orders,
              child: Text('Sort: Orders'),
            ),
            const PopupMenuItem(
              value: _SortBy.revenue,
              child: Text('Sort: Revenue'),
            ),
            const PopupMenuItem(
              value: _SortBy.deliveryTime,
              child: Text('Sort: Delivery Time'),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: _AC.textSecondary,
            size: 22,
          ),
          onPressed: _loadData,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Summary Banner ────────────────────────────────────────
  Widget _buildSummaryBanner() {
    if (_areas.isEmpty) return const SizedBox.shrink();

    return Container(
      color: _AC.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _chip(
            label: 'Total Orders',
            value: '$_totalOrders',
            color: _AC.orange,
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Revenue',
            value: 'Rs.${_totalRevenue.toStringAsFixed(0)}',
            color: _AC.success,
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Avg Time',
            value: '${_avgDelivery.toStringAsFixed(0)} min',
            color: _avgDelivery <= 30 ? _AC.success : _AC.warning,
          ),
          const SizedBox(width: 8),
          _chip(
            label: '🔥 Hot Area',
            value: _hotArea ?? 'N/A',
            color: _AC.error,
            small: true,
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required String value,
    required Color color,
    bool small = false,
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
                fontSize: small ? 9 : 13,
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
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: '🗺 Area Cards'),
          Tab(text: '📊 Bar Chart'),
        ],
      ),
    );
  }

  // ── Tab 1: Heatmap Cards ──────────────────────────────────
  Widget _buildHeatmapTab() {
    if (_areas.isEmpty) {
      return const _EmptyState(
        icon: '🗺',
        title: 'Koi area data nahi',
        subtitle: 'Jab orders aayenge tab areas yahan dikhenge',
      );
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // Legend
          _buildLegend(),
          const SizedBox(height: 14),

          // Active areas
          if (_activeAreas.isNotEmpty) ...[
            _SectionLabel(
              label: 'Active Areas (${_activeAreas.length})',
              subtitle: 'Yahan se orders aa rahe hain',
            ),
            const SizedBox(height: 10),
            ..._activeAreas.map(
              (area) => _AreaCard(area: area, maxOrders: _maxOrders),
            ),
            const SizedBox(height: 6),
          ],

          // Untapped areas
          if (_untappedAreas.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionLabel(
              label: 'Untapped Areas (${_untappedAreas.length})',
              subtitle: 'Yahan marketing karo — orders nahi aaye abhi tak',
            ),
            const SizedBox(height: 10),
            ..._untappedAreas.map((area) => _UntappedAreaCard(area: area)),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Bar Chart ──────────────────────────────────────
  Widget _buildChartTab() {
    final active = _activeAreas;
    if (active.isEmpty) {
      return const _EmptyState(
        icon: '📊',
        title: 'Chart data nahi hai',
        subtitle: 'Pehle kuch orders aane do',
      );
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          _AreaOrdersChart(areas: active),
          const SizedBox(height: 16),
          _AreaRevenueChart(areas: active),
          const SizedBox(height: 16),
          _AreaDeliveryChart(areas: active),
        ],
      ),
    );
  }

  // ── Legend ────────────────────────────────────────────────
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AC.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem('🔥', 'Hot', _AC.error),
          _legendItem('⚡', 'Active', _AC.orange),
          _legendItem('📍', 'Low', _AC.success),
          _legendItem('🆕', 'Untapped', _AC.grey),
        ],
      ),
    );
  }

  Widget _legendItem(String emoji, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Error ─────────────────────────────────────────────────
  Widget _buildError() {
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
              _error ?? 'Unknown error',
              style: const TextStyle(color: _AC.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
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

// ═══════════════════════════════════════════════════════════
// AREA CARD — Active area with full stats
// ═══════════════════════════════════════════════════════════
class _AreaCard extends StatefulWidget {
  final AreaHeatmap area;
  final int maxOrders;

  const _AreaCard({required this.area, required this.maxOrders});

  @override
  State<_AreaCard> createState() => _AreaCardState();
}

class _AreaCardState extends State<_AreaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.area;
    final color = a.intensityColorValue;
    final ratio = widget.maxOrders > 0 ? a.totalOrders / widget.maxOrders : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
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
            // ── Main Row ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Intensity icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            a.intensityEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Area name + label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.area,
                              style: const TextStyle(
                                color: _AC.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                a.intensityLabel,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Orders count
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${a.totalOrders}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          const Text(
                            'orders',
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
                  // Density progress bar
                  Row(
                    children: [
                      const Text(
                        'Density',
                        style: TextStyle(
                          color: _AC.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            backgroundColor: _AC.textSecondary.withOpacity(0.1),
                            color: color,
                            minHeight: 7,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(ratio * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
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
                    Row(
                      children: [
                        _statTile(
                          label: 'Revenue',
                          value: 'Rs.${a.totalRevenue.toStringAsFixed(0)}',
                          color: _AC.success,
                        ),
                        _statTile(
                          label: 'Avg Order',
                          value: a.totalOrders > 0
                              ? 'Rs.${(a.totalRevenue / a.totalOrders).toStringAsFixed(0)}'
                              : 'N/A',
                          color: _AC.orange,
                        ),
                        _statTile(
                          label: 'Avg Delivery',
                          value: '${a.avgDeliveryMin.toStringAsFixed(0)} min',
                          color: a.avgDeliveryMin <= 30
                              ? _AC.success
                              : _AC.warning,
                        ),
                      ],
                    ),
                    if (a.lastOrderDate != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: _AC.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Last order: ${_formatDate(a.lastOrderDate!)}',
                            style: const TextStyle(
                              color: _AC.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Marketing tip for low areas
                    if (a.intensity == 'low') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _AC.info.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _AC.info.withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: _AC.info,
                              size: 14,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Yahan Instagram ads try karo — low activity area hai',
                                style: TextStyle(color: _AC.info, fontSize: 11),
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
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(color: _AC.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Aaj';
    if (diff == 1) return 'Kal';
    return '$diff din pehle';
  }
}

// ═══════════════════════════════════════════════════════════
// UNTAPPED AREA CARD
// ═══════════════════════════════════════════════════════════
class _UntappedAreaCard extends StatelessWidget {
  final AreaHeatmap area;
  const _UntappedAreaCard({required this.area});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _AC.grey.withOpacity(0.3),
          style: BorderStyle.solid,
        ),
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _AC.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🆕', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.area,
                  style: const TextStyle(
                    color: _AC.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Text(
                  'Koi order nahi — marketing opportunity!',
                  style: TextStyle(color: _AC.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _AC.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Target 🎯',
              style: TextStyle(
                color: _AC.info,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AREA ORDERS BAR CHART
// ═══════════════════════════════════════════════════════════
class _AreaOrdersChart extends StatelessWidget {
  final List<AreaHeatmap> areas;
  const _AreaOrdersChart({required this.areas});

  @override
  Widget build(BuildContext context) {
    final maxY =
        areas
            .map((a) => a.totalOrders.toDouble())
            .reduce((a, b) => a > b ? a : b) +
        5;

    return _ChartCard(
      title: '📦 Orders by Area',
      subtitle: 'Har area se kitne orders aaye total',
      child: SizedBox(
        height: 200,
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
                  reservedSize: 30,
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
                    if (i < 0 || i >= areas.length) {
                      return const SizedBox.shrink();
                    }
                    // Short area name
                    final name = areas[i].area;
                    final short = name.length > 8
                        ? '${name.substring(0, 7)}.'
                        : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        short,
                        style: const TextStyle(
                          color: _AC.textSecondary,
                          fontSize: 8,
                        ),
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
            barGroups: areas.asMap().entries.map((e) {
              final i = e.key;
              final area = e.value;
              final color = area.intensityColorValue;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: area.totalOrders.toDouble(),
                    color: color,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: _AC.textSecondary.withOpacity(0.05),
                    ),
                  ),
                ],
              );
            }).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: _AC.textPrimary,
                getTooltipItem: (group, _, rod, __) {
                  final area = areas[group.x];
                  return BarTooltipItem(
                    '${area.area}\n${rod.toY.toInt()} orders',
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
// AREA REVENUE BAR CHART
// ═══════════════════════════════════════════════════════════
class _AreaRevenueChart extends StatelessWidget {
  final List<AreaHeatmap> areas;
  const _AreaRevenueChart({required this.areas});

  @override
  Widget build(BuildContext context) {
    final maxY =
        areas.map((a) => a.totalRevenue).reduce((a, b) => a > b ? a : b) + 50;

    return _ChartCard(
      title: '💰 Revenue by Area',
      subtitle: 'Har area ne kitna revenue generate kiya',
      child: SizedBox(
        height: 200,
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
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    'Rs.${v.toInt()}',
                    style: const TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= areas.length) {
                      return const SizedBox.shrink();
                    }
                    final name = areas[i].area;
                    final short = name.length > 8
                        ? '${name.substring(0, 7)}.'
                        : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        short,
                        style: const TextStyle(
                          color: _AC.textSecondary,
                          fontSize: 8,
                        ),
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
            barGroups: areas.asMap().entries.map((e) {
              final i = e.key;
              final area = e.value;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: area.totalRevenue,
                    gradient: LinearGradient(
                      colors: [_AC.success, _AC.success.withOpacity(0.6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    width: 20,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: _AC.textSecondary.withOpacity(0.05),
                    ),
                  ),
                ],
              );
            }).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: _AC.textPrimary,
                getTooltipItem: (group, _, rod, __) {
                  final area = areas[group.x];
                  return BarTooltipItem(
                    '${area.area}\nRs.${rod.toY.toStringAsFixed(0)}',
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
// AREA DELIVERY TIME CHART (horizontal progress bars)
// ═══════════════════════════════════════════════════════════
class _AreaDeliveryChart extends StatelessWidget {
  final List<AreaHeatmap> areas;
  const _AreaDeliveryChart({required this.areas});

  @override
  Widget build(BuildContext context) {
    // Sort by delivery time ascending
    final sorted = [...areas]
      ..sort((a, b) => a.avgDeliveryMin.compareTo(b.avgDeliveryMin));

    final maxTime = sorted.isEmpty
        ? 30.0
        : sorted.map((a) => a.avgDeliveryMin).reduce((a, b) => a > b ? a : b);

    return _ChartCard(
      title: '⏱ Avg Delivery Time by Area',
      subtitle: 'Kam time = better service. Target: under 30 min',
      child: Column(
        children: sorted.map((area) {
          final ratio = maxTime > 0 ? area.avgDeliveryMin / maxTime : 0.0;
          final color = area.avgDeliveryMin <= 25
              ? _AC.success
              : area.avgDeliveryMin <= 30
              ? _AC.warning
              : _AC.error;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 85,
                  child: Text(
                    area.area,
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
                      value: ratio.clamp(0.0, 1.0),
                      backgroundColor: _AC.textSecondary.withOpacity(0.1),
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${area.avgDeliveryMin.toStringAsFixed(0)} min',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
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

class _SectionLabel extends StatelessWidget {
  final String label;
  final String subtitle;

  const _SectionLabel({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _AC.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: _AC.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────
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
      margin: const EdgeInsets.only(bottom: 10),
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
      children: [_box(50), _box(100), _box(100), _box(100), _box(80), _box(80)],
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
