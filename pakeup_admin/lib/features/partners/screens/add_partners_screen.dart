import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/header_search_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partners_repository.dart';
import '../providers/partners_provider.dart';
import '../widgets/partner_detail_dialog.dart';
import '../widgets/partner_form_dialog.dart';
import '../widgets/partner_stat_chip.dart';
import '../widgets/partner_table_widgets.dart';

class AddPartnersScreen extends ConsumerWidget {
  const AddPartnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(partnersListProvider);
    final searchQuery =
        ref.watch(headerSearchQueryProvider).trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.storefront_rounded,
          title: 'Partner Management',
          subtitle:
              'Onboard, edit, and manage salon & beauty partners — view, activate, or deactivate anytime.',
          action: FilledButton.icon(
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.add_business_rounded, size: 20),
            label: const Text('Add Partner'),
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
        partnersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => _ErrorCard(message: e.toString()),
          data: (partners) {
            final activeCount =
                partners.where((p) => p.isActive).length;
            final inactiveCount = partners.length - activeCount;
            final filtered = searchQuery.isEmpty
                ? partners
                : partners.where((p) {
                    final q = searchQuery;
                    return p.businessName.toLowerCase().contains(q) ||
                        p.ownerName.toLowerCase().contains(q) ||
                        (p.phone?.toLowerCase().contains(q) ?? false) ||
                        (p.city?.toLowerCase().contains(q) ?? false) ||
                        (p.email?.toLowerCase().contains(q) ?? false);
                  }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PartnerStatsRow(
                  chips: [
                    PartnerStatChip(
                      icon: Icons.groups_rounded,
                      label: 'Total Partners',
                      value: '${partners.length}',
                      color: AppColors.primary,
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
                const SizedBox(height: 20),
                if (partners.isEmpty)
                  const _EmptyPartnersCard()
                else if (filtered.isEmpty)
                  _NoSearchResultsCard(query: searchQuery)
                else
                  _PartnersTable(
                    partners: filtered,
                    onView: (p) => _showDetails(context, ref, p),
                    onEdit: (p) => _openForm(context, ref, existing: p),
                    onDelete: (p) => _deletePartner(context, ref, p),
                    onToggleActive: (p) =>
                        _toggleActive(context, ref, p),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PartnerRecord? existing,
  }) async {
    final data = await showDialog<PartnerFormData>(
      context: context,
      builder: (context) => PartnerFormDialog(existing: existing),
    );
    if (data == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final repo = ref.read(partnersRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createPartner(callerId: user.id, data: data);
        if (context.mounted) {
          AppSnackBar.success(
            context,
            'Partner "${data.businessName}" added successfully',
          );
        }
      } else {
        await repo.updatePartner(
          callerId: user.id,
          partnerId: existing.id,
          data: data,
        );
        if (context.mounted) {
          AppSnackBar.success(
            context,
            'Partner "${data.businessName}" updated',
          );
        }
      }
      ref.invalidate(partnersListProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
    }
  }

  void _showDetails(
    BuildContext context,
    WidgetRef ref,
    PartnerRecord partner,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => PartnerDetailDialog(
        partner: partner,
        onEdit: () {
          Navigator.pop(context);
          _openForm(context, ref, existing: partner);
        },
        onDelete: () {
          Navigator.pop(context);
          _deletePartner(context, ref, partner);
        },
        onToggleActive: () {
          Navigator.pop(context);
          _toggleActive(context, ref, partner);
        },
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    PartnerRecord partner,
  ) async {
    final activate = !partner.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(activate ? 'Activate partner?' : 'Deactivate partner?'),
        content: Text(
          activate
              ? 'Make "${partner.businessName}" active and visible?'
              : 'Deactivate "${partner.businessName}"? They will be hidden from listings.',
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
      await ref.read(partnersRepositoryProvider).setPartnerActive(
            callerId: user.id,
            partnerId: partner.id,
            active: activate,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          activate
              ? '"${partner.businessName}" activated'
              : '"${partner.businessName}" deactivated',
        );
      }
      ref.invalidate(partnersListProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
    }
  }

  Future<void> _deletePartner(
    BuildContext context,
    WidgetRef ref,
    PartnerRecord partner,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete partner?'),
        content: Text(
          'Remove "${partner.businessName}" permanently? This cannot be undone.',
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
      await ref.read(partnersRepositoryProvider).deletePartner(
            callerId: user.id,
            partnerId: partner.id,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          'Deleted "${partner.businessName}"',
        );
      }
      ref.invalidate(partnersListProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
    }
  }
}

class _PartnersTable extends StatelessWidget {
  const _PartnersTable({
    required this.partners,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final List<PartnerRecord> partners;
  final void Function(PartnerRecord) onView;
  final void Function(PartnerRecord) onEdit;
  final void Function(PartnerRecord) onDelete;
  final void Function(PartnerRecord) onToggleActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 760.0;
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
                child: const Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: Text('PARTNER', style: partnerTableHeaderStyle),
                    ),
                    SizedBox(
                      width: 108,
                      child: Text('PHONE', style: partnerTableHeaderStyle),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text('CITY', style: partnerTableHeaderStyle),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text('CATEGORY', style: partnerTableHeaderStyle),
                    ),
                    SizedBox(
                      width: 82,
                      child: Text('STATUS', style: partnerTableHeaderStyle),
                    ),
                    Spacer(),
                    SizedBox(
                      width: 148,
                      child: Text(
                        'ACTIONS',
                        style: partnerTableHeaderStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < partners.length; i++)
                _PartnerRow(
                  partner: partners[i],
                  isLast: i == partners.length - 1,
                  onView: () => onView(partners[i]),
                  onEdit: () => onEdit(partners[i]),
                  onDelete: () => onDelete(partners[i]),
                  onToggleActive: () => onToggleActive(partners[i]),
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

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({
    required this.partner,
    required this.isLast,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final PartnerRecord partner;
  final bool isLast;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: partner.isActive ? 1 : 0.6,
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
              child: InkWell(
                onTap: onView,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          partner.businessName.isNotEmpty
                              ? partner.businessName[0].toUpperCase()
                              : 'P',
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
                              partner.businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              partner.ownerName,
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
            SizedBox(
              width: 108,
              child: Text(
                partner.phone?.trim().isNotEmpty == true
                    ? partner.phone!
                    : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: partner.phone?.trim().isNotEmpty == true
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                partner.city?.trim().isNotEmpty == true
                    ? partner.city!
                    : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            SizedBox(
              width: 110,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PartnerCategoryBadge(label: partner.displayCategory),
              ),
            ),
            SizedBox(
              width: 82,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PartnerStatusBadge(isActive: partner.isActive),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 148,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PartnerTableAction(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View',
                    color: AppColors.primary,
                    onPressed: onView,
                  ),
                  const SizedBox(width: 4),
                  PartnerTableAction(
                    icon: partner.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    tooltip: partner.isActive ? 'Deactivate' : 'Activate',
                    color: partner.isActive
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

class _EmptyPartnersCard extends StatelessWidget {
  const _EmptyPartnersCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.handshake_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No partners yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click "Add Partner" to onboard your first salon or beauty partner.',
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
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text(
              'No matching partners',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'No results for "$query".',
              style: const TextStyle(color: AppColors.textSecondary),
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
