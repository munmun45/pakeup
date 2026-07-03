import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/page_access_chips.dart';
import '../../shared/widgets/role_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final profileAsync = ref.watch(adminProfileProvider);

    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    return profileAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (profile) {
        final dateFormat = DateFormat('dd MMM yyyy');
        final timeFormat = DateFormat('hh:mm a');
        final createdAt = profile.createdAt;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: Icons.person_rounded,
              title: 'My Profile',
              subtitle: 'Your account details and access permissions.',
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;

                final profileCard = _ProfileHeroCard(profile: profile);
                final detailsCard = _ProfileDetailsCard(
                  profile: profile,
                  dateFormat: dateFormat,
                  timeFormat: timeFormat,
                  createdAt: createdAt,
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 320, child: profileCard),
                      const SizedBox(width: 20),
                      Expanded(child: detailsCard),
                    ],
                  );
                }

                return Column(
                  children: [
                    profileCard,
                    const SizedBox(height: 20),
                    detailsCard,
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.profile});

  final AdminProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                profile.id.isNotEmpty ? profile.id[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.displayName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              profile.id,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            RoleBadge(isSuperAdmin: profile.isSuperAdmin),
            const SizedBox(height: 16),
            _StatusPill(isActive: profile.isActive),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({
    required this.profile,
    required this.dateFormat,
    required this.timeFormat,
    required this.createdAt,
  });

  final AdminProfile profile;
  final DateFormat dateFormat;
  final DateFormat timeFormat;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Account information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Admin ID',
              value: profile.id,
            ),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: profile.name?.trim().isNotEmpty == true
                  ? profile.name!
                  : '—',
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: profile.phone?.trim().isNotEmpty == true
                  ? profile.phone!
                  : '—',
            ),
            _InfoRow(
              icon: Icons.notes_outlined,
              label: 'Notes',
              value: profile.notes?.trim().isNotEmpty == true
                  ? profile.notes!
                  : '—',
            ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Account Created',
              value: createdAt != null
                  ? '${dateFormat.format(createdAt!.toLocal())} at ${timeFormat.format(createdAt!.toLocal())}'
                  : '—',
            ),
            _InfoRow(
              icon: Icons.shield_outlined,
              label: 'Role',
              value: profile.role.label,
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),
            const Text(
              'Page access',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            PageAccessChips(
              pageKeys: profile.pages,
              allPages: profile.isSuperAdmin,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_outline : Icons.block,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
