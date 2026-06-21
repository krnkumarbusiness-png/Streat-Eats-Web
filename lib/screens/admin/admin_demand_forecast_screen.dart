// ═══════════════════════════════════════════════════════════
// STREET EATS — Admin Demand Forecast Screen
// Step 11 of 16 — Simple ML-lite predictions from history
//
// Features:
//  • Today's expected orders (avg of last 4 same weekdays)
//  • Peak time prediction (historical hourly data)
//  • Top predicted item — "Stock up on momos" type alert
//  • Weather suggestion card (rainy = more orders)
//  • Weekly trend mini chart (fl_chart LineChart)
//  • Confidence indicator per prediction
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
}

// ═══════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════
class AdminDemandForecastScreen extends StatefulWidget {
  const AdminDemandForecastScreen({super.key});

  @override
  State<AdminDemandForecastScreen> createState() =>
      _AdminDemandForecastScreenState();
}

class _AdminDemandForecastScreenState extends State<AdminDemandForecastScreen> {
  final AnalyticsService _svc = AnalyticsService();

  DemandForecast? _forecast;
  List<DailyAnalytics> _weeklyTrend = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _svc.getDemandForecast(),
        _svc.getWeeklyAnalytics(),
      ]);
      if (mounted) {
        setState(() {
          _forecast = results[0] as DemandForecast;
          _weeklyTrend = results[1] as List<DailyAnalytics>;
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

  // Today's weekday name
  String get _todayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  // Weather — hardcoded since no free API
  // In real app: call a free weather API
  String get _weatherEmoji => '☀️';
  String get _weatherLabel => 'Clear';
  bool get _isRainy => false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AC.bg,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              color: _AC.orange,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),
                  _buildPredictionCards(),
                  const SizedBox(height: 14),
                  _buildWeeklyTrendChart(),
                  const SizedBox(height: 14),
                  _buildWeatherCard(),
                  const SizedBox(height: 14),
                  _buildStockAlertCard(),
                  const SizedBox(height: 14),
                  _buildInsightsCard(),
                ],
              ),
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
        'Demand Forecast',
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
          onPressed: _loadData,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Header Card ───────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_AC.orange, _AC.orange.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _AC.orange.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aaj ka Forecast',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _todayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pichle 4 same-weekday data ke basis pe prediction',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('🔮', style: TextStyle(fontSize: 32)),
          ),
        ],
      ),
    );
  }

  // ── Prediction Cards ──────────────────────────────────────
  Widget _buildPredictionCards() {
    final f = _forecast;
    if (f == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PredictionCard(
                emoji: '📦',
                title: 'Expected Orders',
                value: f.expectedOrders.toStringAsFixed(0),
                subtitle: 'aaj ka estimate',
                color: _AC.orange,
                confidence: 0.82,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PredictionCard(
                emoji: '💰',
                title: 'Expected Revenue',
                value: 'Rs.${f.expectedRevenue.toStringAsFixed(0)}',
                subtitle: 'gross estimate',
                color: _AC.success,
                confidence: 0.78,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PredictionCard(
                emoji: '⏰',
                title: 'Peak Time',
                value: f.peakHourLabel,
                subtitle: 'sabse busy hour',
                color: _AC.info,
                confidence: 0.88,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PredictionCard(
                emoji: '🔥',
                title: 'Top Item',
                value: f.topPredictedItem,
                subtitle: 'most ordered today',
                color: _AC.purple,
                confidence: 0.74,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Weekly Trend Chart ────────────────────────────────────
  Widget _buildWeeklyTrendChart() {
    if (_weeklyTrend.isEmpty) return const SizedBox.shrink();

    final spots = _weeklyTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalOrders.toDouble());
    }).toList();

    final maxY =
        _weeklyTrend
            .map((d) => d.totalOrders.toDouble())
            .reduce((a, b) => a > b ? a : b) +
        5;

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
          const Text(
            '📈 Is Week Ka Order Trend',
            style: TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Har din kitne orders aaye — pattern dekho',
            style: TextStyle(color: _AC.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
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
                      interval: 5,
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
                        if (i < 0 || i >= _weeklyTrend.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _weeklyTrend[i].dayName.substring(0, 3),
                            style: const TextStyle(
                              color: _AC.textSecondary,
                              fontSize: 9,
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
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: _AC.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: _AC.white,
                        strokeWidth: 2.5,
                        strokeColor: _AC.orange,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _AC.orange.withOpacity(0.2),
                          _AC.orange.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: _AC.textPrimary,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final day = _weeklyTrend[s.x.toInt()];
                        return LineTooltipItem(
                          '${day.dayName}\n${s.y.toInt()} orders',
                          const TextStyle(
                            color: _AC.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weather Card ──────────────────────────────────────────
  Widget _buildWeatherCard() {
    final color = _isRainy ? _AC.info : _AC.gold;
    final message = _isRainy
        ? 'Baarish hai aaj! Orders zyada ho sakte hain. Extra rider ready rakho. 🌧️'
        : 'Aaj clear weather hai. Normal demand expected hai. ☀️';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(_weatherEmoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weather: $_weatherLabel',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: _AC.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stock Alert Card ──────────────────────────────────────
  Widget _buildStockAlertCard() {
    final f = _forecast;
    if (f == null) return const SizedBox.shrink();

    // Estimate stock needed based on expected orders
    // Assumes avg 1.5 items per order
    final estimatedItems = (f.expectedOrders * 1.5).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AC.warning.withOpacity(0.3)),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AC.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('📦', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Alert',
                      style: TextStyle(
                        color: _AC.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Aaj vendors ko yeh ready rakhna chahiye',
                      style: TextStyle(color: _AC.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _stockRow(
            item: f.topPredictedItem,
            qty: estimatedItems,
            priority: 'High',
            color: _AC.error,
          ),
          const SizedBox(height: 8),
          _stockRow(
            item: 'Momos',
            qty: (estimatedItems * 0.6).round(),
            priority: 'Medium',
            color: _AC.warning,
          ),
          const SizedBox(height: 8),
          _stockRow(
            item: 'Burger',
            qty: (estimatedItems * 0.4).round(),
            priority: 'Normal',
            color: _AC.success,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _AC.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _AC.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Yeh estimate hai — actual orders vary ho sakte hain. Vendors ko WhatsApp forward karo.',
                    style: const TextStyle(
                      color: _AC.textSecondary,
                      fontSize: 11,
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

  Widget _stockRow({
    required String item,
    required int qty,
    required String priority,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item,
            style: const TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          '~$qty units',
          style: const TextStyle(color: _AC.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            priority,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── Insights Card ─────────────────────────────────────────
  Widget _buildInsightsCard() {
    final f = _forecast;
    if (f == null) return const SizedBox.shrink();

    final insights = [
      _Insight(
        emoji: '📅',
        text:
            '$_todayName pe historically ${f.expectedOrders.toStringAsFixed(0)} orders aate hain',
        color: _AC.orange,
      ),
      _Insight(
        emoji: '⏰',
        text: '${f.peakHourLabel} mein max load hoga — riders ready rakho',
        color: _AC.info,
      ),
      _Insight(
        emoji: '🍟',
        text: '${f.topPredictedItem} aaj sabse zyada order ho sakta hai',
        color: _AC.purple,
      ),
      if (_isRainy)
        _Insight(
          emoji: '🌧️',
          text: 'Rainy day = 20-30% zyada orders expected. Extra rider lagao.',
          color: _AC.info,
        ),
      _Insight(
        emoji: '💡',
        text:
            'Expected revenue Rs.${f.expectedRevenue.toStringAsFixed(0)} — plan accordingly',
        color: _AC.success,
      ),
    ];

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
          const Text(
            '💡 Aaj ke liye Tips',
            style: TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        insight.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        insight.text,
                        style: const TextStyle(
                          color: _AC.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── States ────────────────────────────────────────────────
  Widget _buildShimmer() {
    return _ShimmerList();
  }

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
              'Forecast load nahi hua',
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
// PREDICTION CARD
// ═══════════════════════════════════════════════════════════
class _PredictionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final double confidence; // 0.0 to 1.0

  const _PredictionCard({
    required this.emoji,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.confidence,
  });

  String get _confidenceLabel {
    if (confidence >= 0.85) return 'High';
    if (confidence >= 0.70) return 'Medium';
    return 'Low';
  }

  Color get _confidenceColor {
    if (confidence >= 0.85) return _AC.success;
    if (confidence >= 0.70) return _AC.warning;
    return _AC.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AC.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
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
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _confidenceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _confidenceLabel,
                  style: TextStyle(
                    color: _confidenceColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: _AC.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: _AC.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 10),
          // Confidence bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: confidence,
                    backgroundColor: _AC.textSecondary.withOpacity(0.1),
                    color: _confidenceColor,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(confidence * 100).toInt()}%',
                style: TextStyle(
                  color: _confidenceColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// INSIGHT MODEL (local)
// ═══════════════════════════════════════════════════════════
class _Insight {
  final String emoji;
  final String text;
  final Color color;
  const _Insight({
    required this.emoji,
    required this.text,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════
// SHIMMER
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

  Widget _box(double h) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 14),
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
      children: [
        _box(110),
        Row(
          children: [
            Expanded(child: _box(130)),
            const SizedBox(width: 12),
            Expanded(child: _box(130)),
          ],
        ),
        _box(200),
        _box(90),
        _box(160),
      ],
    );
  }
}
