import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Scroll physics that allow pull-to-refresh even when content is short.
const alwaysScrollablePhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

/// Branded pull-to-refresh (magenta spinner on white circle).
Widget pullToRefresh({
  required Future<void> Function() onRefresh,
  required Widget child,
  double displacement = 52,
  double edgeOffset = 12,
}) {
  return RefreshIndicator(
    onRefresh: onRefresh,
    color: AppColors.primary,
    backgroundColor: AppColors.surface,
    strokeWidth: 2.5,
    displacement: displacement,
    edgeOffset: edgeOffset,
    triggerMode: RefreshIndicatorTriggerMode.onEdge,
    semanticsLabel: 'Refresh page',
    child: child,
  );
}

/// Wraps [child] in a scroll view tall enough for pull-to-refresh on short pages.
Widget pullToRefreshBox({
  required Future<void> Function() onRefresh,
  required Widget child,
  EdgeInsetsGeometry? padding,
  double displacement = 52,
}) {
  return pullToRefresh(
    onRefresh: onRefresh,
    displacement: displacement,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: alwaysScrollablePhysics,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    ),
  );
}
