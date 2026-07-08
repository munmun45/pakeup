import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class KycStepSection extends StatelessWidget {
  const KycStepSection({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.required = false,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
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
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (required) ...[
                          const SizedBox(width: 3),
                          const Text(
                            '*',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class KycPropertyTypeSelector extends StatelessWidget {
  const KycPropertyTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.showError = false,
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final bool showError;

  static const options = [
    ('own', 'Own', Icons.home_outlined),
    ('lease', 'Lease', Icons.handshake_outlined),
    ('rent', 'Rent', Icons.key_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final hasError = showError && value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (key, label, icon) in options) ...[
              Expanded(
                child: InkWell(
                  onTap: enabled ? () => onChanged!(key) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: value == key
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: value == key
                            ? AppColors.primary
                            : hasError
                                ? AppColors.error.withValues(alpha: 0.7)
                                : AppColors.border,
                        width: value == key ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: value == key
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: value == key
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (key != 'rent') const SizedBox(width: 8),
            ],
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          const Text(
            'Property type is required',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
