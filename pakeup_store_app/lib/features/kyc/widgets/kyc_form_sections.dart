import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class KycStepSection extends StatelessWidget {
  const KycStepSection({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.required = false,
    this.icon,
  });

  final String step;
  final String title;
  final String subtitle;
  final Widget child;
  final bool required;
  /// Kept for older call sites; section headers are text-only now.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
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
