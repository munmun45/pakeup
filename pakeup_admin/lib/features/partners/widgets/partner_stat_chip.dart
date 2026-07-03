import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PartnerStatChip extends StatelessWidget {
  const PartnerStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PartnerStatsRow extends StatelessWidget {
  const PartnerStatsRow({super.key, required this.chips});

  final List<PartnerStatChip> chips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 960 ? 3 : width >= 520 ? 2 : 1;
        final chipWidth = (width - 12 * (columns - 1)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final chip in chips)
              SizedBox(width: chipWidth, child: chip),
          ],
        );
      },
    );
  }
}
