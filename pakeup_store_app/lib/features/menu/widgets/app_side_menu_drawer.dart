import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/partner_kyc_status.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/providers/stores_provider.dart';

class AppSideMenuDrawer extends ConsumerWidget {
  const AppSideMenuDrawer({super.key});

  void _closeAnd(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasStores = ref.watch(hasStoresProvider);
    final partner = ref.watch(authStateProvider).valueOrNull;
    final stores = ref.watch(myStoresProvider).valueOrNull ?? const [];
    final kycStatus = PartnerKycStatus.resolve(
      stores: stores,
      accountStatus: partner?.kycStatus,
    );

    final displayName = partner != null && partner.ownerName.trim().isNotEmpty
        ? partner.ownerName.trim()
        : 'Partner';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P';

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 16,
              8,
              20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _KycBadge(status: kycStatus),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SectionLabel('Manage'),
                _MenuTile(
                  icon: Icons.storefront_rounded,
                  label: 'My Stores',
                  onTap: () => _closeAnd(context, () => context.push('/stores')),
                ),
                _MenuTile(
                  icon: Icons.add_business_rounded,
                  label: 'Add Store',
                  onTap: () =>
                      _closeAnd(context, () => context.push('/stores/add')),
                ),
                _MenuTile(
                  icon: Icons.spa_rounded,
                  label: 'Services',
                  enabled: hasStores,
                  onTap: () =>
                      _closeAnd(context, () => context.push('/services')),
                ),
                _MenuTile(
                  icon: Icons.inventory_2_rounded,
                  label: 'Inventory',
                  enabled: hasStores,
                  onTap: () =>
                      _closeAnd(context, () => context.go('/inventory-tab')),
                ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                _SectionLabel('Account'),
                _MenuTile(
                  icon: Icons.verified_user_rounded,
                  label: 'KYC Documents',
                  enabled: hasStores,
                  onTap: () => _closeAnd(context, () => context.push('/kyc')),
                ),
                _MenuTile(
                  icon: Icons.account_balance_rounded,
                  label: 'Bank Account',
                  enabled: hasStores,
                  onTap: () => _closeAnd(context, () => context.push('/bank')),
                ),
                _MenuTile(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  onTap: () =>
                      _closeAnd(context, () => context.push('/profile')),
                ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                _SectionLabel('More'),
                _MenuTile(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  onTap: () => _closeAnd(context, () => context.go('/home')),
                ),
                _MenuTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Bookings',
                  onTap: () =>
                      _closeAnd(context, () => context.go('/bookings')),
                ),
                _MenuTile(
                  icon: Icons.payments_rounded,
                  label: 'Payment',
                  enabled: hasStores,
                  onTap: () =>
                      _closeAnd(context, () => context.go('/payment')),
                ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                _MenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  destructive: true,
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(authStateProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KycBadge extends StatelessWidget {
  const _KycBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'approved';
    final rejected = status == 'rejected';
    final label = approved
        ? 'KYC Verified'
        : rejected
            ? 'KYC Rejected'
            : 'KYC Pending';
    final color = approved
        ? AppColors.success
        : rejected
            ? AppColors.error
            : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: approved || rejected
            ? color.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: approved || rejected
              ? color.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approved
                ? Icons.verified_rounded
                : rejected
                    ? Icons.cancel_rounded
                    : Icons.pending_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.textSecondary
        : destructive
            ? AppColors.error
            : AppColors.textPrimary;

    return ListTile(
      enabled: enabled,
      onTap: enabled
          ? onTap
          : () => AppSnackBar.error(context, 'Add a store first'),
      leading: Icon(icon, size: 22, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: color,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      visualDensity: VisualDensity.compact,
    );
  }
}
