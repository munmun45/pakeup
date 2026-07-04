import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_kyc_models.dart';

class AccountPassbookColumn extends StatelessWidget {
  const AccountPassbookColumn({
    super.key,
    required this.account,
    this.onTap,
  });

  final PartnerAccountRecord account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final uploaded = account.hasPassbook;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uploaded ? '1/1 uploaded' : '0/1 uploaded',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: uploaded
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 5),
            _PassbookChip(uploaded: uploaded),
          ],
        ),
      ),
    );
  }
}

class _PassbookChip extends StatelessWidget {
  const _PassbookChip({required this.uploaded});

  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    final color =
        uploaded ? AppColors.success : AppColors.textSecondary;

    return Tooltip(
      message: uploaded
          ? 'Passbook / cancelled cheque uploaded'
          : 'Passbook not uploaded',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: uploaded
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: uploaded
                ? AppColors.success.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              uploaded ? Icons.check_rounded : Icons.remove_rounded,
              size: 10,
              color: color.withValues(alpha: uploaded ? 1 : 0.5),
            ),
            const SizedBox(width: 2),
            Text(
              'PB',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: uploaded ? 1 : 0.65),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
