// ═══════════════════════════════════════════════════════════
// STREAT EATS — Analytics Service
// Handles all analytics RPC calls — Today/Weekly/Monthly/
// Items/Rider Performance/Forecast/Heatmap/Daily Report
// ═══════════════════════════════════════════════════════════

import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────────────────
  // FEATURE 2 — TODAY ANALYTICS
  // ─────────────────────────────────────────────────────────

  Future<TodayAnalytics> getTodayAnalytics() async {
    try {
      final response = await _supabase.rpc('get_today_analytics').select();
      final data = (response as List);
      if (data.isEmpty) return TodayAnalytics.empty();
      return TodayAnalytics.fromMap(data.first);
    } catch (e) {
      throw Exception('Today analytics fetch failed: $e');
    }
  }

  Future<List<HourlyOrder>> getOrdersByHour({DateTime? date}) async {
    try {
      final params = date != null
          ? {
              'target_date':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            }
          : <String, dynamic>{};

      final response = await _supabase
          .rpc('get_orders_by_hour', params: params)
          .select();

      return (response as List).map((e) => HourlyOrder.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Hourly orders fetch failed: $e');
    }
  }

  Future<List<AreaOrder>> getOrdersByArea({DateTime? date}) async {
    try {
      final params = date != null
          ? {
              'target_date':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            }
          : <String, dynamic>{};

      final response = await _supabase
          .rpc('get_orders_by_area', params: params)
          .select();

      return (response as List).map((e) => AreaOrder.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Area orders fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // FEATURE 2 — WEEKLY ANALYTICS
  // ─────────────────────────────────────────────────────────

  Future<List<DailyAnalytics>> getWeeklyAnalytics() async {
    try {
      final response = await _supabase.rpc('get_weekly_analytics').select();

      return (response as List).map((e) => DailyAnalytics.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Weekly analytics fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // FEATURE 2 — MONTHLY ANALYTICS
  // ─────────────────────────────────────────────────────────

  Future<MonthlyAnalytics> getMonthlyAnalytics() async {
    try {
      final response = await _supabase.rpc('get_monthly_analytics').select();
      final data = (response as List);
      if (data.isEmpty) return MonthlyAnalytics.empty();
      return MonthlyAnalytics.fromMap(data.first);
    } catch (e) {
      throw Exception('Monthly analytics fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // FEATURE 3 — ITEM ANALYTICS
  // ─────────────────────────────────────────────────────────

  Future<List<ItemAnalytics>> getTopSellingItems({
    int daysBack = 7,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .rpc(
            'get_top_selling_items',
            params: {'days_back': daysBack, 'result_limit': limit},
          )
          .select();

      return (response as List).map((e) => ItemAnalytics.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Top items fetch failed: $e');
    }
  }

  Future<List<ItemAnalytics>> getLeastSellingItems({
    int daysBack = 7,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .rpc(
            'get_least_selling_items',
            params: {'days_back': daysBack, 'result_limit': limit},
          )
          .select();

      return (response as List).map((e) => ItemAnalytics.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Least items fetch failed: $e');
    }
  }

  Future<List<HourlyItemPopularity>> getItemsByHour() async {
    try {
      final response = await _supabase.rpc('get_items_by_hour').select();

      return (response as List)
          .map((e) => HourlyItemPopularity.fromMap(e))
          .toList();
    } catch (e) {
      throw Exception('Hourly items fetch failed: $e');
    }
  }

  Future<List<TrendingItem>> getTrendingItemsNow() async {
    try {
      final response = await _supabase.rpc('get_trending_items_now').select();

      return (response as List).map((e) => TrendingItem.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Trending items fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // FEATURE 4 — RIDER PERFORMANCE
  // ─────────────────────────────────────────────────────────

  Future<List<RiderPerformance>> getRiderPerformance({DateTime? date}) async {
    try {
      final params = date != null
          ? {
              'target_date':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            }
          : <String, dynamic>{};

      final response = await _supabase
          .rpc('get_rider_performance', params: params)
          .select();

      return (response as List)
          .map((e) => RiderPerformance.fromMap(e))
          .toList();
    } catch (e) {
      throw Exception('Rider performance fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // FEATURE 6 — DEMAND FORECASTING
  // ─────────────────────────────────────────────────────────

  Future<DemandForecast> getDemandForecast() async {
    try {
      final response = await _supabase.rpc('get_demand_forecast').select();
      final data = (response as List);
      if (data.isEmpty) return DemandForecast.empty();
      return DemandForecast.fromMap(data.first);
    } catch (e) {
      throw Exception('Demand forecast fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // FEATURE 7 — AREA HEATMAP
  // ─────────────────────────────────────────────────────────

  Future<List<AreaHeatmap>> getAreaHeatmap() async {
    try {
      final response = await _supabase.rpc('get_area_heatmap').select();

      return (response as List).map((e) => AreaHeatmap.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Area heatmap fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // FEATURE 8 — DAILY REPORT
  // ─────────────────────────────────────────────────────────

  Future<DailyReport> getDailyReport({DateTime? date}) async {
    try {
      final params = date != null
          ? {
              'target_date':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            }
          : <String, dynamic>{};

      final response = await _supabase
          .rpc('get_daily_report', params: params)
          .select();
      final data = (response as List);
      if (data.isEmpty) return DailyReport.empty();
      return DailyReport.fromMap(data.first);
    } catch (e) {
      throw Exception('Daily report fetch failed: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════

// ── Today Analytics ──────────────────────────────────────
class TodayAnalytics {
  final int totalOrders;
  final double grossRevenue;
  final double totalVendorCost;
  final double netProfit;
  final double avgOrderValue;
  final double platformFees;

  TodayAnalytics({
    required this.totalOrders,
    required this.grossRevenue,
    required this.totalVendorCost,
    required this.netProfit,
    required this.avgOrderValue,
    required this.platformFees,
  });

  factory TodayAnalytics.empty() => TodayAnalytics(
    totalOrders: 0,
    grossRevenue: 0,
    totalVendorCost: 0,
    netProfit: 0,
    avgOrderValue: 0,
    platformFees: 0,
  );

  factory TodayAnalytics.fromMap(Map<String, dynamic> map) {
    return TodayAnalytics(
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      grossRevenue: (map['gross_revenue'] as num?)?.toDouble() ?? 0.0,
      totalVendorCost: (map['total_vendor_cost'] as num?)?.toDouble() ?? 0.0,
      netProfit: (map['net_profit'] as num?)?.toDouble() ?? 0.0,
      avgOrderValue: (map['avg_order_value'] as num?)?.toDouble() ?? 0.0,
      platformFees: (map['platform_fees'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Hourly Orders ────────────────────────────────────────
class HourlyOrder {
  final int hourOfDay;
  final int orderCount;
  final double revenue;

  HourlyOrder({
    required this.hourOfDay,
    required this.orderCount,
    required this.revenue,
  });

  // "17" → "5 PM" label
  String get hourLabel {
    final h = hourOfDay > 12 ? hourOfDay - 12 : hourOfDay;
    final suffix = hourOfDay >= 12 ? 'PM' : 'AM';
    return '$h $suffix';
  }

  factory HourlyOrder.fromMap(Map<String, dynamic> map) {
    return HourlyOrder(
      hourOfDay: (map['hour_of_day'] as num?)?.toInt() ?? 0,
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Area Orders ──────────────────────────────────────────
class AreaOrder {
  final String area;
  final int orderCount;
  final double revenue;
  final double avgValue;

  AreaOrder({
    required this.area,
    required this.orderCount,
    required this.revenue,
    required this.avgValue,
  });

  factory AreaOrder.fromMap(Map<String, dynamic> map) {
    return AreaOrder(
      area: map['area']?.toString() ?? 'Unknown',
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      avgValue: (map['avg_value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Daily Analytics (for weekly graph) ──────────────────
class DailyAnalytics {
  final DateTime orderDate;
  final String dayName;
  final int totalOrders;
  final double grossRevenue;
  final double netProfit;

  DailyAnalytics({
    required this.orderDate,
    required this.dayName,
    required this.totalOrders,
    required this.grossRevenue,
    required this.netProfit,
  });

  factory DailyAnalytics.fromMap(Map<String, dynamic> map) {
    return DailyAnalytics(
      orderDate: DateTime.parse(
        map['order_date']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      dayName: map['day_name']?.toString() ?? '',
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      grossRevenue: (map['gross_revenue'] as num?)?.toDouble() ?? 0.0,
      netProfit: (map['net_profit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Monthly Analytics ────────────────────────────────────
class MonthlyAnalytics {
  final int totalOrders;
  final double grossRevenue;
  final double netProfit;
  final double bestWeekNumber;
  final int lastMonthOrders;
  final double lastMonthRevenue;
  final double growthPercent;

  MonthlyAnalytics({
    required this.totalOrders,
    required this.grossRevenue,
    required this.netProfit,
    required this.bestWeekNumber,
    required this.lastMonthOrders,
    required this.lastMonthRevenue,
    required this.growthPercent,
  });

  factory MonthlyAnalytics.empty() => MonthlyAnalytics(
    totalOrders: 0,
    grossRevenue: 0,
    netProfit: 0,
    bestWeekNumber: 0,
    lastMonthOrders: 0,
    lastMonthRevenue: 0,
    growthPercent: 0,
  );

  factory MonthlyAnalytics.fromMap(Map<String, dynamic> map) {
    return MonthlyAnalytics(
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      grossRevenue: (map['gross_revenue'] as num?)?.toDouble() ?? 0.0,
      netProfit: (map['net_profit'] as num?)?.toDouble() ?? 0.0,
      bestWeekNumber: (map['best_week_number'] as num?)?.toDouble() ?? 0.0,
      lastMonthOrders: (map['last_month_orders'] as num?)?.toInt() ?? 0,
      lastMonthRevenue: (map['last_month_revenue'] as num?)?.toDouble() ?? 0.0,
      growthPercent: (map['growth_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Item Analytics ───────────────────────────────────────
class ItemAnalytics {
  final String itemId;
  final String itemName;
  final String vendorName;
  final int totalQuantity;
  final double totalRevenue;
  final double margin;
  final double marginPercent;

  ItemAnalytics({
    required this.itemId,
    required this.itemName,
    required this.vendorName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.margin,
    required this.marginPercent,
  });

  factory ItemAnalytics.fromMap(Map<String, dynamic> map) {
    return ItemAnalytics(
      itemId: map['item_id']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      vendorName: map['vendor_name']?.toString() ?? '',
      totalQuantity: (map['total_quantity'] as num?)?.toInt() ?? 0,
      totalRevenue: (map['total_revenue'] as num?)?.toDouble() ?? 0.0,
      margin: (map['margin'] as num?)?.toDouble() ?? 0.0,
      marginPercent: (map['margin_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Hourly Item Popularity ───────────────────────────────
class HourlyItemPopularity {
  final String hourSlot;
  final String itemName;
  final int orderCount;

  HourlyItemPopularity({
    required this.hourSlot,
    required this.itemName,
    required this.orderCount,
  });

  factory HourlyItemPopularity.fromMap(Map<String, dynamic> map) {
    return HourlyItemPopularity(
      hourSlot: map['hour_slot']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Trending Item ────────────────────────────────────────
class TrendingItem {
  final String itemName;
  final String vendorName;
  final int orderCount;

  TrendingItem({
    required this.itemName,
    required this.vendorName,
    required this.orderCount,
  });

  factory TrendingItem.fromMap(Map<String, dynamic> map) {
    return TrendingItem(
      itemName: map['item_name']?.toString() ?? '',
      vendorName: map['vendor_name']?.toString() ?? '',
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Rider Performance ────────────────────────────────────
class RiderPerformance {
  final String riderId;
  final String riderName;
  final int ordersToday;
  final int ordersThisWeek;
  final double avgDeliveryMinutes;
  final double onTimeRate;
  final double totalEarningsWeek;

  RiderPerformance({
    required this.riderId,
    required this.riderName,
    required this.ordersToday,
    required this.ordersThisWeek,
    required this.avgDeliveryMinutes,
    required this.onTimeRate,
    required this.totalEarningsWeek,
  });

  // Performance badge
  String get performanceBadge {
    if (onTimeRate >= 90) return '🏆 Top Rider';
    if (onTimeRate >= 75) return '⭐ Good';
    if (onTimeRate >= 50) return '👍 Average';
    return '⚠️ Needs Work';
  }

  factory RiderPerformance.fromMap(Map<String, dynamic> map) {
    return RiderPerformance(
      riderId: map['rider_id']?.toString() ?? '',
      riderName: map['rider_name']?.toString() ?? '',
      ordersToday: (map['orders_today'] as num?)?.toInt() ?? 0,
      ordersThisWeek: (map['orders_this_week'] as num?)?.toInt() ?? 0,
      avgDeliveryMinutes:
          (map['avg_delivery_minutes'] as num?)?.toDouble() ?? 0.0,
      onTimeRate: (map['on_time_rate'] as num?)?.toDouble() ?? 0.0,
      totalEarningsWeek:
          (map['total_earnings_week'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Demand Forecast ──────────────────────────────────────
class DemandForecast {
  final double expectedOrders;
  final double expectedRevenue;
  final int peakHour;
  final String topPredictedItem;

  DemandForecast({
    required this.expectedOrders,
    required this.expectedRevenue,
    required this.peakHour,
    required this.topPredictedItem,
  });

  // "17" → "5 PM - 6 PM"
  String get peakHourLabel {
    final h = peakHour > 12 ? peakHour - 12 : peakHour;
    final h2 = (peakHour + 1) > 12 ? (peakHour + 1) - 12 : peakHour + 1;
    return '$h PM - $h2 PM';
  }

  factory DemandForecast.empty() => DemandForecast(
    expectedOrders: 0,
    expectedRevenue: 0,
    peakHour: 19,
    topPredictedItem: 'Momos',
  );

  factory DemandForecast.fromMap(Map<String, dynamic> map) {
    return DemandForecast(
      expectedOrders: (map['expected_orders'] as num?)?.toDouble() ?? 0.0,
      expectedRevenue: (map['expected_revenue'] as num?)?.toDouble() ?? 0.0,
      peakHour: (map['peak_hour'] as num?)?.toInt() ?? 19,
      topPredictedItem: map['top_predicted_item']?.toString() ?? 'Momos',
    );
  }
}

// ── Area Heatmap ─────────────────────────────────────────
class AreaHeatmap {
  final String area;
  final int totalOrders;
  final double totalRevenue;
  final double avgDeliveryMin;
  final DateTime? lastOrderDate;
  final String intensity; // 'high' | 'medium' | 'low' | 'new'

  AreaHeatmap({
    required this.area,
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgDeliveryMin,
    this.lastOrderDate,
    required this.intensity,
  });

  // Color based on intensity
  // Used in UI — returns hex string
  String get intensityColor {
    switch (intensity) {
      case 'high':
        return '#FF6B2B'; // Orange — hot area
      case 'medium':
        return '#FFD700'; // Gold — moderate
      case 'low':
        return '#00C48C'; // Green — low
      default:
        return '#A0A8C0'; // Grey — new/untapped
    }
  }

  String get intensityLabel {
    switch (intensity) {
      case 'high':
        return '🔥 Hot Area';
      case 'medium':
        return '⚡ Active';
      case 'low':
        return '📍 Low';
      default:
        return '🆕 Untapped';
    }
  }

  factory AreaHeatmap.fromMap(Map<String, dynamic> map) {
    return AreaHeatmap(
      area: map['area']?.toString() ?? 'Unknown',
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      totalRevenue: (map['total_revenue'] as num?)?.toDouble() ?? 0.0,
      avgDeliveryMin: (map['avg_delivery_min'] as num?)?.toDouble() ?? 0.0,
      lastOrderDate: map['last_order_date'] != null
          ? DateTime.parse(map['last_order_date'].toString())
          : null,
      intensity: map['intensity']?.toString() ?? 'new',
    );
  }
}

// ── Daily Report ─────────────────────────────────────────
class DailyReport {
  final int totalOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final double grossRevenue;
  final double netProfit;
  final double platformFees;
  final String bestRiderName;
  final int bestRiderOrders;
  final String topItemName;
  final int topItemCount;
  final int yesterdayOrders;
  final double yesterdayRevenue;

  DailyReport({
    required this.totalOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.grossRevenue,
    required this.netProfit,
    required this.platformFees,
    required this.bestRiderName,
    required this.bestRiderOrders,
    required this.topItemName,
    required this.topItemCount,
    required this.yesterdayOrders,
    required this.yesterdayRevenue,
  });

  // Orders growth vs yesterday
  double get ordersGrowthPercent {
    if (yesterdayOrders == 0) return 0;
    return ((totalOrders - yesterdayOrders) / yesterdayOrders) * 100;
  }

  // Revenue growth vs yesterday
  double get revenueGrowthPercent {
    if (yesterdayRevenue == 0) return 0;
    return ((grossRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
  }

  // WhatsApp share text
  String get shareText {
    final now = DateTime.now();
    return '''
🍟 *Streat Eats — Daily Report*
📅 ${now.day}/${now.month}/${now.year}

📦 Orders: $totalOrders (✅ $deliveredOrders | ❌ $cancelledOrders)
💰 Revenue: Rs.${grossRevenue.toStringAsFixed(0)}
📈 Net Profit: Rs.${netProfit.toStringAsFixed(0)}

🏆 Best Rider: $bestRiderName ($bestRiderOrders orders)
🔥 Top Item: $topItemName ($topItemCount sold)

vs Yesterday:
Orders: ${ordersGrowthPercent >= 0 ? '+' : ''}${ordersGrowthPercent.toStringAsFixed(1)}%
Revenue: ${revenueGrowthPercent >= 0 ? '+' : ''}${revenueGrowthPercent.toStringAsFixed(1)}%

_Streat Eats — Ghar Baithe Street Ka Swad_ 🛵
    '''
        .trim();
  }

  factory DailyReport.empty() => DailyReport(
    totalOrders: 0,
    deliveredOrders: 0,
    cancelledOrders: 0,
    grossRevenue: 0,
    netProfit: 0,
    platformFees: 0,
    bestRiderName: 'N/A',
    bestRiderOrders: 0,
    topItemName: 'N/A',
    topItemCount: 0,
    yesterdayOrders: 0,
    yesterdayRevenue: 0,
  );

  factory DailyReport.fromMap(Map<String, dynamic> map) {
    return DailyReport(
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (map['delivered_orders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (map['cancelled_orders'] as num?)?.toInt() ?? 0,
      grossRevenue: (map['gross_revenue'] as num?)?.toDouble() ?? 0.0,
      netProfit: (map['net_profit'] as num?)?.toDouble() ?? 0.0,
      platformFees: (map['platform_fees'] as num?)?.toDouble() ?? 0.0,
      bestRiderName: map['best_rider_name']?.toString() ?? 'N/A',
      bestRiderOrders: (map['best_rider_orders'] as num?)?.toInt() ?? 0,
      topItemName: map['top_item_name']?.toString() ?? 'N/A',
      topItemCount: (map['top_item_count'] as num?)?.toInt() ?? 0,
      yesterdayOrders: (map['yesterday_orders'] as num?)?.toInt() ?? 0,
      yesterdayRevenue: (map['yesterday_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
