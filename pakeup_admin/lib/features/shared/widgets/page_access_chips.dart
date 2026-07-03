import 'package:flutter/material.dart';

import '../../../core/constants/admin_pages.dart';
import '../../../core/theme/app_theme.dart';

class PageAccessChips extends StatelessWidget {
  const PageAccessChips({
    super.key,
    required this.pageKeys,
    this.allPages = false,
  });

  final List<String> pageKeys;
  final bool allPages;

  @override
  Widget build(BuildContext context) {
    if (allPages) {
      return const _AccessChip(
        label: 'All pages',
        highlighted: true,
      );
    }

    if (pageKeys.isEmpty) {
      return Text(
        'No access',
        style: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.8),
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: pageKeys.map((key) {
        final label = AdminPages.byKey(key)?.label ?? key;
        return _AccessChip(label: label);
      }).toList(),
    );
  }
}

class _AccessChip extends StatelessWidget {
  const _AccessChip({
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.secondary.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? AppColors.secondary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: highlighted ? AppColors.secondary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
