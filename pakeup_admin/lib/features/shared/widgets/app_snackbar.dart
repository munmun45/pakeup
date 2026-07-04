import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/app_messenger.dart';
import '../../../core/utils/app_error_message.dart';

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
    required this.background,
    required this.accent,
    required this.icon,
    required this.label,
  });

  final Color background;
  final Color accent;
  final IconData icon;
  final String label;

  static _ToastStyle forType(AppSnackBarType type) => switch (type) {
        AppSnackBarType.success => const _ToastStyle(
            background: Color(0xFF1A2E22),
            accent: Color(0xFF6EE7A0),
            icon: Icons.check_rounded,
            label: 'Success',
          ),
        AppSnackBarType.error => const _ToastStyle(
            background: Color(0xFF351A1F),
            accent: Color(0xFFFF8A9B),
            icon: Icons.close_rounded,
            label: 'Error',
          ),
        AppSnackBarType.warning => const _ToastStyle(
            background: Color(0xFF352A14),
            accent: Color(0xFFFBBF24),
            icon: Icons.priority_high_rounded,
            label: 'Warning',
          ),
        AppSnackBarType.info => const _ToastStyle(
            background: Color(0xFF251A30),
            accent: Color(0xFFF472B6),
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
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(520, screenWidth - 40),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: style.accent.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: style.accent.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: style.accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(style.icon, color: style.accent, size: 17),
                ),
                const SizedBox(width: 12),
                Flexible(
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
                      const SizedBox(height: 1),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFF3F0F5),
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
      ),
    );
  }
}
