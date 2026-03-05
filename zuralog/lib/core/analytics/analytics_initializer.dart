/// One-time analytics initialization widget.
///
/// Registers super properties (platform, app_version, build_number)
/// that are sent with every PostHog event. Place this widget
/// early in the widget tree (e.g., inside ZuralogApp's build).
///
/// Also observes app lifecycle to capture app_opened and app_backgrounded,
/// and tracks session duration via sessionStarted / sessionSummary events.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'analytics_events.dart';
import 'analytics_service.dart';

class AnalyticsInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AnalyticsInitializer({super.key, required this.child});

  @override
  ConsumerState<AnalyticsInitializer> createState() =>
      _AnalyticsInitializerState();
}

class _AnalyticsInitializerState extends ConsumerState<AnalyticsInitializer>
    with WidgetsBindingObserver {
  bool _initialized = false;
  DateTime? _sessionStart;
  int _sessionStartHour = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnalytics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startSession() {
    _sessionStart = DateTime.now();
    _sessionStartHour = _sessionStart!.hour;
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.sessionStarted,
      properties: {
        'hour_of_day': _sessionStartHour,
        'day_of_week': _sessionStart!.weekday,
      },
    );
  }

  void _endSession() {
    final start = _sessionStart;
    if (start == null) return;
    final durationSeconds = DateTime.now().difference(start).inSeconds;
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.sessionSummary,
      properties: {
        'duration_seconds': durationSeconds,
        'hour_of_day': _sessionStartHour,
      },
    );
    _sessionStart = null;
  }

  Future<void> _initAnalytics() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final analytics = ref.read(analyticsServiceProvider);
      final packageInfo = await PackageInfo.fromPlatform();

      // Register super properties — sent with every event
      await analytics.registerSuperProperties({
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
      });

      // Track app opened (cold start)
      await analytics.capture(event: AnalyticsEvents.appOpened, properties: {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': packageInfo.version,
        'is_cold_start': true,
      });

      _startSession();
    } catch (e) {
      debugPrint('AnalyticsInitializer._initAnalytics failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final analytics = ref.read(analyticsServiceProvider);

    switch (state) {
      case AppLifecycleState.paused:
        _endSession();
        analytics.capture(event: AnalyticsEvents.appBackgrounded);
        analytics.flush();
        break;
      case AppLifecycleState.resumed:
        analytics.capture(event: AnalyticsEvents.appOpened, properties: {
          'is_cold_start': false,
        });
        _startSession();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
