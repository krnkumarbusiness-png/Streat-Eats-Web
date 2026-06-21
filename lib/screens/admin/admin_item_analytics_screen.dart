// ═══════════════════════════════════════════════════════════
// STREET EATS — Admin Item Analytics Screen
// Step 9 of 16 — Top sellers, least sellers, margin,
//                time-based popularity, trending now
//
// Features:
//  • Tab 1 — Top Sellers: top 10 items by quantity this week
//  • Tab 2 — Least Selling: flag for removal
//  • Tab 3 — By Time: what sells at 5-6, 6-7, 7-8, 8-9 PM
//  • Tab 4 — Trending Now: last 2 hours hot items
//  • Margin % shown on every item card
//  • Pull-to-refresh on every tab
//  • Light theme (admin panel)
//  • Loading shimmer + error + empty states
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/analytics_service.dart';

// ─────────────────────────────────────────────────────────
// LOCAL COLOR PALETTE
// ─────────────────────────────────────────────────────────
class _AC {
  static const Color bg = Color(0xFFF5F6FA);
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
class AdminItemAnalyticsScreen extends StatefulWidget {
  const AdminItemAnalyticsScreen({super.key});

  @override
  State<AdminItemAnalyticsScreen> createState() =>
      _AdminItemAnalyticsScreenState();
}

class _AdminItemAnalyticsScreenState extends State<AdminItemAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _svc = AnalyticsService();
  late TabController _tabController;

  // Top sellers
  List<ItemAnalytics> _topItems = [];
  bool _topLoading = true;
  String? _topError;

  // Least sellers
  List<ItemAnalytics> _leastItems = [];
  bool _leastLoading = false;
  String? _leastError;
  bool _leastLoaded = false;

  // By time
  List<HourlyItemPopularity> _hourlyItems = [];
  bool _hourlyLoading = false;
  String? _hourlyError;
  bool _hourlyLoaded = false;

  // Trending now
  List<TrendingItem> _trendingItems = [];
  bool _trendingLoading = false;
  String? _trendingError;
  bool _trendingLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case 1:
            if (!_leastLoaded) _loadLeast();
            break;
          case 2:
            if (!_hourlyLoaded) _loadHourly();
            break;
          case 3:
            if (!_trendingLoaded) _loadTrending();
            break;
        }
      }
    });
    _loadTop();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTop() async {
    setState(() {
      _topLoading = true;
      _topError = null;
    });
    try {
      final data = await _svc.getTopSellingItems(daysBack: 7, limit: 10);
      if (mounted) {
        setState(() {
          _topItems = data;
          _topLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _topError = e.toString();
          _topLoading = false;
        });
      }
    }
  }

  Future<void> _loadLeast() async {
    setState(() {
      _leastLoading = true;
      _leastError = null;
    });
    try {
      final data = await _svc.getLeastSellingItems(daysBack: 7, limit: 10);
      if (mounted) {
        setState(() {
          _leastItems = data;
          _leastLoading = false;
          _leastLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leastError = e.toString();
          _leastLoading = false;
        });
      }
    }
  }

  Future<void> _loadHourly() async {
    setState(() {
      _hourlyLoading = true;
      _hourlyError = null;
    });
    try {
      final data = await _svc.getItemsByHour();
      if (mounted) {
        setState(() {
          _hourlyItems = data;
          _hourlyLoading = false;
          _hourlyLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hourlyError = e.toString();
          _hourlyLoading = false;
        });
      }
    }
  }

  Future<void> _loadTrending() async {
    setState(() {
      _trendingLoading = true;
      _trendingError = null;
    });
    try {
      final data = await _svc.getTrendingItemsNow();
      if (mounted) {
        setState(() {
          _trendingItems = data;
          _trendingLoading = false;
          _trendingLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trendingError = e.toString();
          _trendingLoading = false;
        });
      }
    }
  }

  void _refreshCurrent() {
    switch (_tabController.index) {
      case 0:
        _loadTop();
        break;
      case 1:
        _leastLoaded = false;
        _loadLeast();
        break;
      case 2:
        _hourlyLoaded = false;
        _loadHourly();
        break;
      case 3:
        _trendingLoaded = false;
        _loadTrending();
        break;
    }
  }

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
                _TopSellersTab(
                  items: _topItems,
                  isLoading: _topLoading,
                  error: _topError,
                  onRefresh: _loadTop,
                ),
                _LeastSellersTab(
                  items: _leastItems,
                  isLoading: _leastLoading,
                  error: _leastError,
                  onRefresh: () {
                    _leastLoaded = false;
                    _loadLeast();
                  },
                ),
                _ByTimeTab(
                  items: _hourlyItems,
                  isLoading: _hourlyLoading,
                  error: _hourlyError,
                  onRefresh: () {
                    _hourlyLoaded = false;
                    _loadHourly();
                  },
                ),
                _TrendingTab(
                  items: _trendingItems,
                  isLoading: _trendingLoading,
                  error: _trendingError,
                  onRefresh: () {
                    _trendingLoaded = false;
                    _loadTrending();
                  },
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
        'Item Analytics',
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
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: '🔥 Top Sellers'),
          Tab(text: '📉 Least Selling'),
          Tab(text: '⏰ By Time'),
          Tab(text: '📈 Trending'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 1 — TOP SELLERS
// ═══════════════════════════════════════════════════════════
class _TopSellersTab extends StatelessWidget {
  final List<ItemAnalytics> items;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _TopSellersTab({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (items.isEmpty) {
      return const _EmptyState(
        icon: '📦',
        message: 'Is week koi item data nahi hai',
      );
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: items.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SectionLabel(
                label: 'Top ${items.length} Items — Last 7 Days',
              ),
            );
          }
          final item = items[i - 1];
          final rank = i;
          return _ItemCard(
            item: item,
            rank: rank,
            rankColor: rank == 1
                ? _AC.gold
                : rank == 2
                ? const Color(0xFFC0C0C0)
                : rank == 3
                ? const Color(0xFFCD7F32)
                : _AC.textSecondary,
            badge: rank <= 3 ? _rankEmoji(rank) : null,
            highlightColor: _AC.success,
          );
        },
      ),
    );
  }

  String _rankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 2 — LEAST SELLERS
