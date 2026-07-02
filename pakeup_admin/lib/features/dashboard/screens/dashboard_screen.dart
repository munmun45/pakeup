import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/admin_shell.dart';
import '../widgets/pending_salons_list.dart';
import '../widgets/recent_bookings_table.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final bookingsAsync = ref.watch(recentBookingsProvider);
    final salonsAsync = ref.watch(pendingSalonsProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return AdminShell(
      title: 'Dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (stats) => LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1200
                    ? 4
                    : constraints.maxWidth > 800
                        ? 2
                        : 1;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.2,
                  children: [
                    StatCard(
                      title: 'Total Users',
                      value: '${stats.totalUsers}',
                      icon: Icons.people_rounded,
                      color: AppColors.primary,
                      trend: '+12%',
                      subtitle: '${stats.todayBookings} bookings today',
                    ),
                    StatCard(
                      title: 'Active Salons',
                      value: '${stats.totalSalons}',
                      icon: Icons.store_rounded,
                      color: AppColors.secondary,
                      trend: '+5%',
                      subtitle: '${stats.pendingSalons} pending approval',
                    ),
                    StatCard(
                      title: 'Active Bookings',
                      value: '${stats.activeBookings}',
                      icon: Icons.calendar_today_rounded,
                      color: AppColors.warning,
                      subtitle: 'In progress & confirmed',
                    ),
                    StatCard(
                      title: 'Total Revenue',
                      value: currency.format(stats.totalRevenue),
                      icon: Icons.currency_rupee_rounded,
                      color: AppColors.success,
                      trend: '+18%',
                      subtitle:
                          'Commission: ${currency.format(stats.commissionEarned)}',
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: bookingsAsync.when(
                        loading: () => const Card(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        error: (e, _) => Text('Error: $e'),
                        data: (bookings) =>
                            RecentBookingsTable(bookings: bookings),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: salonsAsync.when(
                        loading: () => const Card(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        error: (e, _) => Text('Error: $e'),
                        data: (salons) => PendingSalonsList(salons: salons),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  bookingsAsync.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (bookings) => RecentBookingsTable(bookings: bookings),
                  ),
                  const SizedBox(height: 16),
                  salonsAsync.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (salons) => PendingSalonsList(salons: salons),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _QuickStat(
                      icon: Icons.face_retouching_natural,
                      label: 'AI Analyses',
                      value: '${stats.aiAnalyses}',
                      color: AppColors.primary,
                    ),
                    _QuickStat(
                      icon: Icons.pending_actions,
                      label: 'Pending Salons',
                      value: '${stats.pendingSalons}',
                      color: AppColors.warning,
                    ),
                    _QuickStat(
                      icon: Icons.today_rounded,
                      label: "Today's Bookings",
                      value: '${stats.todayBookings}',
                      color: AppColors.success,
                    ),
                    _QuickStat(
                      icon: Icons.account_balance_wallet,
                      label: 'Commission (10%)',
                      value: currency.format(stats.commissionEarned),
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
