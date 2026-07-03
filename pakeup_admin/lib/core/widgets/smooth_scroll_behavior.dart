import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Enables mouse, trackpad, and touch dragging with consistent scroll physics.
class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
  }
}

/// Scrollbar + smooth physics wrapper for vertical lists.
class SmoothScrollView extends StatelessWidget {
  const SmoothScrollView({
    super.key,
    required this.controller,
    required this.child,
    this.padding,
  });

  final ScrollController controller;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      interactive: true,
      radius: const Radius.circular(6),
      thickness: 5,
      thumbVisibility: false,
      child: SingleChildScrollView(
        controller: controller,
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: child,
      ),
    );
  }
}
