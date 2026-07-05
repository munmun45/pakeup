import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PartnerTableAction extends StatelessWidget {
  const PartnerTableAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 16, color: c),
          ),
        ),
      ),
    );
  }
}

class PartnerStatusBadge extends StatelessWidget {
  const PartnerStatusBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.block,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class PartnerKycStatusBadge extends StatelessWidget {
  const PartnerKycStatusBadge({super.key, required this.status});

  final String status;

  Color get _color => switch (status) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  String get _label => switch (status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Pending',
      };

  IconData get _icon => switch (status) {
        'approved' => Icons.verified_rounded,
        'rejected' => Icons.cancel_rounded,
        _ => Icons.pending_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class PartnerAccountStatusBadge extends StatelessWidget {
  const PartnerAccountStatusBadge({super.key, required this.isComplete});

  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? AppColors.success : AppColors.warning;
    final icon =
        isComplete ? Icons.check_circle_rounded : Icons.pending_rounded;
    final label = isComplete ? 'Complete' : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class PartnerCategoryBadge extends StatelessWidget {
  const PartnerCategoryBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront, size: 12, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class PartnerDialogActionButton extends StatelessWidget {
  const PartnerDialogActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.variant,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final PartnerDialogActionVariant variant;

  @override
  Widget build(BuildContext context) {
    final color = switch (variant) {
      PartnerDialogActionVariant.primary => AppColors.primary,
      PartnerDialogActionVariant.warning => AppColors.warning,
      PartnerDialogActionVariant.success => AppColors.success,
      PartnerDialogActionVariant.danger => AppColors.error,
    };

    final filled = variant == PartnerDialogActionVariant.primary;

    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: filled ? Colors.white : color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum PartnerDialogActionVariant { primary, warning, success, danger }

const partnerTableHeaderStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.9,
  color: AppColors.primaryDark,
);

const partnerTableColumnPadding = EdgeInsets.symmetric(horizontal: 14);

const partnerTableStoreDetailsWidth = 320.0;
const partnerTableCityWidth = 260.0;
const partnerTableCategoryWidth = 130.0;
const partnerTableStatusWidth = 100.0;

const partnerTableActionButtonSize = 30.0;
const partnerTableActionGap = 4.0;
const partnerTableActionCount = 4;

double get partnerTableActionsColumnWidth =>
    partnerTableActionCount * partnerTableActionButtonSize +
    (partnerTableActionCount - 1) * partnerTableActionGap +
    partnerTableColumnPadding.left +
    partnerTableColumnPadding.right;

double partnerTableMinWidth({required double hubColumnWidth}) =>
    partnerTableStoreDetailsWidth +
    partnerTableCityWidth +
    partnerTableCategoryWidth +
    partnerTableStatusWidth +
    hubColumnWidth +
    partnerTableActionsColumnWidth;

class PartnerTableColumn extends StatelessWidget {
  const PartnerTableColumn({
    super.key,
    required this.width,
    required this.child,
    this.align = Alignment.centerLeft,
    this.showDivider = true,
  });

  final double width;
  final Widget child;
  final Alignment align;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: partnerTableColumnPadding,
        alignment: align,
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.65),
                  ),
                ),
              )
            : null,
        child: child,
      ),
    );
  }
}
