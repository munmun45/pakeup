import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partners_repository.dart';
import '../models/partner_service_models.dart';
import '../providers/partner_services_provider.dart';
import '../providers/partner_table_focus_provider.dart';
import '../providers/partners_provider.dart';
import '../../../core/providers/header_search_provider.dart';
import '../widgets/partner_empty_state.dart';
import '../widgets/partner_hub_nav.dart';
import '../widgets/partner_service_form_dialog.dart';
import '../widgets/partner_stat_chip.dart';
import '../../dashboard/widgets/header_search_bar.dart';
import '../widgets/partner_table_widgets.dart';

class PartnerServicesScreen extends ConsumerWidget {
  const PartnerServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(partnerServicesListProvider);
    final partnersAsync = ref.watch(partnersListProvider);
    final focus = ref.watch(partnerTableFocusProvider);
    final searchQuery = ref.watch(headerSearchQueryProvider).trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PartnerFocusBanner(),
        servicesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(e.toString()),
            ),
          ),
          data: (services) {
            final accountFilter = ref.watch(partnerAccountStoreFilterProvider);
            final partners = partnersAsync.valueOrNull ?? [];
            final visible = services.where((s) {
              if (focus != null && s.partnerId != focus.partnerId) return false;
              if (accountFilter != null) {
                final partner = partners.firstWhere(
                  (p) => p.id == s.partnerId,
                  orElse: () => PartnerRecord(id: '', businessName: '', ownerName: ''),
                );
                if (partner.accountId != accountFilter.accountId) return false;
              }
              if (searchQuery.isNotEmpty) {
                final q = searchQuery;
                final matches = s.partnerName.toLowerCase().contains(q) ||
                    s.name.toLowerCase().contains(q) ||
                    (s.description?.toLowerCase().contains(q) ?? false) ||
                    s.price.toString().contains(q);
                if (!matches) return false;
              }
              return true;
            }).toList();

            final activeCount = visible.where((s) => s.isActive).length;
            final inactiveCount = visible.length - activeCount;
            final partnerCount =
                visible.map((s) => s.partnerId).toSet().length;

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
                            icon: Icons.miscellaneous_services_rounded,
                            label: 'Total Services',
                            value: '${visible.length}',
                            color: AppColors.primary,
                          ),
                          PartnerStatChip(
                            icon: Icons.visibility_rounded,
                            label: 'Active',
                            value: '$activeCount',
                            color: AppColors.success,
                          ),
                          PartnerStatChip(
                            icon: Icons.visibility_off_outlined,
                            label: 'Inactive',
                            value: '$inactiveCount',
                            color: AppColors.warning,
                          ),
                          PartnerStatChip(
                            icon: Icons.storefront_outlined,
                            label: 'Partners count',
                            value: '$partnerCount',
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    const SizedBox(
                      width: 320,
                      child: HeaderSearchBar(pageKey: 'partner_services'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () => _openForm(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Service'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                partnersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (partners) {
                    if (partners.isEmpty) {
                      return const PartnerEmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'No partners to manage services',
                        message:
                            'Add and approve partners first, then manage their service menus here.',
                      );
                    }

                    if (visible.isEmpty) {
                      return PartnerEmptyState(
                        icon: Icons.content_paste_search_rounded,
                        title: 'No services yet',
                        message:
                            '${partners.length} partner(s) onboarded. Click "Add Service" to create the first catalog item.',
                        action: OutlinedButton.icon(
                          onPressed: () => _openForm(context, ref),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Service'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      );
                    }

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.09),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'PARTNER',
                                    style: partnerTableHeaderStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'SERVICE',
                                    style: partnerTableHeaderStyle,
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    'PRICE',
                                    style: partnerTableHeaderStyle,
                                  ),
                                ),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    'DURATION',
                                    style: partnerTableHeaderStyle,
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    'STATUS',
                                    style: partnerTableHeaderStyle,
                                  ),
                                ),
                                Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    'ACTIONS',
                                    style: partnerTableHeaderStyle,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (var i = 0; i < visible.length; i++)
                            _ServiceRow(
                              service: visible[i],
                              isLast: i == visible.length - 1,
                              onEdit: () => _openForm(
                                context,
                                ref,
                                existing: services[i],
                              ),
                              onDelete: () =>
                                  _delete(context, ref, services[i]),
                              onToggle: () =>
                                  _toggleActive(context, ref, services[i]),
                            ),
                        ],
                      ),
                    );
                  },
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
    PartnerServiceRecord? existing,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PartnerServiceFormDialog(existing: existing),
    );
    if (result != true) return;

    ref.invalidate(partnerServicesListProvider);
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    PartnerServiceRecord service,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    final data = PartnerServiceFormData(
      partnerId: service.partnerId,
      name: service.name,
      description: service.description,
      price: service.price,
      durationMinutes: service.durationMinutes,
      isActive: !service.isActive,
    );

    try {
      await ref.read(partnerServicesRepositoryProvider).updateService(
            callerId: user.id,
            serviceId: service.id,
            data: data,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          service.isActive
              ? '"${service.name}" deactivated'
              : '"${service.name}" activated',
        );
      }
      ref.invalidate(partnerServicesListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'update service status', e);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PartnerServiceRecord service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Remove "${service.name}" from ${service.partnerName}? This cannot be undone.',
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
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    try {
      await ref.read(partnerServicesRepositoryProvider).deleteService(
            callerId: user.id,
            serviceId: service.id,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          'Service "${service.name}" deleted successfully',
        );
      }
      ref.invalidate(partnerServicesListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'delete service', e);
      }
    }
  }
}

class _ServiceRow extends ConsumerWidget {
  const _ServiceRow({
    required this.service,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final PartnerServiceRecord service;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    service.partnerName.isNotEmpty
                        ? service.partnerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    service.partnerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (service.description?.trim().isNotEmpty == true)
                  Text(
                    service.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '₹${service.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              '${service.durationMinutes} min',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          SizedBox(
            width: 90,
            child: PartnerStatusBadge(isActive: service.isActive),
          ),
          const Spacer(),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PartnerTableAction(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  color: AppColors.primary,
                  onPressed: onEdit,
                ),
                PartnerTableAction(
                  icon: service.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  tooltip: service.isActive ? 'Deactivate' : 'Activate',
                  color: AppColors.warning,
                  onPressed: onToggle,
                ),
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
    );
  }
}
