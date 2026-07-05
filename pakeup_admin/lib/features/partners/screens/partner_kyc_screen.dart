import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partners_repository.dart';
import '../models/partner_kyc_models.dart';
import '../providers/partner_kyc_provider.dart';
import '../providers/partner_table_focus_provider.dart';
import '../providers/partners_provider.dart';
import '../widgets/kyc_documents_column.dart';
import '../widgets/partner_bank_details_dialog.dart';
import '../utils/partner_navigation.dart';
import '../widgets/partner_hub_nav.dart';
import '../widgets/partner_kyc_documents_dialog.dart';
import '../widgets/partner_kyc_form_dialog.dart';
import '../widgets/partner_stat_chip.dart';
import '../widgets/partner_table_widgets.dart';

class PartnerKycScreen extends ConsumerWidget {
  const PartnerKycScreen({super.key});

  PartnerRecord _toPartnerRecord(PartnerKycOverviewRecord row) {
    return PartnerRecord(
      id: row.partnerId,
      businessName: row.businessName,
      ownerName: row.ownerName,
      isActive: row.isActive,
      kycStatus: row.kycStatus,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycAsync = ref.watch(partnerKycOverviewListProvider);
    final focus = ref.watch(partnerTableFocusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PartnerFocusBanner(),
        kycAsync.when(
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
          data: (rows) {
            final accountFilter = ref.watch(partnerAccountStoreFilterProvider);
            final partners = ref.watch(partnersListProvider).valueOrNull ?? [];
            final visible = rows.where((r) {
              if (focus != null && r.partnerId != focus.partnerId) return false;
              if (accountFilter != null) {
                final partner = partners.firstWhere(
                  (p) => p.id == r.partnerId,
                  orElse: () => PartnerRecord(id: '', businessName: '', ownerName: ''),
                );
                if (partner.accountId != accountFilter.accountId) return false;
              }
              return true;
            }).toList();

            final pending =
                visible.where((p) => p.kycStatus == 'pending').length;
            final approved =
                visible.where((p) => p.kycStatus == 'approved').length;
            final rejected =
                visible.where((p) => p.kycStatus == 'rejected').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PartnerStatsRow(
                  chips: [
                    PartnerStatChip(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending Review',
                      value: '$pending',
                      color: AppColors.warning,
                    ),
                    PartnerStatChip(
                      icon: Icons.verified_rounded,
                      label: 'Approved',
                      value: '$approved',
                      color: AppColors.success,
                    ),
                    PartnerStatChip(
                      icon: Icons.cancel_outlined,
                      label: 'Rejected',
                      value: '$rejected',
                      color: AppColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (visible.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('Add partners first to review KYC.'),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const minWidth = 1120.0;
                      final table = Card(
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
                                  SizedBox(
                                    width: 220,
                                    child: Text(
                                      'PARTNER',
                                      style: partnerTableHeaderStyle,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 118,
                                    child: Text(
                                      'PAN NO.',
                                      style: partnerTableHeaderStyle,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 132,
                                    child: Text(
                                      'AADHAAR NO.',
                                      style: partnerTableHeaderStyle,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      'KYC',
                                      style: partnerTableHeaderStyle,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 248,
                                    child: Text(
                                      'DOCUMENTS',
                                      style: partnerTableHeaderStyle,
                                    ),
                                  ),
                                  Spacer(),
                                  PartnerHubNavHeaders(),
                                  SizedBox(width: 12),
                                  SizedBox(
                                    width: 160,
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
                              _KycRow(
                                row: visible[i],
                                isLast: i == visible.length - 1,
                                onView: () => _viewDocuments(
                                  context,
                                  _toPartnerRecord(visible[i]),
                                ),
                                onUpload: () => _openKycUpload(
                                  context,
                                  ref,
                                  _toPartnerRecord(visible[i]),
                                ),
                                onToggleKyc: () => _toggleKyc(
                                  context,
                                  ref,
                                  _toPartnerRecord(visible[i]),
                                ),
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
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _viewDocuments(BuildContext context, PartnerRecord partner) {
    showDialog<void>(
      context: context,
      builder: (context) => PartnerKycDocumentsDialog(partner: partner),
    );
  }

  Future<void> _openKycUpload(
    BuildContext context,
    WidgetRef ref,
    PartnerRecord partner,
  ) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (context) => PartnerKycFormDialog(partner: partner),
    );
    if (result == true || result == 'open_bank') {
      ref.invalidate(partnerKycOverviewListProvider);
      ref.invalidate(partnersListProvider);
    }
    if (result == 'open_bank' && context.mounted) {
      await _openBankDetails(context, ref, partner);
    }
  }

  Future<void> _openBankDetails(
    BuildContext context,
    WidgetRef ref,
    PartnerRecord partner,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => PartnerBankDetailsDialog(partner: partner),
    );
    if (saved == true) {
      ref.invalidate(partnerKycOverviewListProvider);
    }
  }

  Future<void> _toggleKyc(
    BuildContext context,
    WidgetRef ref,
    PartnerRecord partner,
  ) async {
    final nextStatus =
        partner.kycStatus == 'approved' ? 'rejected' : 'approved';
    await _setKyc(context, ref, partner, nextStatus);
  }

  Future<void> _setKyc(
    BuildContext context,
    WidgetRef ref,
    PartnerRecord partner,
    String status,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    try {
      await ref.read(partnersRepositoryProvider).setPartnerKyc(
            callerId: user.id,
            partnerId: partner.id,
            status: status,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          'KYC ${status == 'approved' ? 'approved' : 'rejected'} for "${partner.businessName}"',
        );
      }
      ref.invalidate(partnerKycOverviewListProvider);
      ref.invalidate(partnersListProvider);
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.actionFailed(
          context,
          status == 'approved' ? 'approve KYC' : 'reject KYC',
          e,
        );
      }
    }
  }
}

class _KycRow extends ConsumerWidget {
  const _KycRow({
    required this.row,
    required this.isLast,
    required this.onView,
    required this.onUpload,
    required this.onToggleKyc,
  });

  final PartnerKycOverviewRecord row;
  final bool isLast;
  final VoidCallback onView;
  final VoidCallback onUpload;
  final VoidCallback onToggleKyc;

  bool get _kycApproved => row.kycStatus == 'approved';

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
          SizedBox(
            width: 220,
            child: InkWell(
              onTap: onView,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      row.businessName.isNotEmpty
                          ? row.businessName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          row.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          ),
          SizedBox(
            width: 118,
            child: _IdValueCell(
              value: row.displayPan,
              empty: row.panNumber?.trim().isNotEmpty != true,
            ),
          ),
          SizedBox(
            width: 132,
            child: _IdValueCell(
              value: row.displayAadhaar,
              empty: row.aadhaarNumber?.trim().isNotEmpty != true,
            ),
          ),
          SizedBox(
            width: 100,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PartnerKycStatusBadge(status: row.kycStatus),
            ),
          ),
          SizedBox(
            width: 248,
            child: KycDocumentsColumn(
              row: row,
              onTap: onView,
            ),
          ),
          const Spacer(),
          PartnerHubNavRow(
            partnerId: row.partnerId,
            businessName: row.businessName,
            currentPage: PartnerHubPage.kyc,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PartnerTableAction(
                  icon: Icons.upload_file_outlined,
                  tooltip: 'Upload KYC',
                  color: AppColors.primary,
                  onPressed: onUpload,
                ),
                const SizedBox(width: 4),
                PartnerTableAction(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View documents',
                  color: AppColors.textSecondary,
                  onPressed: onView,
                ),
                const SizedBox(width: 4),
                PartnerTableAction(
                  icon: _kycApproved
                      ? Icons.cancel_outlined
                      : Icons.check_circle_outline,
                  tooltip: _kycApproved ? 'Reject KYC' : 'Approve KYC',
                  color: _kycApproved ? AppColors.error : AppColors.success,
                  onPressed: onToggleKyc,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdValueCell extends StatelessWidget {
  const _IdValueCell({
    required this.value,
    required this.empty,
  });

  final String value;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
        fontStyle: empty ? FontStyle.italic : FontStyle.normal,
        color: empty
            ? AppColors.textSecondary.withValues(alpha: 0.65)
            : AppColors.textPrimary,
        letterSpacing: empty ? 0 : 0.3,
      ),
    );
  }
}
