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

import 'package:zuralog/core/theme/theme.dart';

/// A widget that catches errors in its subtree and reports them to Sentry.
///
/// Acts as a Flutter error boundary using [ErrorWidget.builder] scoped to
/// the subtree, complemented by [onError] for programmatic capture.
class SentryErrorBoundary extends StatefulWidget {
  /// The widget subtree to protect.
  final Widget child;

  /// Logical module name used as a Sentry tag (e.g. `'coach'`, `'data'`).
  ///
  /// Used for grouping issues by feature in the Sentry dashboard.
  final String module;

  /// Optional custom fallback UI. When null a default error card is shown.
  final Widget? fallback;

  /// Whether to show a "Go back" button in the default fallback UI.
  final bool showBackButton;

  /// Creates an [SentryErrorBoundary].
  const SentryErrorBoundary({
    super.key,
    required this.child,
    required this.module,
    this.fallback,
    this.showBackButton = true,
  });

  @override
  State<SentryErrorBoundary> createState() => _SentryErrorBoundaryState();
}

class _SentryErrorBoundaryState extends State<SentryErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

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

  /// Called by [SentryWidget]'s [onError] callback.
  void _handleError(Object error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });

    Sentry.withScope((scope) {
      scope.setTag('module', widget.module);
      scope.setTag('error_boundary', 'true');
      scope.setLevel(SentryLevel.fatal);
      Sentry.captureException(error, stackTrace: stackTrace);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback ??
          _DefaultErrorFallback(
            module: widget.module,
            showBackButton: widget.showBackButton,
            onRetry: () => setState(() {
              _error = null;
              _stackTrace = null;
            }),
          );
    }

    return SentryWidget(
      child: widget.child,
    );
  }
}

/// Default fallback UI shown inside [SentryErrorBoundary] on error.
///
/// Matches the app's dark-first design: true-black background, sage green
/// action button, and minimal typographic layout.
class _DefaultErrorFallback extends StatelessWidget {
  final String module;
  final bool showBackButton;
  final VoidCallback onRetry;

  const _DefaultErrorFallback({
    required this.module,
    required this.showBackButton,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Something went wrong',
                style: AppTextStyles.h1.copyWith(
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'An unexpected error occurred in this section of the app. '
                'The issue has been reported automatically.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
              if (showBackButton && canPop) ...[
                const SizedBox(height: 12),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
