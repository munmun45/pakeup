import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'premium_card.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  factory StatusBadge.approved(String label) =>
      StatusBadge(label: label, color: AppColors.success, icon: Icons.check_circle_rounded);

  factory StatusBadge.pending(String label) =>
      StatusBadge(label: label, color: AppColors.warning, icon: Icons.schedule_rounded);

  factory StatusBadge.rejected(String label) =>
      StatusBadge(label: label, color: AppColors.error, icon: Icons.cancel_rounded);

  factory StatusBadge.info(String label) =>
      StatusBadge(label: label, color: AppColors.info, icon: Icons.info_outline_rounded);

  static StatusBadge forKyc(String status) => switch (status) {
        'approved' => StatusBadge.approved('Approved'),
        'rejected' => StatusBadge.rejected('Rejected'),
        _ => StatusBadge.pending('Pending'),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: margin,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}

class QuickActionChip extends StatelessWidget {
  const QuickActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final bool expanded;

  static const double _radius = 10;
  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: expanded
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(_radius),
              splashColor: color.withValues(alpha: 0.08),
              highlightColor: color.withValues(alpha: 0.04),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 6 : 8,
                  vertical: expanded ? 8 : 6,
                ),
                child: _buildInline(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      padding: EdgeInsets.all(expanded ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Icon(icon, color: color, size: _iconSize),
    );
  }

  Widget _buildInline() {
    return Row(
      children: [
        _iconBox(),
        SizedBox(width: expanded ? 6 : 8),
        Expanded(
          child: Text(
            label,
            maxLines: expanded ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: expanded ? 9.5 : 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class GradientPageHeader extends StatelessWidget {
  const GradientPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.initial,
    this.trailing,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final String? initial;
  final Widget? trailing;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Row(
        children: [
          if (initial != null)
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                initial!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          if (initial != null) const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
                if (badge != null) ...[
                  const SizedBox(height: 8),
                  badge!,
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
