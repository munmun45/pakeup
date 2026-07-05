import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/header_search_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partners_repository.dart';
import '../providers/partners_provider.dart';
import '../providers/partner_table_focus_provider.dart';
import '../widgets/partner_parent_account_dialog.dart';
import '../widgets/partner_stat_chip.dart';
import '../../dashboard/widgets/header_search_bar.dart';
import '../widgets/partner_table_widgets.dart';
import '../utils/partner_navigation.dart';

class CreatePartnerScreen extends ConsumerWidget {
  const CreatePartnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(partnerOwnerAccountsListProvider);
    final accountFilter = ref.watch(partnerAccountStoreFilterProvider);
    final searchQuery =
        ref.watch(headerSearchQueryProvider).trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        accountsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => _ErrorCard(message: e.toString()),
          data: (accounts) {
            final activeCount = accounts.where((a) => a.isActive).length;
            final inactiveCount = accounts.length - activeCount;
            
            final filteredByAccount = accountFilter != null
                ? accounts.where((a) => a.id == accountFilter.accountId).toList()
                : accounts;

            final filtered = searchQuery.isEmpty
                ? filteredByAccount
                : filteredByAccount.where((a) {
                    final q = searchQuery;
                    return a.ownerName.toLowerCase().contains(q) ||
                        (a.phone?.toLowerCase().contains(q) ?? false) ||
                        (a.email?.toLowerCase().contains(q) ?? false) ||
                        (a.whatsapp?.toLowerCase().contains(q) ?? false);
                  }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: PartnerStatsRow(
                        chips: [
                          PartnerStatChip(
                            icon: Icons.groups_rounded,
                            label: 'Total Partners',
                            value: '${accounts.length}',
                            color: AppColors.secondary,
                          ),
                          PartnerStatChip(
                            icon: Icons.check_circle_outline,
                            label: 'Active',
                            value: '$activeCount',
                            color: AppColors.success,
                          ),
                          PartnerStatChip(
                            icon: Icons.person_off_outlined,
                            label: 'Inactive',
                            value: '$inactiveCount',
                            color: AppColors.error,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    const SizedBox(
                      width: 320,
                      child: HeaderSearchBar(pageKey: 'partner_create_account'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => _openCreateDialog(context, ref),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: const Text('Create Partner'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (accounts.isEmpty)
                  const _EmptyAccountsCard()
                else if (filtered.isEmpty)
                  _NoSearchResultsCard(query: searchQuery)
                else
                  _PartnerAccountsTable(
                    accounts: filtered,
                    onEdit: (a) => _openEditDialog(context, ref, a),
                    onDelete: (a) => _deleteAccount(context, ref, a),
                    onToggleActive: (a) => _toggleActive(context, ref, a),
                    onViewStores: (a) =>
                        PartnerNavigation.openAccountStores(ref, context, account: a),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PartnerParentAccountDialog(),
    );
    if (saved == true) {
      ref.invalidate(partnerOwnerAccountsListProvider);
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    PartnerOwnerAccount account,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PartnerParentAccountDialog(existing: account),
    );
    if (saved == true) {
      ref.invalidate(partnerOwnerAccountsListProvider);
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    PartnerOwnerAccount account,
  ) async {
    final activate = !account.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(activate ? 'Activate partner?' : 'Deactivate partner?'),
        content: Text(
          activate
              ? 'Make "${account.ownerName}" active? They can log in again.'
              : 'Deactivate "${account.ownerName}"? They will not be able to log in.',
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
    if (user == null) {
      if (context.mounted) {
        AppSnackBar.warning(context, 'Please sign in again');
      }
      return;
    }

    try {
      await ref.read(partnersRepositoryProvider).setPartnerAccountActive(
            callerId: user.id,
            accountId: account.id,
            active: activate,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          activate
              ? '"${account.ownerName}" activated'
              : '"${account.ownerName}" deactivated',
        );
      }
      ref.invalidate(partnerOwnerAccountsListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'update partner status', e);
      }
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    PartnerOwnerAccount account,
  ) async {
    final hasStores = account.storeCount > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete partner account?'),
        content: Text(
          hasStores
              ? 'Delete "${account.ownerName}" and all ${account.storeCount} '
                  'linked store(s)? This cannot be undone.'
              : 'Remove "${account.ownerName}" permanently? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(hasStores ? 'Delete All' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      if (context.mounted) {
        AppSnackBar.warning(context, 'Please sign in again');
      }
      return;
    }

    try {
      await ref.read(partnersRepositoryProvider).deletePartnerAccount(
            callerId: user.id,
            accountId: account.id,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          hasStores
              ? 'Partner "${account.ownerName}" and ${account.storeCount} store(s) deleted'
              : 'Partner "${account.ownerName}" deleted',
        );
      }
      ref.invalidate(partnerOwnerAccountsListProvider);
      ref.invalidate(partnersListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'delete partner account', e);
      }
    }
  }
}

class _PartnerAccountsTable extends StatelessWidget {
  const _PartnerAccountsTable({
    required this.accounts,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onViewStores,
  });

  final List<PartnerOwnerAccount> accounts;
  final void Function(PartnerOwnerAccount) onEdit;
  final void Function(PartnerOwnerAccount) onDelete;
  final void Function(PartnerOwnerAccount) onToggleActive;
  final void Function(PartnerOwnerAccount) onViewStores;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 1130.0;
        final table = Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.09),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.secondary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 160,
                      child: Text('OWNER', style: partnerTableHeaderStyle),
                    ),
                    _buildDivider(),
                    const SizedBox(
                      width: 110,
                      child: Text('PHONE', style: partnerTableHeaderStyle),
                    ),
                    _buildDivider(),
                    const SizedBox(
                      width: 150,
                      child: Text('EMAIL', style: partnerTableHeaderStyle),
                    ),
                    _buildDivider(),
                    const SizedBox(
                      width: 110,
                      child: Text('WHATSAPP', style: partnerTableHeaderStyle),
                    ),
                    _buildDivider(),
                    const SizedBox(
                      width: 70,
                      child: Text('STORES', style: partnerTableHeaderStyle),
                    ),
                    _buildDivider(),
                    const SizedBox(
                      width: 82,
                      child: Text('STATUS', style: partnerTableHeaderStyle),
                    ),
                    const Spacer(),
                    _buildDivider(),
                    const SizedBox(
                      width: 168,
                      child: Text(
                        'ACTIONS',
                        style: partnerTableHeaderStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < accounts.length; i++)
                _PartnerAccountRow(
                  account: accounts[i],
                  isLast: i == accounts.length - 1,
                  onEdit: () => onEdit(accounts[i]),
                  onDelete: () => onDelete(accounts[i]),
                  onToggleActive: () => onToggleActive(accounts[i]),
                  onViewStores: () => onViewStores(accounts[i]),
                ),
            ],
          ),
        );

        if (constraints.maxWidth < minWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: table),
          );
        }
        return table;
      },
    );
  }
}

