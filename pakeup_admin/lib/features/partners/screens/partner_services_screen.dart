import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../models/partner_service_models.dart';
import '../providers/partner_services_provider.dart';
import '../providers/partners_provider.dart';
import '../widgets/partner_empty_state.dart';
import '../widgets/partner_service_form_dialog.dart';
import '../widgets/partner_stat_chip.dart';
import '../widgets/partner_table_widgets.dart';

class PartnerServicesScreen extends ConsumerWidget {
  const PartnerServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(partnerServicesListProvider);
    final partnersAsync = ref.watch(partnersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.spa_rounded,
          title: 'Partner Services',
          subtitle:
              'Manage service menus and pricing for onboarded partners — catalog control like Zomato menus.',
          action: OutlinedButton.icon(
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Service'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
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
            final activeCount = services.where((s) => s.isActive).length;
            final inactiveCount = services.length - activeCount;
            final partnerCount =
                services.map((s) => s.partnerId).toSet().length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PartnerStatsRow(
                  chips: [
                    PartnerStatChip(
                      icon: Icons.miscellaneous_services_rounded,
                      label: 'Total Services',
                      value: '${services.length}',
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
                      label: 'Partners',
                      value: '$partnerCount',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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

                    if (services.isEmpty) {
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
                            child: const Row(
                              children: [
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
                          for (var i = 0; i < services.length; i++)
                            _ServiceRow(
                              service: services[i],
                              isLast: i == services.length - 1,
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
    if (context.mounted) {
      AppSnackBar.success(
        context,
        existing == null ? 'Service added' : 'Service updated',
      );
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    PartnerServiceRecord service,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

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
      if (context.mounted) AppSnackBar.error(context, e.toString());
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
    if (user == null) return;

    try {
      await ref.read(partnerServicesRepositoryProvider).deleteService(
            callerId: user.id,
            serviceId: service.id,
          );
      if (context.mounted) {
        AppSnackBar.success(context, '"${service.name}" deleted');
      }
      ref.invalidate(partnerServicesListProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
    }
  }
}

class _ServiceRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
