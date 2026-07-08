import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_error_message.dart';
import '../../../core/widgets/app_messenger.dart';
import 'premium_card.dart';

enum AppSnackBarType { success, error, info, warning }

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.success,
    Duration duration = const Duration(seconds: 4),
  }) {
    void showNow() {
      if (!context.mounted) return;

      AppOverlayMessenger.show(
        context,
        duration: duration,
        child: _ToastPill(message: message, type: type),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => showNow());
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.success);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.info);
  }

  static void warning(BuildContext context, String message) {
    show(
      context,
      message: message,
      type: AppSnackBarType.warning,
      duration: const Duration(seconds: 4),
    );
  }

  static void error(BuildContext context, String message) {
    show(
      context,
      message: message,
      type: AppSnackBarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void errorFrom(BuildContext context, Object error) {
    show(
      context,
      message: formatAppError(error),
      type: AppSnackBarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void actionFailed(
    BuildContext context,
    String action,
    Object error,
  ) {
    show(
      context,
      message: couldNotMessage(action, error),
      type: AppSnackBarType.error,
      duration: const Duration(seconds: 5),
    );
  }
}

class _ToastStyle {
  const _ToastStyle({
    required this.accent,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final IconData icon;
  final String label;

  static _ToastStyle forType(AppSnackBarType type) => switch (type) {
        AppSnackBarType.success => const _ToastStyle(
            accent: AppColors.success,
            icon: Icons.check_rounded,
            label: 'Success',
          ),
        AppSnackBarType.error => const _ToastStyle(
            accent: AppColors.error,
            icon: Icons.close_rounded,
            label: 'Error',
          ),
        AppSnackBarType.warning => const _ToastStyle(
            accent: AppColors.warning,
            icon: Icons.priority_high_rounded,
            label: 'Warning',
          ),
        AppSnackBarType.info => const _ToastStyle(
            accent: AppColors.primary,
            icon: Icons.info_outline_rounded,
            label: 'Info',
          ),
      };
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({
    required this.message,
    required this.type,
  });

  final String message;
  final AppSnackBarType type;

  @override
  Widget build(BuildContext context) {
    final style = _ToastStyle.forType(type);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(520, screenWidth - 32),
        ),
        child: PremiumCard(
          accentColor: style.accent,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      style.accent.withValues(alpha: 0.18),
                      style.accent.withValues(alpha: 0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: style.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      style.label,
                      style: TextStyle(
                        color: style.accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
