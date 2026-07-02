import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_models.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  return const DashboardStats(
    totalUsers: 0,
    totalSalons: 0,
    activeBookings: 0,
    totalRevenue: 0,
    pendingSalons: 0,
    todayBookings: 0,
    commissionEarned: 0,
    aiAnalyses: 0,
  );
});

final recentBookingsProvider = FutureProvider<List<RecentBooking>>((ref) async {
  return [];
});

final pendingSalonsProvider = FutureProvider<List<PendingSalon>>((ref) async {
  return [];
});
