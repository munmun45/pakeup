import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/external_links.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/partner_kyc_status.dart';
import '../../services/providers/services_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/app_ui_components.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';
import '../models/dashboard_models.dart';
import '../providers/dashboard_provider.dart';

/// Shared spacing for dashboard stat + quick-action grids.
const _dashboardGridGap = 10.0;
const _dashboardSectionGap = 16.0;
const _dashboardTitleGap = 10.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(authStateProvider).valueOrNull;
    final storesAsync = ref.watch(myStoresProvider);
    final hasStores = ref.watch(hasStoresProvider);
    final statsAsync = ref.watch(partnerDashboardStatsProvider);
    final stores = storesAsync.valueOrNull ?? const <StoreRecord>[];
    final kycStatus = PartnerKycStatus.resolve(
      stores: stores,
      accountStatus: partner?.kycStatus,
    );
    final kycApproved = PartnerKycStatus.isApproved(
      stores: stores,
      accountStatus: partner?.kycStatus,
    );

    if (partner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _DashboardHeader(
            name: partner.ownerName.isNotEmpty
                ? partner.ownerName
                : partner.businessName,
            initial:
                (partner.ownerName.isNotEmpty
                        ? partner.ownerName
                        : partner.businessName)
                    .isNotEmpty
                ? (partner.ownerName.isNotEmpty
                          ? partner.ownerName
                          : partner.businessName)[0]
                      .toUpperCase()
                : 'P',
            kycStatus: kycStatus,
          ),
          Expanded(
            child: pullToRefresh(
              onRefresh: () async {
                await ref.read(authStateProvider.notifier).refreshSession();
                ref.invalidate(myStoresProvider);
                ref.invalidate(myServicesProvider);
                ref.invalidate(partnerDashboardStatsProvider);
                await Future.wait([
                  ref.read(myStoresProvider.future),
                  ref.read(partnerDashboardStatsProvider.future),
                ]);
              },
              child: ListView(
                physics: alwaysScrollablePhysics,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageBottom,
                ),
                children: [
                  // KYC banner
                  if (!kycApproved && hasStores) ...[
                    _KycBanner(
                      status: kycStatus,
                      onTap: () => context.push('/kyc'),
                    ),
                    const SizedBox(height: _dashboardSectionGap),
                  ],

                  // Booking & revenue metrics
                  statsAsync.when(
                    loading: () => const SizedBox(
                      height: 212,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => const _MetricsPanel(
                      stats: PartnerDashboardStats(),
                    ),
                    data: (stats) => _MetricsPanel(stats: stats),
                  ),
                  const SizedBox(height: _dashboardSectionGap),

                  const SectionHeader(
                    title: 'Quick Actions',
                    compact: true,
                  ),
                  const SizedBox(height: _dashboardTitleGap),
                  _QuickActionsGrid(hasStores: hasStores),
                  const SizedBox(height: _dashboardSectionGap),

                  const SectionHeader(
                    title: 'Need Help?',
                    compact: true,
                  ),
                  const SizedBox(height: _dashboardTitleGap),
                  const _HelpContactCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.hasStores});

  final bool hasStores;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickActionRow(
          children: [
            QuickActionChip(
              expanded: true,
              icon: Icons.storefront_rounded,
              label: 'My Stores',
              color: AppColors.primary,
              onTap: () => context.push('/stores'),
            ),
            QuickActionChip(
              expanded: true,
              icon: Icons.verified_user_rounded,
              label: 'Upload KYC',
              color: const Color(0xFF5C6BC0),
              enabled: hasStores,
              onTap: () => context.push('/kyc'),
            ),
            QuickActionChip(
              expanded: true,
              icon: Icons.account_balance_rounded,
              label: 'Bank Account',
              color: AppColors.teal,
              enabled: hasStores,
              onTap: () => context.push('/bank'),
            ),
          ],
        ),
        const SizedBox(height: _dashboardGridGap),
        _QuickActionRow(
          children: [
            QuickActionChip(
              expanded: true,
              icon: Icons.inventory_2_rounded,
              label: 'Inventory',
              color: AppColors.warning,
              enabled: hasStores,
              onTap: () => context.push('/inventory'),
            ),
            QuickActionChip(
              expanded: true,
              icon: Icons.spa_rounded,
              label: 'Services',
              color: AppColors.secondary,
              enabled: hasStores,
              onTap: () => context.push('/services'),
            ),
            QuickActionChip(
              expanded: true,
              icon: Icons.person_rounded,
              label: 'Profile',
              color: const Color(0xFF546E7A),
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: _dashboardGridGap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.initial,
    required this.kycStatus,
  });
  final String name;
  final String initial;
  final String kycStatus;

  @override
  Widget build(BuildContext context) {
    return GradientPageHeader(
      title: name,
      subtitle: 'Welcome back!',
      initial: initial,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kycStatus == 'approved'
                  ? Icons.verified_rounded
                  : Icons.pending_rounded,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              kycStatus == 'approved' ? 'Verified' : 'KYC Pending',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KYC banner ────────────────────────────────────────────────────────────────

class _KycBanner extends StatelessWidget {
  const _KycBanner({required this.status, required this.onTap});
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final color = isRejected ? AppColors.error : AppColors.warning;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              isRejected ? Icons.cancel_rounded : Icons.info_outline_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRejected ? 'KYC Rejected' : 'KYC Pending',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    isRejected
                        ? 'Your KYC was rejected. Tap to re-upload.'
                        : 'Upload your documents to activate your stores.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.stats});

  final PartnerDashboardStats stats;

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  String _money(double value) => _currency.format(value);

  @override
  Widget build(BuildContext context) {
    final bookingRow = [
      _MetricItem(
        icon: Icons.calendar_month_rounded,
        label: 'Total Bookings',
        value: '${stats.totalBookings}',
        color: AppColors.primary,
      ),
      _MetricItem(
        icon: Icons.today_rounded,
        label: 'Today',
        value: '${stats.todayBookings}',
        color: const Color(0xFF1976D2),
      ),
      _MetricItem(
        icon: Icons.event_rounded,
        label: 'Tomorrow',
        value: '${stats.tomorrowBookings}',
        color: const Color(0xFF5C6BC0),
      ),
    ];

    final revenueRow = [
      _MetricItem(
        icon: Icons.payments_rounded,
        label: 'Lifetime',
        value: _money(stats.lifetimeRevenue),
        color: AppColors.success,
      ),
      _MetricItem(
        icon: Icons.history_rounded,
        label: 'Past Month',
        value: _money(stats.pastMonthRevenue),
        color: const Color(0xFF00897B),
      ),
      _MetricItem(
        icon: Icons.trending_up_rounded,
        label: 'This Month',
        value: _money(stats.thisMonthRevenue),
        color: AppColors.secondary,
      ),
    ];

    return Column(
      children: [
        _MetricRow(items: bookingRow),
        const SizedBox(height: _dashboardGridGap),
        _MetricRow(items: revenueRow),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: _dashboardGridGap),
            Expanded(child: _MetricCard(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      accentColor: item.color,
      compact: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  item.color.withValues(alpha: 0.16),
                  item.color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 16, color: item.color),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpContactCard extends StatelessWidget {
  const _HelpContactCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Contact PakeUp Support',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ContactLine(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            value: Env.supportWhatsApp,
            color: const Color(0xFF25D366),
            onTap: () => _launch(
              context,
              () => ExternalLinks.openWhatsApp(Env.supportWhatsApp),
              'WhatsApp',
            ),
          ),
          const SizedBox(height: 10),
          _ContactLine(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: Env.supportPhone,
            color: const Color(0xFF1976D2),
            onTap: () => _launch(
              context,
              () => ExternalLinks.openPhone(Env.supportPhone),
              'phone',
            ),
          ),
          const SizedBox(height: 10),
          _ContactLine(
            icon: Icons.email_outlined,
            label: 'Email',
            value: Env.supportEmail,
            color: AppColors.secondary,
            onTap: () => _launch(
              context,
              () => ExternalLinks.openEmail(Env.supportEmail),
              'email',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(
    BuildContext context,
    Future<bool> Function() action,
    String label,
  ) async {
    final ok = await action();
    if (!ok && context.mounted) {
      AppSnackBar.error(context, 'Could not open $label');
    }
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

