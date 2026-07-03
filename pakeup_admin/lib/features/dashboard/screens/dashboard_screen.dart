import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/pending_salons_list.dart';
import '../widgets/recent_bookings_table.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const double _gap = 16;

  static int _statColumns(double width) {
    if (width >= 1100) return 4;
    if (width >= 560) return 2;
    return 1;
  }

  static int _quickStatColumns(double width) {
    if (width >= 1000) return 4;
    if (width >= 520) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final bookingsAsync = ref.watch(recentBookingsProvider);
    final salonsAsync = ref.watch(pendingSalonsProvider);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Column(
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
              data: (stats) {
                final columns = _statColumns(width);
                final cardWidth =
                    (width - _gap * (columns - 1)) / columns;

                final cards = [
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
                ];

                return Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: cardWidth,
                          child: card,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            if (width > 1000)
              Row(
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
              )
            else ...[
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
            const SizedBox(height: 24),
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (stats) {
                final columns = _quickStatColumns(width);
                final itemWidth =
                    (width - _gap * (columns - 1)) / columns;

                final items = [
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
                ];

                if (columns == 4) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            Expanded(child: items[i]),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: itemWidth,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: item,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
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
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
