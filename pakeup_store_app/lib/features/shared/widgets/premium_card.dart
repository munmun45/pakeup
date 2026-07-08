import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared premium card look — soft elevation, clean white surface.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.accentColor,
    this.radius = 18,
    this.compact = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final double radius;
  final bool compact;

  static BoxDecoration decoration({
    Color? accent,
    double radius = 18,
    bool compact = false,
  }) {
    final tint = accent ?? AppColors.primary;
    if (compact) {
      return BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.09),
            blurRadius: 14,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
        ],
      );
    }
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.border.withValues(alpha: 0.55),
      ),
      boxShadow: [
        BoxShadow(
          color: tint.withValues(alpha: 0.1),
          blurRadius: 28,
          offset: const Offset(0, 10),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: decoration(
        accent: accentColor,
        radius: radius,
        compact: compact,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
