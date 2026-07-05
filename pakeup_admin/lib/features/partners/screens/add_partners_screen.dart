import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/header_search_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partners_repository.dart';
import '../providers/partner_table_focus_provider.dart';
import '../providers/partners_provider.dart';
import '../widgets/partner_detail_dialog.dart';
import '../widgets/partner_form_dialog.dart';
import '../widgets/partner_hub_nav.dart';
import '../widgets/partner_stat_chip.dart';
import '../widgets/partner_table_widgets.dart';

class AddPartnersScreen extends ConsumerWidget {
  const AddPartnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(partnersListProvider);
    final focus = ref.watch(partnerTableFocusProvider);
    final accountFilter = ref.watch(partnerAccountStoreFilterProvider);
    final searchQuery =
        ref.watch(headerSearchQueryProvider).trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PartnerFocusBanner(),
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
            final visible = accountFilter != null
                ? filterByAccountStores(
                    filtered,
                    accountFilter,
                    (p) => p.accountId,
                  )
                : filterByPartnerFocus(
                    filtered,
                    focus,
                    (p) => p.id,
                  );

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
                            icon: Icons.storefront_rounded,
                            label: 'Inactive',
                            value: '$inactiveCount',
                            color: AppColors.error,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    FilledButton.icon(
                      onPressed: () => _openStoreForm(context, ref),
                      icon: const Icon(Icons.add_business_rounded, size: 20),
                      label: const Text('Add Store'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (partners.isEmpty)
                  const _EmptyPartnersCard()
                else if (visible.isEmpty)
                  _NoSearchResultsCard(query: searchQuery)
                else
                  _PartnersTable(
                    partners: visible,
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

  Future<void> _openStoreForm(
    BuildContext context,
    WidgetRef ref, {
    PartnerRecord? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PartnerFormDialog(
        existing: existing,
        storeOnlyMode: true,
      ),
    );
    if (saved == true) {
      ref.invalidate(partnersListProvider);
      ref.invalidate(partnerOwnerAccountsListProvider);
    }
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PartnerRecord? existing,
  }) async {
    await _openStoreForm(context, ref, existing: existing);
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
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

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
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'update partner status', e);
      }
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
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    try {
      await ref.read(partnersRepositoryProvider).deletePartner(
            callerId: user.id,
            partnerId: partner.id,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          'Partner "${partner.businessName}" deleted successfully',
        );
      }
      ref.invalidate(partnersListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(context, 'delete partner', e);
      }
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
        final minWidth = partnerTableMinWidth(
          hubColumnWidth: 0,
        );
        final table = Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const PartnerTableColumn(
                      width: partnerTableStoreDetailsWidth,
                      child:
                          Text('STORE DETAILS', style: partnerTableHeaderStyle),
                    ),
                    const PartnerTableColumn(
                      width: partnerTableCityWidth,
                      child: Text('CONTACT & ADDRESS', style: partnerTableHeaderStyle),
                    ),
                    const PartnerTableColumn(
                      width: partnerTableCategoryWidth,
                      child: Text('CATEGORY', style: partnerTableHeaderStyle),
                    ),
                    const PartnerTableColumn(
                      width: partnerTableStatusWidth,
                      child: Text('STATUS', style: partnerTableHeaderStyle),
                    ),
                    const Spacer(),
                    PartnerTableColumn(
                      width: partnerTableActionsColumnWidth,
                      showDivider: false,
                      align: Alignment.centerRight,
                      child: const Text(
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

class _PartnerRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final accountFilter = ref.watch(partnerAccountStoreFilterProvider);
    final isAccountFilterActive = partner.accountId != null &&
        accountFilter?.accountId == partner.accountId;

    return Opacity(
      opacity: partner.isActive ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isAccountFilterActive
              ? AppColors.primary.withValues(alpha: 0.04)
              : null,
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PartnerTableColumn(
              width: partnerTableStoreDetailsWidth,
              child: _StoreDetailsCell(
                partner: partner,
                isAccountFilterActive: isAccountFilterActive,
              ),
            ),
            PartnerTableColumn(
              width: partnerTableCityWidth,
              child: _ContactAddressCell(partner: partner),
            ),
            PartnerTableColumn(
              width: partnerTableCategoryWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PartnerCategoryBadge(label: partner.displayCategory),
              ),
            ),
            PartnerTableColumn(
              width: partnerTableStatusWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PartnerStatusBadge(isActive: partner.isActive),
              ),
            ),
            const Spacer(),
            PartnerTableColumn(
              width: partnerTableActionsColumnWidth,
              showDivider: false,
              align: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreDetailsCell extends ConsumerWidget {
  const _StoreDetailsCell({
    required this.partner,
    required this.isAccountFilterActive,
  });

  final PartnerRecord partner;
  final bool isAccountFilterActive;

  Future<void> _copyAndCallPhone(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: digits));

    final uri = Uri(scheme: 'tel', path: digits);
    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!context.mounted) return;
    if (opened) {
      AppSnackBar.success(context, 'Phone copied · opening dialer');
    } else {
      AppSnackBar.success(context, 'Phone number copied');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneRaw = (partner.accountPhone ?? partner.phone)?.trim();
    final hasPhone = phoneRaw != null && phoneRaw.isNotEmpty;
    final phone = hasPhone ? phoneRaw : 'No phone';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partner.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (partner.storeCount > 1 && partner.accountId != null)
                      _OwnerStoresChip(
                        count: partner.storeCount,
                        active: isAccountFilterActive,
                        onTap: () {
                          ref
                              .read(partnerAccountStoreFilterProvider.notifier)
                              .state = PartnerAccountStoreFilter(
                            accountId: partner.accountId!,
                            ownerName: partner.ownerName,
                            storeCount: partner.storeCount,
                          );
                          ref.read(partnerTableFocusProvider.notifier).state =
                              null;
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: hasPhone
                          ? Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${partner.ownerName} · ',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                   onTap: () =>
                                       _copyAndCallPhone(context, phoneRaw),
                                   child: MouseRegion(
                                     cursor: SystemMouseCursors.click,
                                     child: Text(
                                       phone,
                                       style: const TextStyle(
                                         fontSize: 11.5,
                                         fontWeight: FontWeight.w600,
                                         color: AppColors.primary,
                                       ),
                                     ),
                                   ),
                                 ),
                              ],
                            )
                          : Text(
                              partner.ownerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.95),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerStoresChip extends StatelessWidget {
  const _OwnerStoresChip({
    required this.count,
    required this.onTap,
    this.active = false,
  });

  final int count;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: active
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.secondary.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 12,
                  color: active ? AppColors.primary : AppColors.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count stores',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.primary : AppColors.secondary,
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

class _ContactAddressCell extends StatelessWidget {
  const _ContactAddressCell({required this.partner});

  final PartnerRecord partner;

  Future<void> _launchMap(BuildContext context) async {
    final lat = partner.latitude;
    final lng = partner.longitude;
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      final address = [
        partner.addressLine,
        partner.city,
        partner.state,
        partner.pincode,
      ].where((e) => e != null && e.trim().isNotEmpty).join(', ');
      if (address.isEmpty) {
        AppSnackBar.warning(context, 'No address or location details found for this store');
        return;
      }
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        AppSnackBar.error(context, 'Could not open Google Maps');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, 'Error opening map: $e');
      }
    }
  }

  Future<void> _copyAndCallPhone(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: digits));

