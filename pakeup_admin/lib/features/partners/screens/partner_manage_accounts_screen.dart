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
import '../widgets/account_passbook_column.dart';
import '../widgets/partner_account_view_dialog.dart';
import '../../../core/providers/header_search_provider.dart';
import '../widgets/partner_bank_details_dialog.dart';
import '../widgets/partner_hub_nav.dart';
import '../widgets/partner_stat_chip.dart';
import '../widgets/partner_table_widgets.dart';

class PartnerManageAccountsScreen extends ConsumerWidget {
  const PartnerManageAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(partnerAccountsListProvider);
    final focus = ref.watch(partnerTableFocusProvider);
    final searchQuery = ref.watch(headerSearchQueryProvider).trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PartnerFocusBanner(),
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
            final accountFilter = ref.watch(partnerAccountStoreFilterProvider);
            final partners = ref.watch(partnersListProvider).valueOrNull ?? [];
            final visible = accounts.where((a) {
              if (focus != null && a.partnerId != focus.partnerId) return false;
              if (accountFilter != null) {
                final partner = partners.firstWhere(
                  (p) => p.id == a.partnerId,
                  orElse: () => PartnerRecord(id: '', businessName: '', ownerName: ''),
                );
                if (partner.accountId != accountFilter.accountId) return false;
              }
              if (searchQuery.isNotEmpty) {
                final q = searchQuery;
                final matches = a.businessName.toLowerCase().contains(q) ||
                    a.ownerName.toLowerCase().contains(q) ||
                    (a.bankName?.toLowerCase().contains(q) ?? false) ||
                    (a.accountNumber?.toLowerCase().contains(q) ?? false) ||
                    (a.ifscCode?.toLowerCase().contains(q) ?? false);
                if (!matches) return false;
              }
              return true;
            }).toList();

            final approved =
                visible.where((a) => a.accountStatus == 'approved').length;
            final pending =
                visible.where((a) => a.accountStatus == 'pending').length;
            final rejected =
                visible.where((a) => a.accountStatus == 'rejected').length;

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
                if (visible.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('Add partners first to manage accounts.'),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const minWidth = 920.0;
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
                                    width: 140,
                                    child: Text(
                                      'BANK',
                                      style: partnerTableHeaderStyle,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
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
                                    width: 88,
                                    child: Text(
                                      'DOCUMENT',
                                      style: partnerTableHeaderStyle,
                                    ),
                                  ),
                                  Spacer(),
                                  SizedBox(
                                    width: 120,
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
                              _AccountRow(
                                account: visible[i],
                                isLast: i == visible.length - 1,
                                onView: () =>
                                    _showAccountView(context, visible[i]),
                                onUpload: () => _openBankDetails(
                                  context,
                                  ref,
                                  visible[i],
                                ),
                                onToggleApproval: () => _toggleAccountApproval(
                                  context,
                                  ref,
                                  visible[i],
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

  void _showAccountView(BuildContext context, PartnerAccountRecord account) {
    showDialog<void>(
      context: context,
      builder: (context) => PartnerAccountViewDialog(account: account),
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
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

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
      if (context.mounted) {
        AppSnackBar.actionFailed(
          context,
          nextStatus == 'approved' ? 'approve account' : 'reject account',
          e,
        );
      }
    }
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({
    required this.account,
    required this.isLast,
    required this.onView,
    required this.onUpload,
    required this.onToggleApproval,
  });

  final PartnerAccountRecord account;
  final bool isLast;
  final VoidCallback onView;
  final VoidCallback onUpload;
  final VoidCallback onToggleApproval;

  bool get _isApproved => account.accountStatus == 'approved';

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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          account.ownerName,
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
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccountValueCell(
                    value: account.bankName ?? '—',
                    empty: account.bankName?.trim().isNotEmpty != true,
                  ),
                  if (account.ifscCode?.trim().isNotEmpty == true)
                    Text(
                      account.ifscCode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: _AccountValueCell(
                value: account.accountNumber?.trim().isNotEmpty == true
                    ? account.accountNumber!
                    : '—',
                empty: account.accountNumber?.trim().isNotEmpty != true,
              ),
            ),
            SizedBox(
              width: 108,
              child: Align(
                alignment: Alignment.centerLeft,
                child: PartnerKycStatusBadge(status: account.accountStatus),
              ),
            ),
            SizedBox(
              width: 88,
              child: AccountPassbookColumn(
                account: account,
                onTap: account.hasPassbook ? onView : onUpload,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 120,
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
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _AccountValueCell extends StatelessWidget {
  const _AccountValueCell({
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
