/// PostHog navigation observer for GoRouter.
///
/// Automatically tracks screen views when the user navigates
/// between routes. Add this to the GoRouter's [observers] list.
///
/// Usage:
///   GoRouter(
///     observers: [PostHogNavigatorObserver(analyticsService)],
///   )

import 'package:flutter/material.dart';
import 'analytics_service.dart';

class PostHogNavigatorObserver extends NavigatorObserver {
  final AnalyticsService _analytics;

  PostHogNavigatorObserver(this._analytics);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreen(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackScreen(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackScreen(newRoute);
    }
  }

  void _trackScreen(Route<dynamic> route) {
    final screenName = route.settings.name;
    if (screenName != null && screenName.isNotEmpty) {
      _analytics.screen(
        screenName: screenName,
        properties: {
          'route_path': screenName,
        },
      );
    }
  }
}
