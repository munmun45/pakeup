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
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';
import '../models/dashboard_models.dart';
import '../providers/dashboard_provider.dart';

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
          // ── Fixed gradient header ──
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

          // ── Scrollable content ──
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // KYC banner
                  if (!kycApproved && hasStores) ...[
                    _KycBanner(
                      status: kycStatus,
                      onTap: () => context.push('/kyc'),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Booking & revenue metrics (horizontal scroll)
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
                  const SizedBox(height: 16),

                  // Quick actions — single horizontal scroll row
                  const _SectionTitle('Quick Actions'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickAction(
                          icon: Icons.storefront_rounded,
                          label: 'My Stores',
                          color: AppColors.primary,
                          onTap: () => context.push('/stores'),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.verified_user_rounded,
                          label: 'Upload KYC',
                          color: const Color(0xFF5C6BC0),
                          enabled: hasStores,
                          onTap: () => context.push('/kyc'),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.account_balance_rounded,
                          label: 'Bank Account',
                          color: const Color(0xFF00897B),
                          enabled: hasStores,
                          onTap: () => context.push('/bank'),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.inventory_2_rounded,
                          label: 'Inventory',
                          color: const Color(0xFFE65100),
                          enabled: hasStores,
                          onTap: () => context.push('/inventory'),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.spa_rounded,
                          label: 'Services',
                          color: AppColors.secondary,
                          enabled: hasStores,
                          onTap: () => context.push('/services'),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          color: const Color(0xFF546E7A),
                          onTap: () => context.push('/profile'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const _SectionTitle('Need Help?'),
                  const SizedBox(height: 10),
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

// ── Header ───────────────────────────────────────────────────────────────────

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
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // KYC badge
          Container(
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
        ],
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
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
        const SizedBox(height: 10),
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
            if (i > 0) const SizedBox(width: 10),
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 15, color: item.color),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
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
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
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

// ── Quick action tile ─────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? color : AppColors.textSecondary;
    return GestureDetector(
      onTap: enabled
          ? onTap
          : () => AppSnackBar.error(context, 'Add a store first'),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: SizedBox(
          width: 88,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
