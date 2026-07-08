import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_card.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(partnerDashboardStatsProvider);

    return PageScaffold(
      title: 'Bookings',
      body: pullToRefresh(
        onRefresh: () async {
          ref.invalidate(partnerDashboardStatsProvider);
          await ref.read(partnerDashboardStatsProvider.future);
        },
        child: statsAsync.when(
          loading: () => const LoadingState(message: 'Loading bookings...'),
          error: (_, e) => ErrorState(
            message: 'Could not load bookings',
            onRetry: () => ref.invalidate(partnerDashboardStatsProvider),
          ),
          data: (stats) => ListView(
            physics: alwaysScrollablePhysics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.pageHorizontal,
              AppSpacing.pageHorizontal,
              AppSpacing.pageBottom,
            ),
            children: [
              const SectionHeader(
                title: 'Overview',
                subtitle: 'Booking activity at a glance',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      compact: true,
                      icon: Icons.calendar_month_rounded,
                      title: 'Total',
                      value: '${stats.totalBookings}',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      compact: true,
                      icon: Icons.today_rounded,
                      title: 'Today',
                      value: '${stats.todayBookings}',
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      compact: true,
                      icon: Icons.event_rounded,
                      title: 'Tomorrow',
                      value: '${stats.tomorrowBookings}',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              EmptyState(
                icon: Icons.event_note_rounded,
                title: stats.totalBookings > 0
                    ? '${stats.totalBookings} booking(s)'
                    : 'No bookings yet',
                message: stats.totalBookings > 0
                    ? 'Detailed booking list will appear here as customers book your services.'
                    : 'Bookings from customers will appear here.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
