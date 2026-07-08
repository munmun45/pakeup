class PartnerDashboardStats {
  const PartnerDashboardStats({
    this.totalBookings = 0,
    this.todayBookings = 0,
    this.tomorrowBookings = 0,
    this.lifetimeRevenue = 0,
    this.pastMonthRevenue = 0,
    this.thisMonthRevenue = 0,
  });

  final int totalBookings;
  final int todayBookings;
  final int tomorrowBookings;
  final double lifetimeRevenue;
  final double pastMonthRevenue;
  final double thisMonthRevenue;

  factory PartnerDashboardStats.fromJson(Map<String, dynamic> json) {
    return PartnerDashboardStats(
      totalBookings: json['total_bookings'] as int? ?? 0,
      todayBookings: json['today_bookings'] as int? ?? 0,
      tomorrowBookings: json['tomorrow_bookings'] as int? ?? 0,
      lifetimeRevenue: _toDouble(json['lifetime_revenue']),
      pastMonthRevenue: _toDouble(json['past_month_revenue']),
      thisMonthRevenue: _toDouble(json['this_month_revenue']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
