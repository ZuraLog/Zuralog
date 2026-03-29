/// Zuralog Design System — Pull-to-Refresh Wrapper.
///
/// Themed [RefreshIndicator] with a Sage spinner on the surface background.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Pull-to-refresh wrapper that uses brand Sage for the spinner.
///
/// Wraps a scrollable [child] in a [RefreshIndicator] themed to match
/// the Zuralog design system.
class ZPullToRefresh extends StatelessWidget {
  /// Creates a [ZPullToRefresh].
  const ZPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  /// Callback triggered when the user pulls to refresh.
  /// Must return a [Future] that completes when the refresh is done.
  final Future<void> Function() onRefresh;

  /// The scrollable child widget (e.g. a [ListView] or [CustomScrollView]).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: child,
    );
  }
}
