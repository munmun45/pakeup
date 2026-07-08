import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../models/partner_kyc_models.dart';
import 'partner_table_widgets.dart';

class PartnerAccountViewDialog extends StatelessWidget {
  const PartnerAccountViewDialog({super.key, required this.account});

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

  String _display(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return '—';
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final initial = account.ownerName.isNotEmpty
        ? account.ownerName[0].toUpperCase()
        : 'P';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.surface,
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.ownerName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Account ID: ${account.accountId}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (account.storeCount > 0)
                              Text(
                                '${account.storeCount} store${account.storeCount == 1 ? '' : 's'} linked',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                PartnerKycStatusBadge(
                                  status: account.accountStatus,
                                ),
                                _DocsStatusChip(complete: account.isComplete),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AccountInfoGrid(
                          items: [
                            _AccountInfoItem(
                              icon: Icons.person_outline,
                              label: 'Account Holder',
                              value: _display(account.bankAccountHolder),
                              muted: account.bankAccountHolder
                                      ?.trim()
                                      .isNotEmpty !=
                                  true,
                            ),
                            _AccountInfoItem(
                              icon: Icons.account_balance_outlined,
                              label: 'Bank Name',
                              value: _display(account.bankName),
                              muted:
                                  account.bankName?.trim().isNotEmpty != true,
                            ),
                            _AccountInfoItem(
                              icon: Icons.tag,
                              label: 'IFSC Code',
                              value: _display(account.ifscCode),
                              muted:
                                  account.ifscCode?.trim().isNotEmpty != true,
                            ),
                            _AccountInfoItem(
                              icon: Icons.numbers,
                              label: 'Account Number',
                              value: _display(account.accountNumber),
                              muted: account.accountNumber
                                      ?.trim()
                                      .isNotEmpty !=
                                  true,
                            ),
                            _AccountInfoItem(
                              icon: Icons.savings_outlined,
                              label: 'Account Type',
                              value: account.displayAccountType,
                              muted: account.accountType?.trim().isNotEmpty != true,
                            ),
                            _AccountInfoItem(
                              icon: Icons.payment_rounded,
                              label: 'UPI ID',
                              value: account.displayUpiId,
                              muted: account.upiId?.trim().isNotEmpty != true,
                            ),
                          ],
                        ),
                        if (account.accountUpdatedAt != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Last updated ${dateFmt.format(account.accountUpdatedAt!.toLocal())}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Passbook Document',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PassbookTile(
                          uploaded: account.hasPassbook,
                          onOpen: account.hasPassbook
                              ? () => _openPassbook(context)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
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

class _DocsStatusChip extends StatelessWidget {
  const _DocsStatusChip({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.folder_open_rounded : Icons.folder_off_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            complete ? 'Complete' : 'Incomplete',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoItem {
  const _AccountInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;
}

class _AccountInfoGrid extends StatelessWidget {
  const _AccountInfoGrid({required this.items});

  final List<_AccountInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.8),
                ),
              ),
            _AccountInfoRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({required this.item});

  final _AccountInfoItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            item.icon,
            size: 16,
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: item.muted
                      ? AppColors.textSecondary.withValues(alpha: 0.65)
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassbookTile extends StatelessWidget {
  const _PassbookTile({required this.uploaded, this.onOpen});

  final bool uploaded;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final color = uploaded ? AppColors.success : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: uploaded
            ? AppColors.success.withValues(alpha: 0.04)
            : AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: uploaded
              ? AppColors.success.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.menu_book_outlined,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bank Passbook / Cancelled Cheque',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  uploaded ? 'Document uploaded' : 'Not uploaded yet',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (uploaded && onOpen != null)
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Missing',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
