import 'package:flutter/material.dart';

import '../../../core/utils/app_error_message.dart';
import '../../../core/widgets/app_messenger.dart';

class AppSnackBar {
  AppSnackBar._();

  static void show(BuildContext context, String message, {Color? bg}) {
    final messenger =
        rootScaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bg ?? const Color(0xFF1A1225),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message, bg: const Color(0xFF2E7D32));
  }

  static void error(BuildContext context, String message) {
    show(context, message, bg: const Color(0xFFD32F2F));
  }

  static void actionFailed(BuildContext context, String action, Object err) {
    AppSnackBar.error(
      context,
      'Could not $action. ${friendlyErrorMessage(err)}',
    );
  }
}
