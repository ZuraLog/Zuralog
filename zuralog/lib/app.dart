/// Zuralog Edge Agent — Root Application Widget.
///
/// Configures [MaterialApp.router] with the Zuralog design system themes
/// (light/dark/system-native), connects [themeModeProvider] for reactive
/// theme switching, and uses [routerProvider] to power GoRouter-based
/// declarative navigation.
///
/// [ZuralogApp] is a [ConsumerStatefulWidget] so it can call
/// [AuthStateNotifier.checkAuthStatus] once in [initState], triggering the
/// initial auth token validation without requiring an imperative post-frame
/// callback on every rebuild.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_initializer.dart';
import 'package:zuralog/core/router/app_router.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/workout/presentation/widgets/workout_resume_gate.dart';

/// The root widget of the Zuralog application.
///
/// Extends [ConsumerStatefulWidget] to:
/// 1. Watch [themeModeProvider] and rebuild [MaterialApp.router] on change.
/// 2. Trigger [AuthStateNotifier.checkAuthStatus] exactly once in [initState],
///    initiating the startup auth token check that determines initial routing.
class ZuralogApp extends ConsumerStatefulWidget {
  /// Creates the root [ZuralogApp] widget.
  const ZuralogApp({super.key});

  @override
  ConsumerState<ZuralogApp> createState() => _ZuralogAppState();
}

/// State for [ZuralogApp].
///
/// Calls [AuthStateNotifier.checkAuthStatus] in [initState] to determine
/// whether a stored session exists. The result transitions [authStateProvider]
/// from [AuthState.unauthenticated] (initial) to either [AuthState.authenticated]
/// or back to [AuthState.unauthenticated], which the GoRouter redirect callback
/// then reacts to automatically.
class _ZuralogAppState extends ConsumerState<ZuralogApp> {
  @override
  void initState() {
    super.initState();
    // Perform the startup auth token check asynchronously.
    // We use addPostFrameCallback so the first frame renders (with the loading
    // state) before the async work begins, avoiding a race with the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // valueOrNull falls back to ThemeMode.system while the async preference
    // loads from SharedPreferences/API — no flash of wrong theme.
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final router = ref.watch(routerProvider);

    return AnalyticsInitializer(
      child: MaterialApp.router(
        title: 'Zuralog',
        debugShowCheckedModeBanner: false,
        // Light and dark themes from the design system.
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Persisted preference: dark/light/system. Falls back to system
        // while the async provider loads on cold start.
        themeMode: themeMode,
        // GoRouter-backed declarative navigation.
        routerConfig: router,
        // Wrap the router's child so the resume-workout prompt fires once
        // on cold start, above the Navigator but inside Material context so
        // [showDialog] can reach a valid Navigator.
        builder: (context, child) => WorkoutResumeGate(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
