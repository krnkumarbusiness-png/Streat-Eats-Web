// ═══════════════════════════════════════════════════════════
// STREAT EATS — Admin Analytics Hub Screen
// Single screen linking all 8 analytics features
// Step 14 of 16 — admin_analytics_hub_screen.dart
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../services/analytics_service.dart';
import 'admin_float_management_screen.dart';
import 'admin_order_analytics_screen.dart';
import 'admin_item_analytics_screen.dart';
import 'admin_rider_performance_screen.dart';
import 'admin_demand_forecast_screen.dart';
import 'admin_area_heatmap_screen.dart';
import 'admin_daily_report_screen.dart';

class AdminAnalyticsHubScreen extends StatefulWidget {
  const AdminAnalyticsHubScreen({super.key});

  @override
  State<AdminAnalyticsHubScreen> createState() =>
      _AdminAnalyticsHubScreenState();
}

class _AdminAnalyticsHubScreenState extends State<AdminAnalyticsHubScreen>
    with SingleTickerProviderStateMixin {
  // ── Quick Stats (live) ────────────────────────────────
  final AnalyticsService _analyticsService = AnalyticsService();
  TodayAnalytics? _quickStats;
  bool _statsLoading = true;

  // ── Animation ─────────────────────────────────────────
  late AnimationController _animController;

  // ── Hub Feature List ──────────────────────────────────
  // Defined as data so adding new features = just add here
  late final List<_HubFeature> _features;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _features = [
      _HubFeature(
        emoji: '💰',
        title: 'Float Management',
        subtitle: 'Rider cash & settlement tracking',
        color: const Color(0xFF00C48C),
        onTap: () => _navigate(const AdminFloatManagementScreen()),
      ),
      _HubFeature(
        emoji: '📊',
        title: 'Order Analytics',
        subtitle: 'Today / Weekly / Monthly trends',
        color: AppColors.primary,
        onTap: () => _navigate(const AdminOrderAnalyticsScreen()),
      ),
      _HubFeature(
        emoji: '🍟',
        title: 'Item Analytics',
        subtitle: 'Top selling & trending items',
        color: const Color(0xFFFF6B6B),
        onTap: () => _navigate(const AdminItemAnalyticsScreen()),
      ),
      _HubFeature(
        emoji: '🛵',
        title: 'Rider Performance',
        subtitle: 'Delivery stats & leaderboard',
        color: const Color(0xFF4ECDC4),
        onTap: () => _navigate(const AdminRiderPerformanceScreen()),
      ),
      _HubFeature(
        emoji: '🔮',
        title: 'Demand Forecast',
        subtitle: 'Expected orders & peak time',
        color: const Color(0xFF9B59B6),
        onTap: () => _navigate(const AdminDemandForecastScreen()),
      ),
      _HubFeature(
        emoji: '🗺️',
        title: 'Area Heatmap',
        subtitle: 'Order density by locality',
        color: const Color(0xFFE67E22),
        onTap: () => _navigate(const AdminAreaHeatmapScreen()),
      ),
      _HubFeature(
        emoji: '📋',
        title: 'Daily Report',
        subtitle: 'End-of-day summary & WhatsApp share',
        color: const Color(0xFF25D366),
        onTap: () => _navigate(const AdminDailyReportScreen()),
      ),
    ];

    _loadQuickStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  Future<void> _loadQuickStats() async {
    try {
      final stats = await _analyticsService.getTodayAnalytics();
      if (mounted) {
        setState(() {
          _quickStats = stats;
          _statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: _buildQuickStatsBar(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: _buildFeatureGrid(),
          ),
        ],
      ),
    );
  }

  // ── Sliver AppBar ─────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textDark,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
        title: const Text(
          'Analytics Hub',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        background: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          color: AppColors.primary,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Streat Eats Command Center',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  // ── Quick Stats Bar ───────────────────────────────────
  Widget _buildQuickStatsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
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
      child: _statsLoading
          ? const Center(
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Aaj ka data load ho raha hai...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickStat(
                  '📦',
                  'Orders',
                  _quickStats?.totalOrders.toString() ?? '—',
                ),
                _quickStatDivider(),
                _quickStat(
                  '💰',
                  'Revenue',
                  'Rs.${_quickStats?.grossRevenue.toStringAsFixed(0) ?? '—'}',
                ),
                _quickStatDivider(),
                _quickStat(
                  '📈',
                  'Net Profit',
                  'Rs.${_quickStats?.netProfit.toStringAsFixed(0) ?? '—'}',
                ),
              ],
            ),
    );
  }

  Widget _quickStat(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _quickStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.2),
    );
  }

  // ── Feature Grid ──────────────────────────────────────
  Widget _buildFeatureGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final feature = _features[index];
        // Staggered animation
        final delay = index * 0.08;
        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(
              ((_animController.value - delay).clamp(0.0, 1.0) /
                      (1.0 - delay).clamp(0.01, 1.0))
                  .clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - t)),
                child: child,
              ),
            );
          },
          child: _FeatureCard(feature: feature),
        );
      }, childCount: _features.length),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Feature Card Widget
// ═══════════════════════════════════════════════════════════

class _FeatureCard extends StatefulWidget {
  final _HubFeature feature;
  const _FeatureCard({required this.feature});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.feature.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji icon in colored circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.feature.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    widget.feature.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const Spacer(),
              // Title
              Text(
                widget.feature.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Subtitle
              Text(
                widget.feature.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Bottom arrow bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: widget.feature.color.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: widget.feature.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: widget.feature.color,
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
}

// ═══════════════════════════════════════════════════════════
// Data Class
// ═══════════════════════════════════════════════════════════

class _HubFeature {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _HubFeature({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
