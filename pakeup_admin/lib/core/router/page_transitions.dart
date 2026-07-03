import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/admin_pages.dart';

class RouteTransitionTracker {
  RouteTransitionTracker._();

  static int? _lastMenuIndex;

  static int menuIndexForPath(String path) {
    final key = pageKeyFromPath(path);
    if (key == null) return 0;

    final pages = AdminPages.all;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].key == key) return i;
    }
    return 0;
  }

  static String? pageKeyFromPath(String path) {
    if (path == '/profile') return 'profile';
    for (final page in AdminPages.all) {
      if (page.route == path) return page.key;
    }
    return null;
  }

  static String titleForPath(String path) {
    if (path == '/profile') return 'My Profile';
    final key = pageKeyFromPath(path);
    return AdminPages.byKey(key ?? 'dashboard')?.label ?? 'PakeUp Admin';
  }

  /// Returns true when navigating to a later menu item (slide from right).
  static bool goingForward(String path) {
    final nextIndex = menuIndexForPath(path);
    final forward =
        _lastMenuIndex == null || nextIndex >= (_lastMenuIndex ?? 0);
    _lastMenuIndex = nextIndex;
    return forward;
  }

  static void reset() => _lastMenuIndex = null;
}

/// Fade-in duration used when switching admin panel pages.
const adminPageFadeDuration = Duration(milliseconds: 300);

CustomTransitionPage<T> buildLoginPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Instant page swap — fade is handled in [AdminShell] for reliable shell transitions.
Page<T> buildAdminPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<T>(
    key: state.pageKey,
    child: child,
  );
}
