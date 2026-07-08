import 'dart:async';

import 'package:flutter/material.dart';

/// Root overlay toasts — always above dialogs and modals.
class AppOverlayMessenger {
  AppOverlayMessenger._();

  static OverlayEntry? _entry;
  static Timer? _hideTimer;

  static void show(
    BuildContext context, {
    required Widget child,
    Duration duration = const Duration(seconds: 4),
  }) {
    _hideTimer?.cancel();
    _dismiss();

    final overlay = _rootOverlay(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final padding = MediaQuery.paddingOf(ctx);
        return Positioned(
          left: 16,
          right: 16,
          bottom: padding.bottom + 88,
          child: IgnorePointer(
            ignoring: false,
            child: Material(
              type: MaterialType.transparency,
              elevation: 24,
              child: child,
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);

    _hideTimer = Timer(duration, () {
      if (_entry == entry) _dismiss();
    });
  }

  static void dismiss() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _dismiss();
  }

  static void _dismiss() {
    _entry?.remove();
    _entry = null;
  }

  static OverlayState? _rootOverlay(BuildContext context) {
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav?.overlay != null) return rootNav!.overlay;

    return Overlay.maybeOf(context, rootOverlay: true);
  }
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
