import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/image_preview_dialog.dart';
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

const _tableHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.2,
  color: AppColors.textSecondary,
);

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
                    (s.ownerName?.toLowerCase().contains(q) ?? false) ||
                    (s.profileId?.toLowerCase().contains(q) ?? false) ||
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
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF9FA),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.border.withValues(alpha: 0.8),
                                  width: 1.2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'PARTNER',
                                    style: _tableHeaderStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'SERVICE',
                                    style: _tableHeaderStyle,
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    'STATUS',
                                    style: _tableHeaderStyle,
                                  ),
                                ),
                                Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    'ACTIONS',
                                    style: _tableHeaderStyle,
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
                                existing: visible[i],
                              ),
                              onDelete: () =>
                                  _delete(context, ref, visible[i]),
                              onToggle: () =>
                                  _toggleActive(context, ref, visible[i]),
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
      discountPrice: service.discountPrice,
      durationMinutes: service.durationMinutes,
      category: service.category,
      targetGender: service.targetGender,
      serviceLocation: service.serviceLocation,
      serviceImage: service.serviceImage,
      isFeatured: service.isFeatured,
      prepInstructions: service.prepInstructions,
      isActive: !service.isActive,
      isParlourAvailable: service.isParlourAvailable,
      parlourPrice: service.parlourPrice,
      parlourDurationMinutes: service.parlourDurationMinutes,
      parlourTargetGender: service.parlourTargetGender,
      parlourPriceMen: service.parlourPriceMen,
      parlourDurationMen: service.parlourDurationMen,
      parlourPriceWomen: service.parlourPriceWomen,
      parlourDurationWomen: service.parlourDurationWomen,
      parlourPrepMen: service.parlourPrepMen,
      parlourPrepWomen: service.parlourPrepWomen,
      isHomeAvailable: service.isHomeAvailable,
      homePrice: service.homePrice,
      homeDurationMinutes: service.homeDurationMinutes,
      homeTargetGender: service.homeTargetGender,
      homePriceMen: service.homePriceMen,
      homeDurationMen: service.homeDurationMen,
      homePriceWomen: service.homePriceWomen,
      homeDurationWomen: service.homeDurationWomen,
      homePrepMen: service.homePrepMen,
      homePrepWomen: service.homePrepWomen,
      freeRadiusKm: service.freeRadiusKm,
      perKmCharge: service.perKmCharge,
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

  Future<void> _copyProfileId(BuildContext context, String profileId) async {
    await Clipboard.setData(ClipboardData(text: profileId));
    if (context.mounted) {
      AppSnackBar.success(context, 'Profile ID copied');
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        Icons.spa_outlined,
        size: 20,
        color: AppColors.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If only women configurations are enabled anywhere, mark it as female
    final hasMen = (service.isParlourAvailable && service.parlourPriceMen != null) || 
                   (service.isHomeAvailable && service.homePriceMen != null);
    final hasWomen = (service.isParlourAvailable && service.parlourPriceWomen != null) || 
                     (service.isHomeAvailable && service.homePriceWomen != null);

    final isFemale = hasWomen && !hasMen;
    final isMale = hasMen && !hasWomen;

    final genderIcon = isFemale
        ? Icons.female_rounded
        : (isMale ? Icons.male_rounded : Icons.wc_rounded);

    final String genderLabel;
    final List<String> genders = [];
    if (service.isParlourAvailable) {
      final parlourGenders = [];
      if (service.parlourPriceMen != null) parlourGenders.add('Men');
      if (service.parlourPriceWomen != null) parlourGenders.add('Women');
      genders.add('Salon: ${parlourGenders.isEmpty ? 'Unisex' : parlourGenders.join('/')}');
    }
    if (service.isHomeAvailable) {
      final homeGenders = [];
      if (service.homePriceMen != null) homeGenders.add('Men');
      if (service.homePriceWomen != null) homeGenders.add('Women');
      genders.add('Home: ${homeGenders.isEmpty ? 'Unisex' : homeGenders.join('/')}');
    }
    genderLabel = genders.isEmpty ? 'Unisex' : genders.join(' · ');

    final profileId = service.profileId?.trim();
    final hasProfileId = profileId != null && profileId.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        hoverColor: AppColors.primary.withValues(alpha: 0.015),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // PARTNER column
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    MouseRegion(
                      cursor: (service.partnerPrimaryImage?.trim().isNotEmpty == true ||
                              (service.partnerImages.isNotEmpty && service.partnerImages.first.trim().isNotEmpty))
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        onTap: () {
                          final img = service.partnerPrimaryImage?.trim().isNotEmpty == true
                              ? service.partnerPrimaryImage!.trim()
                              : (service.partnerImages.isNotEmpty ? service.partnerImages.first.trim() : null);
                          if (img != null && img.isNotEmpty) {
                            showImagePreviewDialog(context, img, title: service.partnerName);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            backgroundImage: (service.partnerPrimaryImage?.trim().isNotEmpty == true)
                                ? NetworkImage(service.partnerPrimaryImage!.trim())
                                : (service.partnerImages.isNotEmpty && service.partnerImages.first.trim().isNotEmpty)
                                    ? NetworkImage(service.partnerImages.first.trim())
                                    : null,
                            child: (service.partnerPrimaryImage?.trim().isNotEmpty == true ||
                                    (service.partnerImages.isNotEmpty && service.partnerImages.first.trim().isNotEmpty))
                                ? null
                                : Text(
                                    service.partnerName.isNotEmpty
                                        ? service.partnerName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.partnerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 12,
                                color: AppColors.textSecondary.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${service.ownerName ?? '—'} · ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (hasProfileId)
                                GestureDetector(
                                  onTap: () => _copyProfileId(context, profileId),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Text(
                                      profileId,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'No Profile ID',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // SERVICE column
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final displayImg = (service.primaryImage?.trim().isNotEmpty == true)
                            ? service.primaryImage!.trim()
                            : (service.serviceImage?.trim().isNotEmpty == true
                                ? service.serviceImage!.trim()
                                : (service.images.isNotEmpty ? service.images.first.trim() : null));

                        return MouseRegion(
                          cursor: (displayImg != null && displayImg.isNotEmpty)
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: GestureDetector(
                            onTap: (displayImg != null && displayImg.isNotEmpty)
                                ? () => showImagePreviewDialog(context, displayImg, title: service.name)
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (displayImg != null && displayImg.isNotEmpty)
                                  ? Image.network(
                                      displayImg,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                                    )
                                  : _buildImagePlaceholder(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.secondary.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Text(
                                  service.category,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                genderIcon, 
                                size: 12, 
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                genderLabel,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                service.serviceLocation == 'At Home'
                                    ? 'At Home (Radius: ${service.freeRadiusKm}km · ₹${service.perKmCharge.toStringAsFixed(0)}/km)'
                                    : (service.serviceLocation == 'Both'
                                        ? 'Salon & Home (Radius: ${service.freeRadiusKm}km · ₹${service.perKmCharge.toStringAsFixed(0)}/km)'
                                        : 'At Salon Only'),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            service.description ?? 'No description provided.',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.85),
                              fontSize: 11.5,
                              fontStyle: service.description == null ? FontStyle.italic : FontStyle.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              

              
              // STATUS column
              SizedBox(
                width: 90,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: PartnerStatusBadge(isActive: service.isActive),
                ),
              ),
              
              const Spacer(),
              
              // ACTIONS column
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
                    const SizedBox(width: 4),
                    PartnerTableAction(
                      icon: service.isActive
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      tooltip: service.isActive ? 'Deactivate' : 'Activate',
                      color: AppColors.warning,
                      onPressed: onToggle,
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
      ),
    );
  }
}
