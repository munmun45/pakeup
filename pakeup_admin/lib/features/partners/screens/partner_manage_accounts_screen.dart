import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../data/partners_repository.dart';
import '../models/partner_kyc_models.dart';
import '../providers/partner_kyc_provider.dart';
import '../widgets/partner_bank_details_dialog.dart';
import '../widgets/partner_stat_chip.dart';
import '../widgets/partner_table_widgets.dart';

class PartnerManageAccountsScreen extends ConsumerWidget {
  const PartnerManageAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(partnerAccountsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Manage Accounts',
          subtitle:
              'Add and update partner bank account details and passbook documents.',
        ),
        const SizedBox(height: 24),
        accountsAsync.when(
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
          data: (accounts) {
            final approved =
                accounts.where((a) => a.accountStatus == 'approved').length;
            final pending =
                accounts.where((a) => a.accountStatus == 'pending').length;
            final rejected =
                accounts.where((a) => a.accountStatus == 'rejected').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PartnerStatsRow(
                  chips: [
                    PartnerStatChip(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
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
                if (accounts.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('Add partners first to manage accounts.'),
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
                                flex: 2,
                                child: Text(
                                  'PARTNER',
                                  style: partnerTableHeaderStyle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'BANK',
                                  style: partnerTableHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'ACCOUNT',
                                  style: partnerTableHeaderStyle,
                                ),
                              ),
                              SizedBox(
                                width: 108,
                                child: Text(
                                  'APPROVAL',
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
                        for (var i = 0; i < accounts.length; i++)
                          _AccountRow(
                            account: accounts[i],
                            isLast: i == accounts.length - 1,
                            onView: () => _showAccountView(context, accounts[i]),
                            onUpload: () =>
                                _openBankDetails(context, ref, accounts[i]),
                            onEdit: () =>
                                _openBankDetails(context, ref, accounts[i]),
                            onToggleApproval: () => _toggleAccountApproval(
                              context,
                              ref,
                              accounts[i],
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

  void _showAccountView(BuildContext context, PartnerAccountRecord account) {
    showDialog<void>(
      context: context,
      builder: (context) => _AccountViewDialog(account: account),
    );
  }

  Future<void> _openBankDetails(
    BuildContext context,
    WidgetRef ref,
    PartnerAccountRecord account,
  ) async {
    final partner = PartnerRecord(
      id: account.partnerId,
      businessName: account.businessName,
      ownerName: account.ownerName,
      isActive: account.isActive,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => PartnerBankDetailsDialog(partner: partner),
    );
    if (saved == true) {
      ref.invalidate(partnerAccountsListProvider);
    }
  }

  Future<void> _toggleAccountApproval(
    BuildContext context,
    WidgetRef ref,
    PartnerAccountRecord account,
  ) async {
    final nextStatus =
        account.accountStatus == 'approved' ? 'rejected' : 'approved';

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    try {
      await ref.read(partnerKycRepositoryProvider).setAccountStatus(
            callerId: user.id,
            partnerId: account.partnerId,
            status: nextStatus,
          );
      if (context.mounted) {
        AppSnackBar.success(
          context,
          'Account ${nextStatus == 'approved' ? 'approved' : 'rejected'} for "${account.businessName}"',
        );
      }
      ref.invalidate(partnerAccountsListProvider);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, e.toString());
    }
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.isLast,
    required this.onView,
    required this.onUpload,
    required this.onEdit,
    required this.onToggleApproval,
  });

  final PartnerAccountRecord account;
  final bool isLast;
  final VoidCallback onView;
  final VoidCallback onUpload;
  final VoidCallback onEdit;
  final VoidCallback onToggleApproval;

  bool get _isApproved => account.accountStatus == 'approved';

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
                      account.businessName[0].toUpperCase(),
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
                          account.businessName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          account.ownerName,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.bankName ?? '—',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (account.ifscCode?.trim().isNotEmpty == true)
                    Text(
                      account.ifscCode!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                account.maskedAccount,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 108,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PartnerKycStatusBadge(status: account.accountStatus),
              ),
            ),
            SizedBox(
              width: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PartnerTableAction(
                    icon: Icons.upload_file_outlined,
                    tooltip: 'Upload Account',
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
                    icon: _isApproved
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                    tooltip: _isApproved ? 'Reject Account' : 'Approve Account',
                    color: _isApproved ? AppColors.error : AppColors.success,
                    onPressed: onToggleApproval,
                  ),
                  const SizedBox(width: 4),
                  PartnerTableAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit Account',
                    color: AppColors.primary,
                    onPressed: onEdit,
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _AccountViewDialog extends StatelessWidget {
  const _AccountViewDialog({required this.account});

  final PartnerAccountRecord account;

  Future<void> _openPassbook(BuildContext context) async {
    final url = account.passbookDocUrl;
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppSnackBar.error(context, 'Could not open passbook document');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          account.ownerName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
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
              const SizedBox(height: 16),
              _ViewField(
                label: 'Account Holder',
                value: account.bankAccountHolder ?? '—',
              ),
              _ViewField(label: 'Bank Name', value: account.bankName ?? '—'),
              _ViewField(label: 'IFSC Code', value: account.ifscCode ?? '—'),
              _ViewField(
                label: 'Account Number',
                value: account.maskedAccount,
              ),
              _ViewField(
                label: 'Approval',
                value: switch (account.accountStatus) {
                  'approved' => 'Approved',
                  'rejected' => 'Rejected',
                  _ => 'Pending',
                },
              ),
              _ViewField(
                label: 'Documents',
                value: account.isComplete ? 'Complete' : 'Incomplete',
              ),
              if (account.hasPassbook) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openPassbook(context),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('View Passbook'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewField extends StatelessWidget {
  const _ViewField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
