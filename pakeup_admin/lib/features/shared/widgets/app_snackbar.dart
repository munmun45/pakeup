import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/widgets/app_messenger.dart';
import '../../../core/theme/app_theme.dart';

enum AppSnackBarType { success, error, info, warning }

class AppSnackBar {
  AppSnackBar._();

  static ScaffoldMessengerState? _messenger(BuildContext context) {
    return rootScaffoldMessengerKey.currentState ??
        ScaffoldMessenger.maybeOf(context);
  }

  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.success,
    String actionLabel = 'Close',
    Duration duration = const Duration(seconds: 4),
  }) {
    void showNow() {
      final messenger = _messenger(context);
      if (messenger == null) return;

      final size = MediaQuery.sizeOf(context);
      final padding = MediaQuery.paddingOf(context);
      final barWidth = math.min(380.0, size.width - 32);
      final left = math.max(16.0, size.width - barWidth - 16);

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          elevation: 6,
          behavior: SnackBarBehavior.floating,
          width: barWidth,
          margin: EdgeInsets.only(
            bottom: padding.bottom + 16,
            left: left,
            right: 16,
          ),
          backgroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          duration: duration,
          dismissDirection: DismissDirection.horizontal,
          content: _AppSnackBarBody(
            message: message,
            type: type,
            actionLabel: actionLabel,
            onClose: messenger.hideCurrentSnackBar,
          ),
        ),
      );
    }

    // Show after frame so rebuilds from provider invalidation don't hide it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) showNow();
    });
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.success);
  }

  static void error(BuildContext context, String message) {
    show(
      context,
      message: message,
      type: AppSnackBarType.error,
      duration: const Duration(seconds: 5),
    );
  }
}

class _AppSnackBarBody extends StatelessWidget {
  const _AppSnackBarBody({
    required this.message,
    required this.type,
    required this.actionLabel,
    required this.onClose,
  });

  final String message;
  final AppSnackBarType type;
  final String actionLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = switch (type) {
      AppSnackBarType.success => AppColors.success,
      AppSnackBarType.error => AppColors.error,
      AppSnackBarType.warning => AppColors.warning,
      AppSnackBarType.info => AppColors.primary,
    };

    final icon = switch (type) {
      AppSnackBarType.success => Icons.check_circle_rounded,
      AppSnackBarType.error => Icons.error_outline_rounded,
      AppSnackBarType.warning => Icons.warning_amber_rounded,
      AppSnackBarType.info => Icons.info_outline_rounded,
    };

    return Row(
      children: [
        Container(
          width: 4,
          height: 44,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        TextButton(
          onPressed: onClose,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
