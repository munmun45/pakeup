import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
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

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.surface,
                  ],
                ),
                border: const Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      partner != null && partner.businessName.isNotEmpty
                          ? partner.businessName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner?.businessName ?? 'Partner',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        if (partner != null)
                          Text(
                            partner.ownerName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  const _MenuSectionTitle('Manage'),
                  _MenuTile(
                    icon: Icons.storefront_rounded,
                    label: 'My Stores',
                    color: AppColors.primary,
                    onTap: () => _closeAnd(context, () => context.push('/stores')),
                  ),
                  _MenuTile(
                    icon: Icons.add_business_rounded,
                    label: 'Add Store',
                    color: AppColors.primary,
                    onTap: () =>
                        _closeAnd(context, () => context.push('/stores/add')),
                  ),
                  _MenuTile(
                    icon: Icons.spa_rounded,
                    label: 'Services',
                    color: AppColors.secondary,
                    enabled: hasStores,
                    onTap: () =>
                        _closeAnd(context, () => context.push('/services')),
                  ),
                  _MenuTile(
                    icon: Icons.inventory_2_rounded,
                    label: 'Inventory',
                    color: const Color(0xFFE65100),
                    enabled: hasStores,
                    onTap: () =>
                        _closeAnd(context, () => context.go('/inventory-tab')),
                  ),
                  const SizedBox(height: 8),
                  const _MenuSectionTitle('Account'),
                  _MenuTile(
                    icon: Icons.verified_user_rounded,
                    label: 'KYC Documents',
                    color: const Color(0xFF5C6BC0),
                    enabled: hasStores,
                    onTap: () =>
                        _closeAnd(context, () => context.push('/kyc')),
                  ),
                  _MenuTile(
                    icon: Icons.account_balance_rounded,
                    label: 'Bank Account',
                    color: const Color(0xFF00897B),
                    enabled: hasStores,
                    onTap: () =>
                        _closeAnd(context, () => context.push('/bank')),
                  ),
                  _MenuTile(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    color: const Color(0xFF546E7A),
                    onTap: () =>
                        _closeAnd(context, () => context.push('/profile')),
                  ),
                  const SizedBox(height: 8),
                  const _MenuSectionTitle('More'),
                  _MenuTile(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    color: AppColors.primary,
                    onTap: () => _closeAnd(context, () => context.go('/home')),
                  ),
                  _MenuTile(
                    icon: Icons.calendar_month_rounded,
                    label: 'Bookings',
                    color: const Color(0xFF1976D2),
                    onTap: () =>
                        _closeAnd(context, () => context.go('/bookings')),
                  ),
                  _MenuTile(
                    icon: Icons.payments_rounded,
                    label: 'Payment',
                    color: const Color(0xFF00897B),
                    enabled: hasStores,
                    onTap: () =>
                        _closeAnd(context, () => context.go('/payment')),
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AppColors.error,
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign Out'),
                          content:
                              const Text('Are you sure you want to sign out?'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onTap: enabled
            ? onTap
            : () => AppSnackBar.error(context, 'Add a store first'),
      ),
    );
  }
}
