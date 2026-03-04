/// Zuralog — Sentry GoRouter Navigator Observer.
///
/// Bridges GoRouter navigation events to Sentry breadcrumbs.
/// [SentryNavigatorObserver] already handles performance transactions;
/// this observer adds structured breadcrumb data so every navigation
/// event appears in Sentry's issue timeline with route context.
///
/// Registered alongside [SentryNavigatorObserver] in [routerProvider].
library;

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// A [NavigatorObserver] that emits a Sentry breadcrumb on every
/// push, pop, and replace navigation event.
class SentryRouterObserver extends NavigatorObserver {
  /// Creates a [SentryRouterObserver].
  const SentryRouterObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(
      event: 'push',
      to: _routeName(route),
      from: _routeName(previousRoute),
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(
      event: 'pop',
      to: _routeName(previousRoute),
      from: _routeName(route),
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _record(
      event: 'replace',
      to: _routeName(newRoute),
      from: _routeName(oldRoute),
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(
      event: 'remove',
      to: _routeName(previousRoute),
      from: _routeName(route),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _routeName(Route<dynamic>? route) =>
      route?.settings.name ?? 'unknown';

  void _record({
    required String event,
    required String to,
    required String from,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'nav.$event $from → $to',
        category: 'navigation',
        type: 'navigation',
        level: SentryLevel.info,
        data: {
          'event': event,
          'from': from,
          'to': to,
        },
      ),
    );
  }
}
