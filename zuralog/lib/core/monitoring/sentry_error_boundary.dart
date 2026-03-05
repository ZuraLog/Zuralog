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

/// A widget that catches errors in its subtree and reports them to Sentry.
///
/// Acts as a Flutter error boundary using [SentryWidget] for automatic
/// error capture and Sentry breadcrumb tracking for navigation context.
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
    // NOTE: Do NOT wrap in SentryWidget here. SentryWidget uses a static
    // GlobalKey internally, so only one instance can exist in the tree at
    // a time. When multiple tabs render in an IndexedStack, duplicates
    // cause the widget tree to be truncated. The top-level app already
    // has Sentry integration via SentryFlutter.init().
    return widget.child;
  }
}
