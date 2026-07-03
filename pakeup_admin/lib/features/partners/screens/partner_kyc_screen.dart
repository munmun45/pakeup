import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partners_repository.dart';
import '../providers/partners_provider.dart';
import '../widgets/partner_bank_details_dialog.dart';
import '../widgets/partner_detail_dialog.dart';
import '../widgets/partner_kyc_form_dialog.dart';
import '../widgets/partner_stat_chip.dart';
import '../widgets/partner_table_widgets.dart';

class PartnerKycScreen extends ConsumerWidget {
  const PartnerKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(partnersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.verified_user_rounded,
          title: 'Partner KYC',
          subtitle:
              'Review and approve partner identity and business documents before go-live.',
        ),
        const SizedBox(height: 24),
        partnersAsync.when(
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
          data: (partners) {
            final pending =
                partners.where((p) => p.kycStatus == 'pending').length;
            final approved =
                partners.where((p) => p.kycStatus == 'approved').length;
            final rejected =
                partners.where((p) => p.kycStatus == 'rejected').length;

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
                if (partners.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('Add partners first to review KYC.'),
                      ),
                    ),
                  )
                else
                  Card(
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
                                color:
                                    AppColors.primary.withValues(alpha: 0.18),
                              ),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'PARTNER',
                                  style: partnerTableHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 108,
                                child: Text(
                                  'KYC',
                                  style: partnerTableHeaderStyle,
                                ),
                              ),
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
                        for (var i = 0; i < partners.length; i++)
                          _KycRow(
                            partner: partners[i],
                            isLast: i == partners.length - 1,
                            onView: () => _showDetails(context, ref, partners[i]),
                            onUpload: () =>
                                _openKycUpload(context, ref, partners[i]),
                            onToggleKyc: () => _toggleKyc(
                              context,
                              ref,
                              partners[i],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
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
        onEdit: () => Navigator.pop(context),
        onDelete: () => Navigator.pop(context),
        onToggleActive: () => Navigator.pop(context),
      ),
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
      ref.invalidate(partnersListProvider);
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
    if (user == null) return;

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
      ref.invalidate(partnersListProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
    }
  }
}

class _KycRow extends StatelessWidget {
  const _KycRow({
    required this.partner,
    required this.isLast,
    required this.onView,
    required this.onUpload,
    required this.onToggleKyc,
  });

  final PartnerRecord partner;
  final bool isLast;
  final VoidCallback onView;
  final VoidCallback onUpload;
  final VoidCallback onToggleKyc;

  bool get _kycApproved => partner.kycStatus == 'approved';

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
            child: InkWell(
              onTap: onView,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      partner.businessName[0].toUpperCase(),
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
                          partner.businessName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          partner.ownerName,
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
            width: 108,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PartnerKycStatusBadge(status: partner.kycStatus),
            ),
          ),
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
                  tooltip: 'View',
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
