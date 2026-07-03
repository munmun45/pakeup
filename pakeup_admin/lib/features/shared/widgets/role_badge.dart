import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.isSuperAdmin,
    this.compact = false,
    this.tableMode = false,
  });

  final bool isSuperAdmin;
  final bool compact;
  final bool tableMode;

  @override
  Widget build(BuildContext context) {
    final color = isSuperAdmin ? AppColors.secondary : AppColors.primary;
    final label = isSuperAdmin
        ? (tableMode ? 'Super' : 'Super Admin')
        : 'Admin';

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuperAdmin ? Icons.verified_user_rounded : Icons.person_rounded,
            size: compact ? 12 : 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );

    if (tableMode && isSuperAdmin) {
      return Tooltip(message: 'Super Admin', child: badge);
    }

    return badge;
  }
}