Widget _buildDivider() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    width: 1,
    height: 20,
    color: AppColors.border.withValues(alpha: 0.6),
  );
}

Widget _buildContactColumn({
  required BuildContext context,
  required double width,
  required String? value,
  required String type, // 'phone' | 'email' | 'whatsapp'
}) {
  if (value == null || value.trim().isEmpty) {
    return SizedBox(
      width: width,
      child: const Text(
        '—',
        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      ),
    );
  }

  return SizedBox(
    width: width,
    child: InkWell(
      onTap: () async {
        // 1. Copy to clipboard
        await Clipboard.setData(ClipboardData(text: value));

        // 2. Determine Action URL
        try {
          Uri uri;
          String typeName;
          if (type == 'phone') {
            final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
            uri = Uri.parse('tel:$cleanPhone');
            typeName = 'phone call';
          } else if (type == 'email') {
            uri = Uri.parse('mailto:$value');
            typeName = 'email client';
          } else {
            final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
            uri = Uri.parse('https://wa.me/$cleanPhone');
            typeName = 'WhatsApp';
          }

          // 3. Launch URL
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            if (context.mounted) {
              AppSnackBar.success(context, 'Copied & opening $typeName');
            }
          } else {
            if (context.mounted) {
              AppSnackBar.success(context, 'Copied: $value (Could not open launcher)');
            }
          }
        } catch (e) {
          if (context.mounted) {
            AppSnackBar.success(context, 'Copied: $value');
          }
        }
      },
      child: Tooltip(
        message: type == 'phone'
            ? 'Click to copy & call'
            : type == 'email'
                ? 'Click to copy & email'
                : 'Click to copy & WhatsApp',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _PartnerAccountRow extends StatelessWidget {
  const _PartnerAccountRow({
    required this.account,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onViewStores,
  });

  final PartnerOwnerAccount account;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onViewStores;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: account.isActive ? 1 : 0.6,
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
              width: 160,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor:
                        AppColors.secondary.withValues(alpha: 0.12),
                    child: Text(
                      account.ownerName.isNotEmpty
                          ? account.ownerName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          account.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Tooltip(
                          message: 'Click to copy ID: ${account.id}',
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: account.id));
                              AppSnackBar.success(context, 'Copied ID: ${account.id}');
                            },
                            child: Text(
                              'ID: ${account.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildDivider(),
            _buildContactColumn(
              context: context,
              width: 110,
              value: account.phone,
              type: 'phone',
            ),
            _buildDivider(),
            _buildContactColumn(
              context: context,
              width: 150,
              value: account.email,
              type: 'email',
            ),
            _buildDivider(),
            _buildContactColumn(
              context: context,
              width: 110,
              value: account.whatsapp,
              type: 'whatsapp',
            ),
            _buildDivider(),
            SizedBox(
              width: 70,
              child: Text(
                '${account.storeCount}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: account.storeCount > 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            _buildDivider(),
            SizedBox(
              width: 82,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PartnerStatusBadge(isActive: account.isActive),
              ),
            ),
            const Spacer(),
            _buildDivider(),
            SizedBox(
              width: 168,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PartnerTableAction(
                    icon: Icons.storefront_outlined,
                    tooltip: 'My stores',
                    color: AppColors.primary,
                    onPressed: onViewStores,
                  ),
                  const SizedBox(width: 4),
                  PartnerTableAction(
                    icon: account.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    tooltip: account.isActive ? 'Deactivate' : 'Activate',
                    color: account.isActive
                        ? AppColors.warning
                        : AppColors.success,
                    onPressed: onToggleActive,
                  ),
                  const SizedBox(width: 4),
                  PartnerTableAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 4),
                  PartnerTableAction(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: AppColors.error,
                    onPressed: onDelete,
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

class _EmptyAccountsCard extends StatelessWidget {
  const _EmptyAccountsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.person_add_alt_1_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No partner accounts yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click "Create Partner" to add the first parent login account.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
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
        padding: const EdgeInsets.all(32),
        child: Text(
          'No partners match "$query".',
          style: const TextStyle(color: AppColors.textSecondary),
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
      color: AppColors.error.withValues(alpha: 0.06),
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
