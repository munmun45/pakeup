class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.totalSalons,
    required this.activeBookings,
    required this.totalRevenue,
    required this.pendingSalons,
    required this.todayBookings,
    required this.commissionEarned,
    required this.aiAnalyses,
  });

  final int totalUsers;
  final int totalSalons;
  final int activeBookings;
  final double totalRevenue;
  final int pendingSalons;
  final int todayBookings;
  final double commissionEarned;
  final int aiAnalyses;
}

class RecentBooking {
  const RecentBooking({
    required this.id,
    required this.customerName,
    required this.salonName,
    required this.service,
    required this.amount,
    required this.status,
    required this.date,
  });

  final String id;
  final String customerName;
  final String salonName;
  final String service;
  final double amount;
  final String status;
  final DateTime date;
}

class PendingSalon {
  const PendingSalon({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.city,
    required this.submittedAt,
  });

  final String id;
  final String name;
  final String ownerName;
  final String city;
  final DateTime submittedAt;
}
