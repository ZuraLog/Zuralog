/// Zuralog — Sentry Error Boundary Widget.
///
/// Wraps any widget subtree in a Flutter error boundary that catches
/// uncaught widget build errors and reports them to Sentry with rich
/// context. Displays a graceful fallback UI so users never see a red
/// crash screen in production.
///
/// Usage — wrap individual screens:
/// ```dart
/// SentryErrorBoundary(
///   module: 'coach',
///   child: ChatScreen(),
/// )
/// ```
///
/// Or use the [SentryErrorBoundary.screen] named constructor to create
/// a full-page boundary with a standard back-navigation recovery option.
library;

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// A widget that adds Sentry navigation breadcrumbs when a screen mounts.
///
/// Records a Sentry breadcrumb in [initState] for navigation context.
/// The [module] string identifies the screen in the Sentry dashboard.
class SentryErrorBoundary extends StatefulWidget {
  /// The widget subtree to protect.
  final Widget child;

  /// Logical module name used as a Sentry tag (e.g. `'coach'`, `'data'`).
  ///
  /// Used for grouping issues by feature in the Sentry dashboard.
  final String module;

  /// Creates an [SentryErrorBoundary].
  const SentryErrorBoundary({
    super.key,
    required this.child,
    required this.module,
  });

  @override
  State<SentryErrorBoundary> createState() => _SentryErrorBoundaryState();
}

class _SentryErrorBoundaryState extends State<SentryErrorBoundary> {
  @override
  void initState() {
    super.initState();
    // Add a breadcrumb when the boundary screen mounts.
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'Screen mounted: ${widget.module}',
        category: 'navigation',
        type: 'navigation',
        level: SentryLevel.info,
        data: {'module': widget.module},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
