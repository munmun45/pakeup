import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class KycDocumentUploadTile extends StatelessWidget {
  const KycDocumentUploadTile({
    super.key,
    required this.label,
    required this.icon,
    required this.fileName,
    required this.hasFile,
    required this.onPick,
    this.onView,
    this.required = true,
    this.sizeHint = 'PDF, JPG or PNG — max 1 MB',
    this.errorText,
  });

  final String label;
  final IconData icon;
  final String? fileName;
  final bool hasFile;
  final VoidCallback onPick;
  final VoidCallback? onView;
  final bool required;
  final String sizeHint;
  final String? errorText;

  bool get _hasError => errorText != null && errorText!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _hasError
            ? AppColors.error.withValues(alpha: 0.03)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _hasError
              ? AppColors.error.withValues(alpha: 0.55)
              : hasFile
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.border,
          width: _hasError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hasError
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: _hasError ? AppColors.error : AppColors.primary,
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
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (required) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (fileName != null) ...[
                      Text(
                        fileName!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      sizeHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(
                          alpha: fileName != null ? 0.85 : 1,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasFile && onView != null) ...[
                IconButton(
                  tooltip: 'View',
                  onPressed: onView,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
              OutlinedButton.icon(
                onPressed: onPick,
                icon: Icon(
                  hasFile ? Icons.refresh : Icons.upload_file,
                  size: 16,
                ),
                label: Text(hasFile ? 'Replace' : 'Upload'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _hasError ? AppColors.error : AppColors.primary,
                  side: BorderSide(
                    color: (_hasError ? AppColors.error : AppColors.primary)
                        .withValues(alpha: 0.4),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_hasError) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  });

  final String? value;
  final ValueChanged<String> onChanged;

  static const options = [
    ('own', 'Own', Icons.home_outlined),
    ('lease', 'Lease', Icons.handshake_outlined),
    ('rent', 'Rent', Icons.key_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (key, label, icon) in options) ...[
          Expanded(
            child: InkWell(
              onTap: () => onChanged(key),
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
    );
  }
}
