import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/admin_pages.dart';
import '../../../core/providers/header_search_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/page_access_chips.dart';
import '../../shared/widgets/role_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../data/admin_users_repository.dart';
import '../providers/admin_users_provider.dart';

class ManageAdminsScreen extends ConsumerWidget {
  const ManageAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final adminsAsync = ref.watch(adminUsersListProvider);
    final searchQuery = ref.watch(headerSearchQueryProvider).trim().toLowerCase();

    if (user == null || !user.isSuperAdmin) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Super Admin access only',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Admin Users',
          subtitle:
              'Create admin accounts and control which pages each user can access.',
          action: FilledButton.icon(
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.person_add_rounded, size: 20),
            label: const Text('Add Admin'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        adminsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => _ErrorCard(message: e.toString()),
          data: (admins) {
            final activeCount =
                admins.where((admin) => admin.isActive).length;
            final inactiveCount = admins.length - activeCount;
            final filteredAdmins = searchQuery.isEmpty
                ? admins
                : admins.where((admin) {
                    final id = admin.id.toLowerCase();
                    final name = admin.name?.toLowerCase() ?? '';
                    final phone = admin.phone?.toLowerCase() ?? '';
                    return id.contains(searchQuery) ||
                        name.contains(searchQuery) ||
                        phone.contains(searchQuery);
                  }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 960 ? 3 : width >= 520 ? 2 : 1;
                    final chipWidth =
                        (width - 12 * (columns - 1)) / columns;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: chipWidth,
                          child: _StatChip(
                            icon: Icons.group_rounded,
                            label: 'Total Users',
                            value: '${admins.length}',
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: chipWidth,
                          child: _StatChip(
                            icon: Icons.check_circle_outline,
                            label: 'Active Users',
                            value: '$activeCount',
                            color: AppColors.success,
                          ),
                        ),
                        SizedBox(
                          width: chipWidth,
                          child: _StatChip(
                            icon: Icons.person_off_outlined,
                            label: 'Deactive Users',
                            value: '$inactiveCount',
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (admins.isEmpty)
                  const _EmptyAdminsCard()
                else if (filteredAdmins.isEmpty)
                  _NoSearchResultsCard(query: searchQuery)
                else
                  _AdminsListView(
                    admins: filteredAdmins,
                    onEdit: (admin) =>
                        _openForm(context, ref, existing: admin),
                    onDelete: (id) => _deleteAdmin(context, ref, id),
                    onToggleActive: (admin) =>
                        _toggleAdminActive(context, ref, admin),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static const _tableHeaderStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    color: AppColors.primaryDark,
  );
}

class _AdminsListView extends StatelessWidget {
  const _AdminsListView({
    required this.admins,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final List<AdminAccount> admins;
  final void Function(AdminAccount admin) onEdit;
  final void Function(String id) onDelete;
  final void Function(AdminAccount admin) onToggleActive;

  void _showDetails(BuildContext context, AdminAccount admin) {
    showDialog<void>(
      context: context,
      builder: (context) => _AdminDetailDialog(
        admin: admin,
        onEdit: () {
          Navigator.pop(context);
          onEdit(admin);
        },
        onDelete: () {
          Navigator.pop(context);
          onDelete(admin.id);
        },
        onToggleActive: () {
          Navigator.pop(context);
          onToggleActive(admin);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const tableMinWidth = 720.0;
        final table = Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 200,
                      child: Text(
                        'ADMIN',
                        style: ManageAdminsScreen._tableHeaderStyle,
                      ),
                    ),
                    const SizedBox(
                      width: 108,
                      child: Text(
                        'PHONE',
                        style: ManageAdminsScreen._tableHeaderStyle,
                      ),
                    ),
                    const SizedBox(
                      width: 112,
                      child: Text(
                        'ROLE',
                        style: ManageAdminsScreen._tableHeaderStyle,
                      ),
                    ),
                    const SizedBox(
                      width: 82,
                      child: Text(
                        'STATUS',
                        style: ManageAdminsScreen._tableHeaderStyle,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(
                      width: 148,
                      child: Text(
                        'ACTIONS',
                        style: ManageAdminsScreen._tableHeaderStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < admins.length; i++)
                _CompactAdminRow(
                  admin: admins[i],
                  isLast: i == admins.length - 1,
                  onView: () => _showDetails(context, admins[i]),
                  onEdit: () => onEdit(admins[i]),
                  onDelete: () => onDelete(admins[i].id),
                  onToggleActive: () => onToggleActive(admins[i]),
                ),
            ],
          ),
        );

        if (constraints.maxWidth < tableMinWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableMinWidth,
              child: table,
            ),
          );
        }

        return table;
      },
    );
  }
}

class _CompactAdminRow extends StatelessWidget {
  const _CompactAdminRow({
    required this.admin,
    required this.isLast,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final AdminAccount admin;
  final bool isLast;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: admin.isSuperAdmin || admin.isActive ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(8),
                  hoverColor: AppColors.primary.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            admin.id.isNotEmpty
                                ? admin.id[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                admin.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                '@${admin.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 108,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  admin.phone?.trim().isNotEmpty == true
                      ? admin.phone!
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: admin.phone?.trim().isNotEmpty == true
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 112,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TableBadgeWrap(
                  child: RoleBadge(
                    isSuperAdmin: admin.isSuperAdmin,
                    compact: true,
                    tableMode: true,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 82,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TableBadgeWrap(
                  child: _StatusBadge(
                    isActive: admin.isActive,
                    isSuperAdmin: admin.isSuperAdmin,
                    compact: true,
                  ),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 148,
              child: Align(
                alignment: Alignment.centerRight,
                child: admin.isSuperAdmin
                    ? _ActionButton(
                        icon: Icons.visibility_outlined,
                        tooltip: 'View',
                        color: AppColors.primary,
                        onPressed: onView,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ActionButton(
                            icon: Icons.visibility_outlined,
                            tooltip: 'View',
                            color: AppColors.primary,
                            onPressed: onView,
                          ),
                          const SizedBox(width: 4),
                          _ActionButton(
                            icon: admin.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            tooltip:
                                admin.isActive ? 'Deactivate' : 'Activate',
                            color: admin.isActive
                                ? AppColors.warning
                                : AppColors.success,
                            onPressed: onToggleActive,
                          ),
                          const SizedBox(width: 4),
                          _ActionButton(
                            icon: Icons.edit_outlined,
                            tooltip: 'Edit',
                            onPressed: onEdit,
                          ),
                          const SizedBox(width: 4),
                          _ActionButton(
                            icon: Icons.delete_outline,
                            tooltip: 'Delete',
                            color: AppColors.error,
                            onPressed: onDelete,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableBadgeWrap extends StatelessWidget {
  const _TableBadgeWrap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

class _AdminDetailDialog extends StatelessWidget {
  const _AdminDetailDialog({
    required this.admin,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final AdminAccount admin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      admin.id.isNotEmpty ? admin.id[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
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
                          admin.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${admin.id}',
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
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RoleBadge(
                    isSuperAdmin: admin.isSuperAdmin,
                    compact: true,
                  ),
                  _StatusBadge(
                    isActive: admin.isActive,
                    isSuperAdmin: admin.isSuperAdmin,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _DetailField(
                        icon: Icons.badge_outlined,
                        label: 'Admin ID',
                        value: admin.id,
                      ),
                      _DetailField(
                        icon: Icons.person_outline,
                        label: 'Full Name',
                        value: admin.name?.trim().isNotEmpty == true
                            ? admin.name!
                            : '—',
                      ),
                      _DetailField(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: admin.phone?.trim().isNotEmpty == true
                            ? admin.phone!
                            : '—',
                      ),
                      _DetailField(
                        icon: Icons.notes_outlined,
                        label: 'Notes',
                        value: admin.notes?.trim().isNotEmpty == true
                            ? admin.notes!
                            : '—',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Page access',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      PageAccessChips(
                        pageKeys: admin.pages,
                        allPages: admin.isSuperAdmin,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!admin.isSuperAdmin) ...[
                      _DialogActionButton(
                        label: admin.isActive ? 'Deactivate' : 'Activate',
                        icon: admin.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        onPressed: onToggleActive,
                        variant: admin.isActive
                            ? _DialogActionVariant.warning
                            : _DialogActionVariant.success,
                      ),
                      const SizedBox(width: 6),
                      _DialogActionButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onPressed: onEdit,
                        variant: _DialogActionVariant.primary,
                      ),
                      const SizedBox(width: 6),
                      _DialogActionButton(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        onPressed: onDelete,
                        variant: _DialogActionVariant.danger,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DialogActionVariant { primary, warning, success, danger }

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.variant,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final _DialogActionVariant variant;

  @override
  Widget build(BuildContext context) {
    final color = switch (variant) {
      _DialogActionVariant.primary => AppColors.primary,
      _DialogActionVariant.warning => AppColors.warning,
      _DialogActionVariant.success => AppColors.success,
      _DialogActionVariant.danger => AppColors.error,
    };

    final filled = variant == _DialogActionVariant.primary;

    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: filled ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on ManageAdminsScreen {
  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    AdminAccount? existing,
  }) async {
    final result = await showDialog<_AdminFormResult>(
      context: context,
      builder: (context) => _AdminFormDialog(existing: existing),
    );

    if (result == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final repo = ref.read(adminUsersRepositoryProvider);

    try {
      if (existing == null) {
        await repo.createAdmin(
          callerId: user.id,
          newId: result.id,
          password: result.password,
          pageKeys: result.pageKeys,
          name: result.name,
          phone: result.phone,
          notes: result.notes,
        );
      } else {
        await repo.updateAdmin(
          callerId: user.id,
          targetId: existing.id,
          pageKeys: result.pageKeys,
          name: result.name,
          phone: result.phone,
          notes: result.notes,
          newId: result.id != existing.id ? result.id : null,
          newPassword:
              result.password.isNotEmpty ? result.password : null,
        );
      }

      if (context.mounted) {
        AppSnackBar.success(
          context,
          existing == null
              ? 'Admin "${result.id}" created successfully'
              : result.id != existing.id
                  ? 'Admin updated — ID changed to "${result.id}"'
                  : 'Access updated for "${existing.id}"',
        );
      }

      ref.invalidate(adminUsersListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _toggleAdminActive(
    BuildContext context,
    WidgetRef ref,
    AdminAccount admin,
  ) async {
    final activate = !admin.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(activate ? 'Activate admin?' : 'Deactivate admin?'),
        content: Text(
          activate
              ? 'Allow "${admin.id}" to sign in again?'
              : 'Block "${admin.id}" from signing in? They can be reactivated later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  activate ? AppColors.success : AppColors.warning,
            ),
            child: Text(activate ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    try {
      await ref.read(adminUsersRepositoryProvider).setAdminActive(
            callerId: user.id,
            targetId: admin.id,
            active: activate,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          activate
              ? '"${admin.id}" activated'
              : '"${admin.id}" deactivated',
        );
      }

      ref.invalidate(adminUsersListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _deleteAdmin(
    BuildContext context,
    WidgetRef ref,
    String targetId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete admin?'),
        content: Text(
          'Remove admin "$targetId"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    try {
      await ref.read(adminUsersRepositoryProvider).deleteAdmin(
            callerId: user.id,
            targetId: targetId,
          );
      if (context.mounted) {
        AppSnackBar.success(context, 'Deleted "$targetId"');
      }

      ref.invalidate(adminUsersListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, e.toString());
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isActive,
    required this.isSuperAdmin,
    this.compact = false,
  });

  final bool isActive;
  final bool isSuperAdmin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (isSuperAdmin) {
      return _pill(
        label: 'Active',
        color: AppColors.success,
        icon: Icons.check_circle_outline,
      );
    }

    if (isActive) {
      return _pill(
        label: 'Active',
        color: AppColors.success,
        icon: Icons.check_circle_outline,
      );
    }

    return _pill(
      label: 'Inactive',
      color: AppColors.error,
      icon: Icons.block,
    );
  }

  Widget _pill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 17,
              color: color ?? AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoSearchResultsCard extends StatelessWidget {
  const _NoSearchResultsCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text(
              'No matching admins',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'No results for "$query". Try a different ID, name, or phone.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAdminsCard extends StatelessWidget {
  const _EmptyAdminsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No admin users yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click "Add Admin" to create your first admin user.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _AdminFormResult {
  _AdminFormResult({
    required this.id,
    required this.password,
    required this.pageKeys,
    this.name,
    this.phone,
    this.notes,
  });

  final String id;
  final String password;
  final List<String> pageKeys;
  final String? name;
  final String? phone;
  final String? notes;
}

class _AdminFormDialog extends StatefulWidget {
  const _AdminFormDialog({this.existing});

  final AdminAccount? existing;

  @override
  State<_AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<_AdminFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _passController;
  late final TextEditingController _confirmPassController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late final Set<String> _selectedPages;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.existing?.id ?? '');
    _passController = TextEditingController();
    _confirmPassController = TextEditingController();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.existing?.phone ?? '');
    _notesController =
        TextEditingController(text: widget.existing?.notes ?? '');
    _selectedPages = {...?widget.existing?.pages};
  }

  @override
  void dispose() {
    _idController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        _selectedPages.addAll(
          AdminPages.assignablePages().map((p) => p.key),
        );
      } else {
        _selectedPages.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = AdminPages.assignablePages();
    final allSelected = _selectedPages.length == pages.length;
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width * 0.78).clamp(720.0, 1100.0);
    final dialogHeight = (size.height * 0.88).clamp(620.0, 900.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Admin' : 'Add New Admin',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEdit
                                ? 'Update profile and page access for ${widget.existing!.id}'
                                : 'Create a new admin and assign page permissions',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AdminFormSection(
                                title: 'Account credentials',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _AdminFormField(
                                      controller: _idController,
                                      label: 'Admin ID',
                                      hint: 'e.g. manager',
                                      icon: Icons.badge_outlined,
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                              ? 'Required'
                                              : null,
                                    ),
                                    if (isEdit) ...[
                                      const SizedBox(height: 10),
                                      _PasswordKeepHint(),
                                    ],
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _AdminFormField(
                                            controller: _passController,
                                            label: isEdit
                                                ? 'New Password'
                                                : 'Password',
                                            hint: isEdit
                                                ? 'Optional'
                                                : 'Min 4 characters',
                                            icon: Icons.lock_outline,
                                            obscureText: true,
                                            validator: (v) {
                                              if (isEdit &&
                                                  (v == null || v.isEmpty)) {
                                                return null;
                                              }
                                              if (v == null || v.length < 4) {
                                                return 'Min 4 characters';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _AdminFormField(
                                            controller: _confirmPassController,
                                            label: 'Confirm Password',
                                            hint: isEdit
                                                ? 'Optional'
                                                : 'Re-enter password',
                                            icon: Icons.lock_reset_outlined,
                                            obscureText: true,
                                            validator: (v) {
                                              final pass =
                                                  _passController.text;
                                              if (isEdit && pass.isEmpty) {
                                                if (v == null || v.isEmpty) {
                                                  return null;
                                                }
                                                return 'Clear this field or enter a new password above';
                                              }
                                              if (v == null || v.isEmpty) {
                                                return 'Required';
                                              }
                                              if (v != pass) {
                                                return 'Passwords do not match';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _AdminFormSection(
                                title: 'Profile details',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _AdminFormField(
                                            controller: _nameController,
                                            label: 'Full Name',
                                            hint: 'e.g. Rahul Sharma',
                                            icon: Icons.person_outline,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _AdminFormField(
                                            controller: _phoneController,
                                            label: 'Phone Number',
                                            hint: 'e.g. 9876543210',
                                            icon: Icons.phone_outlined,
                                            keyboardType: TextInputType.phone,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    _AdminFormField(
                                      controller: _notesController,
                                      label: 'Notes',
                                      hint: 'Optional notes about this admin',
                                      icon: Icons.notes_outlined,
                                      maxLines: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Page Access',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => _toggleAll(!allSelected),
                                  child: Text(
                                    allSelected
                                        ? 'Deselect all'
                                        : 'Select all',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.background,
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: pages.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1, indent: 16),
                                  itemBuilder: (context, index) {
                                    final page = pages[index];
                                    return CheckboxListTile(
                                      title: Text(page.label),
                                      secondary: Icon(page.icon, size: 22),
                                      value: _selectedPages.contains(page.key),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedPages.add(page.key);
                                          } else {
                                            _selectedPages.remove(page.key);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                            if (_selectedPages.isEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Select at least one page',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        if (_selectedPages.isEmpty) {
                          setState(() {});
                          return;
                        }

                        Navigator.pop(
                          context,
                          _AdminFormResult(
                            id: _idController.text.trim(),
                            password: _passController.text,
                            pageKeys: _selectedPages.toList(),
                            name: _nameController.text.trim(),
                            phone: _phoneController.text.trim(),
                            notes: _notesController.text.trim(),
                          ),
                        );
                      },
                      child: Text(isEdit ? 'Save Changes' : 'Create Admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminFormSection extends StatelessWidget {
  const _AdminFormSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PasswordKeepHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Leave both password fields empty to keep the current password.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminFormField extends StatelessWidget {
  const _AdminFormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontSize: 14.5,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13.5,
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.65),
          fontSize: 13.5,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 18 : 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
