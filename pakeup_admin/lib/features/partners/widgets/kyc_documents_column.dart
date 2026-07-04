import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_kyc_models.dart';

class KycDocumentsColumn extends StatelessWidget {
  const KycDocumentsColumn({
    super.key,
    required this.row,
    this.onTap,
  });

  final PartnerKycOverviewRecord row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final docs = row.documentStatuses;
    final uploaded = row.uploadedDocCount;

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
              '$uploaded/${PartnerKycOverviewRecord.totalDocSlots} uploaded',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: uploaded > 0
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final doc in docs) _DocChip(doc: doc),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocChip extends StatelessWidget {
  const _DocChip({required this.doc});

  final KycDocStatusItem doc;

  @override
  Widget build(BuildContext context) {
    final color = doc.uploaded ? AppColors.success : AppColors.textSecondary;

    return Tooltip(
      message: doc.uploaded
          ? '${doc.fullLabel} uploaded'
          : '${doc.fullLabel} not uploaded',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: doc.uploaded
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: doc.uploaded
                ? AppColors.success.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              doc.uploaded ? Icons.check_rounded : Icons.remove_rounded,
              size: 10,
              color: color.withValues(alpha: doc.uploaded ? 1 : 0.5),
            ),
            const SizedBox(width: 2),
            Text(
              doc.shortLabel,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: doc.uploaded ? 1 : 0.65),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