    final uri = Uri(scheme: 'tel', path: digits);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!context.mounted) return;
    if (opened) {
      AppSnackBar.success(context, 'Phone copied · opening dialer');
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String whatsapp) async {
    final digits = whatsapp.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    final uri = Uri.parse('https://wa.me/$digits');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!context.mounted) return;
    if (!opened) {
      AppSnackBar.error(context, 'Could not open WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = partner.phone?.trim();
    final whatsapp = partner.whatsapp?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;
    final hasWhatsapp = whatsapp != null && whatsapp.isNotEmpty;

    final address = [
      partner.addressLine,
      partner.city,
      partner.state,
      partner.pincode,
    ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasPhone || hasWhatsapp) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (hasPhone)
                GestureDetector(
                  onTap: () => _copyAndCallPhone(context, phone),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_rounded, size: 10, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (hasWhatsapp)
                GestureDetector(
                  onTap: () => _openWhatsApp(context, whatsapp),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _WhatsappIcon(size: 10),
                          const SizedBox(width: 4),
                          Text(
                            whatsapp,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        GestureDetector(
          onTap: () => _launchMap(context),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 11,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    address.isNotEmpty ? address : 'Click to pin location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: address.isNotEmpty ? FontWeight.w500 : FontWeight.w600,
                      color: address.isNotEmpty ? AppColors.textSecondary : AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: address.isNotEmpty
                          ? AppColors.textSecondary.withValues(alpha: 0.4)
                          : AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WhatsappIcon extends StatelessWidget {
  const _WhatsappIcon({this.size = 11});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.chat_bubble_rounded,
          size: size + 2,
          color: const Color(0xFF25D366),
        ),
        Positioned(
          top: (size + 2) * 0.15,
          child: Icon(
            Icons.phone_rounded,
            size: (size + 2) * 0.55,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