// ═══════════════════════════════════════════════════════════
class _LeastSellersTab extends StatelessWidget {
  final List<ItemAnalytics> items;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _LeastSellersTab({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (items.isEmpty) {
      return const _EmptyState(
        icon: '✅',
        message: 'Sab items achha chal rahe hain!',
      );
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: items.length + 2,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SectionLabel(label: 'Kam Bikne Wale Items'),
            );
          }
          if (i == 1) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _AC.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AC.error.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _AC.error, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In items ko menu se hatane ya price kam karne pe consider karo',
                      style: TextStyle(
                        color: _AC.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final item = items[i - 2];
          return _ItemCard(
            item: item,
            rank: i - 1,
            highlightColor: _AC.error,
            badge: '⚠️',
            showRemoveFlag: true,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 3 — BY TIME
// ═══════════════════════════════════════════════════════════
class _ByTimeTab extends StatelessWidget {
  final List<HourlyItemPopularity> items;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _ByTimeTab({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  // Group items by hour slot
  Map<String, List<HourlyItemPopularity>> get _grouped {
    final map = <String, List<HourlyItemPopularity>>{};
    for (final item in items) {
      map.putIfAbsent(item.hourSlot, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (items.isEmpty) {
      return const _EmptyState(
        icon: '⏰',
        message: 'Time-wise data abhi available nahi',
      );
    }

    final grouped = _grouped;
    final slots = grouped.keys.toList()..sort();

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          _SectionLabel(label: 'Har Ghante Kya Bikta Hai'),
          const SizedBox(height: 14),
          ...slots.map((slot) {
            final slotItems = grouped[slot]!;
            return _TimeSlotCard(slot: slot, items: slotItems);
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 4 — TRENDING NOW
// ═══════════════════════════════════════════════════════════
class _TrendingTab extends StatelessWidget {
  final List<TrendingItem> items;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const _TrendingTab({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShimmerList();
    if (error != null) return _ErrorState(error: error!, onRetry: onRefresh);
    if (items.isEmpty) {
      return const _EmptyState(
        icon: '😴',
        message: 'Abhi koi trending item nahi hai',
      );
    }

    return RefreshIndicator(
      color: _AC.orange,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: items.length + 2,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SectionLabel(label: 'Abhi Trending — Last 2 Hours'),
            );
          }
          if (i == 1) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _AC.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AC.orange.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: _AC.orange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yeh items pichle 2 ghante mein sabse zyada order hue hain',
                      style: TextStyle(
                        color: _AC.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final item = items[i - 2];
          final rank = i - 1;
          return _TrendingCard(item: item, rank: rank);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════

// ── Item Card (Top + Least sellers) ──────────────────────
class _ItemCard extends StatelessWidget {
  final ItemAnalytics item;
  final int rank;
  final Color highlightColor;
  final String? badge;
  final Color? rankColor;
  final bool showRemoveFlag;

  const _ItemCard({
    required this.item,
    required this.rank,
    required this.highlightColor,
    this.badge,
    this.rankColor,
    this.showRemoveFlag = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxMarginWidth = 80.0;
    final marginRatio = (item.marginPercent / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlightColor.withOpacity(0.12), width: 1),
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
          Row(
            children: [
              // Rank badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (rankColor ?? _AC.textSecondary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: badge != null
                      ? Text(badge!, style: const TextStyle(fontSize: 18))
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            color: rankColor ?? _AC.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        color: _AC.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      item.vendorName,
                      style: const TextStyle(
                        color: _AC.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Quantity sold
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.totalQuantity}',
                    style: TextStyle(
                      color: highlightColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'sold',
                    style: TextStyle(color: _AC.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              _MiniStat(
                label: 'Revenue',
                value: 'Rs.${item.totalRevenue.toStringAsFixed(0)}',
                color: _AC.orange,
              ),
              _MiniStat(
                label: 'Margin',
                value: 'Rs.${item.margin.toStringAsFixed(0)}',
                color: _AC.success,
              ),
              _MiniStat(
                label: 'Margin %',
                value: '${item.marginPercent.toStringAsFixed(1)}%',
                color: item.marginPercent >= 30
                    ? _AC.success
                    : item.marginPercent >= 15
                    ? _AC.warning
                    : _AC.error,
              ),
              if (showRemoveFlag)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _AC.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Hatao?',
                    style: TextStyle(
                      color: _AC.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Margin progress bar
          Row(
            children: [
              const Text(
                'Margin',
                style: TextStyle(color: _AC.textSecondary, fontSize: 10),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: marginRatio,
                    backgroundColor: _AC.textSecondary.withOpacity(0.1),
                    color: item.marginPercent >= 30
                        ? _AC.success
                        : item.marginPercent >= 15
                        ? _AC.warning
                        : _AC.error,
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.marginPercent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: _AC.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Time Slot Card ────────────────────────────────────────
class _TimeSlotCard extends StatelessWidget {
  final String slot;
  final List<HourlyItemPopularity> items;

  const _TimeSlotCard({required this.slot, required this.items});

  Color get _slotColor {
    if (slot.contains('17') || slot.contains('5 PM')) return _AC.info;
    if (slot.contains('18') || slot.contains('6 PM')) return _AC.orange;
    if (slot.contains('19') || slot.contains('7 PM')) return _AC.error;
    if (slot.contains('20') || slot.contains('8 PM')) return _AC.warning;
    return _AC.textSecondary;
  }

  int get _maxOrders =>
      items.map((e) => e.orderCount).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Slot header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _slotColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, color: _slotColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  slot,
                  style: TextStyle(
                    color: _slotColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} items',
                  style: const TextStyle(
                    color: _AC.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Items list
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: items.map((item) {
                final ratio = _maxOrders > 0
                    ? item.orderCount / _maxOrders
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.itemName,
                          style: const TextStyle(
                            color: _AC.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: _AC.textSecondary.withOpacity(
                                0.1,
                              ),
                              color: _slotColor,
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '${item.orderCount}',
                        style: TextStyle(
                          color: _slotColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trending Card ─────────────────────────────────────────
class _TrendingCard extends StatelessWidget {
  final TrendingItem item;
  final int rank;

  const _TrendingCard({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AC.orange.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fire icon with rank
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _AC.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                Text(
                  '#$rank',
                  style: const TextStyle(
                    color: _AC.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    color: _AC.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  item.vendorName,
                  style: const TextStyle(
                    color: _AC.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _AC.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item.orderCount} orders',
              style: const TextStyle(
                color: _AC.orange,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini Stat ─────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: _AC.textSecondary, fontSize: 9),
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

  Widget _box(double h) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 10),
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_box(20), _box(90), _box(90), _box(90), _box(90), _box(90)],
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
  final String icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
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
