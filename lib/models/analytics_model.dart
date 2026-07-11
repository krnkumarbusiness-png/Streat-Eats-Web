// ═══════════════════════════════════════════════════════════
// STREAT EATS — Analytics Model
// Order analytics, revenue, forecast, heatmap models
// ═══════════════════════════════════════════════════════════

class OrderAnalyticsSnapshot {
  final DateTime date;
  final int totalOrders;
  final double grossRevenue;
  final double netProfit;
  final double avgOrderValue;
  final double platformFees;
  final double totalVendorCost;

  OrderAnalyticsSnapshot({
    required this.date,
    required this.totalOrders,
    required this.grossRevenue,
    required this.netProfit,
    required this.avgOrderValue,
    required this.platformFees,
    required this.totalVendorCost,
  });

  // Profit margin percent
  double get profitMarginPercent {
    if (grossRevenue == 0) return 0;
    return (netProfit / grossRevenue) * 100;
  }

  factory OrderAnalyticsSnapshot.empty() => OrderAnalyticsSnapshot(
    date: DateTime.now(),
    totalOrders: 0,
    grossRevenue: 0,
    netProfit: 0,
    avgOrderValue: 0,
    platformFees: 0,
    totalVendorCost: 0,
  );

  factory OrderAnalyticsSnapshot.fromMap(Map<String, dynamic> map) {
    return OrderAnalyticsSnapshot(
      date: DateTime.now(),
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      grossRevenue: (map['gross_revenue'] as num?)?.toDouble() ?? 0.0,
      netProfit: (map['net_profit'] as num?)?.toDouble() ?? 0.0,
      avgOrderValue: (map['avg_order_value'] as num?)?.toDouble() ?? 0.0,
      platformFees: (map['platform_fees'] as num?)?.toDouble() ?? 0.0,
      totalVendorCost: (map['total_vendor_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────
class WeeklyAnalyticsModel {
  final List<DayData> days;

  WeeklyAnalyticsModel({required this.days});

  // Best day by orders
  DayData? get bestDay {
    if (days.isEmpty) return null;
    return days.reduce((a, b) => a.totalOrders > b.totalOrders ? a : b);
  }

  // Total week orders
  int get totalWeekOrders => days.fold(0, (sum, d) => sum + d.totalOrders);

  // Total week revenue
  double get totalWeekRevenue =>
      days.fold(0.0, (sum, d) => sum + d.grossRevenue);

  // Week over week growth — needs previous week data
  double weekOverWeekGrowth(WeeklyAnalyticsModel? previousWeek) {
    if (previousWeek == null || previousWeek.totalWeekOrders == 0) return 0;
    return ((totalWeekOrders - previousWeek.totalWeekOrders) /
            previousWeek.totalWeekOrders) *
        100;
  }

  factory WeeklyAnalyticsModel.fromList(List<dynamic> list) {
    return WeeklyAnalyticsModel(
      days: list.map((e) => DayData.fromMap(e)).toList(),
    );
  }
}

class DayData {
  final DateTime orderDate;
  final String dayName;
  final int totalOrders;
  final double grossRevenue;
  final double netProfit;

  DayData({
    required this.orderDate,
    required this.dayName,
    required this.totalOrders,
    required this.grossRevenue,
    required this.netProfit,
  });

  factory DayData.fromMap(Map<String, dynamic> map) {
    return DayData(
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

// ─────────────────────────────────────────────────────────
class MonthlyAnalyticsModel {
  final int totalOrders;
  final double grossRevenue;
  final double netProfit;
  final double bestWeekNumber;
  final int lastMonthOrders;
  final double lastMonthRevenue;
  final double growthPercent;

  MonthlyAnalyticsModel({
    required this.totalOrders,
    required this.grossRevenue,
    required this.netProfit,
    required this.bestWeekNumber,
    required this.lastMonthOrders,
    required this.lastMonthRevenue,
    required this.growthPercent,
  });

  // Growth arrow
  bool get isGrowthPositive => growthPercent >= 0;

  String get growthLabel {
    final sign = isGrowthPositive ? '+' : '';
    return '$sign${growthPercent.toStringAsFixed(1)}%';
  }

  factory MonthlyAnalyticsModel.empty() => MonthlyAnalyticsModel(
    totalOrders: 0,
    grossRevenue: 0,
    netProfit: 0,
    bestWeekNumber: 0,
    lastMonthOrders: 0,
    lastMonthRevenue: 0,
    growthPercent: 0,
  );

  factory MonthlyAnalyticsModel.fromMap(Map<String, dynamic> map) {
    return MonthlyAnalyticsModel(
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

// ─────────────────────────────────────────────────────────
class DemandForecastModel {
  final double expectedOrders;
  final double expectedRevenue;
  final int peakHour;
  final String topPredictedItem;

  DemandForecastModel({
    required this.expectedOrders,
    required this.expectedRevenue,
    required this.peakHour,
    required this.topPredictedItem,
  });

  String get peakHourLabel {
    final h = peakHour > 12 ? peakHour - 12 : peakHour;
    final h2 = (peakHour + 1) > 12 ? (peakHour + 1) - 12 : peakHour + 1;
    return '$h PM - $h2 PM';
  }

  String get expectedOrdersLabel => expectedOrders.toStringAsFixed(0);

  String get expectedRevenueLabel => 'Rs.${expectedRevenue.toStringAsFixed(0)}';

  factory DemandForecastModel.empty() => DemandForecastModel(
    expectedOrders: 0,
    expectedRevenue: 0,
    peakHour: 19,
    topPredictedItem: 'Momos',
  );

  factory DemandForecastModel.fromMap(Map<String, dynamic> map) {
    return DemandForecastModel(
      expectedOrders: (map['expected_orders'] as num?)?.toDouble() ?? 0.0,
      expectedRevenue: (map['expected_revenue'] as num?)?.toDouble() ?? 0.0,
      peakHour: (map['peak_hour'] as num?)?.toInt() ?? 19,
      topPredictedItem: map['top_predicted_item']?.toString() ?? 'Momos',
    );
  }
}

// ─────────────────────────────────────────────────────────
class AreaHeatmapModel {
  final String area;
  final int totalOrders;
  final double totalRevenue;
  final double avgDeliveryMin;
  final DateTime? lastOrderDate;
  final String intensity;

  AreaHeatmapModel({
    required this.area,
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgDeliveryMin,
    this.lastOrderDate,
    required this.intensity,
  });

  String get intensityLabel {
    switch (intensity) {
      case 'high':
        return '🔥 Hot Area';
      case 'medium':
        return '⚡ Active';
      case 'low':
        return '📍 Low Activity';
      default:
        return '🆕 Untapped';
    }
  }

  // Returns int 0-3 for color logic in UI
  int get intensityLevel {
    switch (intensity) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  factory AreaHeatmapModel.fromMap(Map<String, dynamic> map) {
    return AreaHeatmapModel(
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

// ─────────────────────────────────────────────────────────
class DailyReportModel {
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

  DailyReportModel({
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

  double get ordersGrowth {
    if (yesterdayOrders == 0) return 0;
    return ((totalOrders - yesterdayOrders) / yesterdayOrders) * 100;
  }

  double get revenueGrowth {
    if (yesterdayRevenue == 0) return 0;
    return ((grossRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
  }

  int get successRate {
    if (totalOrders == 0) return 0;
    return ((deliveredOrders / totalOrders) * 100).round();
  }

  String get whatsappText {
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
Orders: ${ordersGrowth >= 0 ? '+' : ''}${ordersGrowth.toStringAsFixed(1)}%
Revenue: ${revenueGrowth >= 0 ? '+' : ''}${revenueGrowth.toStringAsFixed(1)}%

_Streat Eats — Ghar Baithe Street Ka Swad_ 🛵
    '''
        .trim();
  }

  factory DailyReportModel.empty() => DailyReportModel(
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

  factory DailyReportModel.fromMap(Map<String, dynamic> map) {
    return DailyReportModel(
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
