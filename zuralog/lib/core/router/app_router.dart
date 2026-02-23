/// Zuralog Edge Agent — GoRouter Configuration.
///
/// Declares [routerProvider], a Riverpod [Provider<GoRouter>] that creates the
/// [GoRouter] instance ONCE and uses [refreshListenable] to re-trigger the
/// [redirect] callback whenever auth state or first-launch flag changes —
/// without recreating the entire router.
///
/// **Route tree:**
/// ```
/// /welcome              → WelcomeScreen (Auth Home — Apple/Google/Email)
/// /onboarding           → OnboardingPageView (shown only on first launch)
/// /auth/login           → LoginScreen
/// /auth/register        → RegisterScreen
/// / (StatefulShellRoute) → AppShell
///   /dashboard          → DashboardScreen (tab 0)
///   /chat               → ChatScreen (placeholder, tab 1)
///   /integrations       → IntegrationsHubScreen (tab 2)
/// /settings             → SettingsScreen (pushed over shell)
/// /debug/catalog        → CatalogScreen (dev-only)
/// ```
///
/// **First-launch redirect rule:**
/// On the very first launch (before [markOnboardingComplete] is called),
/// any navigation to [welcomePath] is intercepted and redirected to
/// [onboardingPath]. After completing/skipping onboarding the flag is set
/// and subsequent launches go directly to [welcomePath].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/presentation/auth/login_screen.dart';
import 'package:zuralog/features/auth/presentation/auth/register_screen.dart';
import 'package:zuralog/features/auth/presentation/onboarding/onboarding_page_view.dart';
import 'package:zuralog/features/auth/presentation/onboarding/welcome_screen.dart';
import 'package:zuralog/features/catalog/catalog_screen.dart';
import 'package:zuralog/core/router/auth_guard.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/chat/presentation/chat_screen.dart';
import 'package:zuralog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:zuralog/features/integrations/presentation/integrations_hub_screen.dart';
import 'package:zuralog/features/settings/presentation/settings_screen.dart';
import 'package:zuralog/shared/layout/app_shell.dart';

// ── Auth State → ChangeNotifier Bridge ───────────────────────────────────────

/// Bridges Riverpod's [authStateProvider] and [hasSeenOnboardingProvider]
/// to a single [ChangeNotifier] that [GoRouter] can use as a [refreshListenable].
///
/// When either provider emits a new value, [notifyListeners] is called so the
/// router re-evaluates its [redirect] callback without recreating the [GoRouter].
class _RouterRefreshListenable extends ChangeNotifier {
  /// Creates a [_RouterRefreshListenable] that listens to auth and onboarding
  /// state changes via [ref].
  _RouterRefreshListenable(Ref ref) {
    // Listen to auth state changes.
    ref.listen<AuthState>(
      authStateProvider,
      (prev, next) => notifyListeners(),
    );
    // Listen to the onboarding flag to redirect first-timers.
    ref.listen<AsyncValue<bool>>(
      hasSeenOnboardingProvider,
      (prev, next) => notifyListeners(),
    );
  }
}

// ── Router Provider ───────────────────────────────────────────────────────────

/// Riverpod provider that exposes the configured [GoRouter] instance.
///
/// The [GoRouter] is created **once** and kept alive for the lifetime of the
/// provider. Auth-state and onboarding-flag changes are propagated via
/// [refreshListenable] so only the [redirect] callback is re-evaluated.
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _RouterRefreshListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: RouteNames.welcomePath,
    refreshListenable: listenable,
    debugLogDiagnostics: kDebugMode,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);
      final location = state.matchedLocation;

      // ── Step 1: Run the auth guard first. ───────────────────────────────
      final authRedirect = authGuardRedirect(
        authState: authState,
        location: location,
      );
      if (authRedirect != null) return authRedirect;

      // ── Step 2: First-launch onboarding redirect. ────────────────────────
      // Only relevant when the user is unauthenticated and heading to /welcome.
      // If the onboarding flag is still loading, stay put.
      final onboardingAsync = ref.read(hasSeenOnboardingProvider);
      if (location == RouteNames.welcomePath) {
        // While the async flag is loading, stay on /welcome (no redirect).
        if (onboardingAsync.isLoading) return null;
        final hasSeen = onboardingAsync.valueOrNull ?? true;
        if (!hasSeen) {
          // First launch — show onboarding before the auth home.
          return RouteNames.onboardingPath;
        }
      }

      return null;
    },
    routes: _buildRoutes(),
  );
});

/// Constructs the complete route list for the application.
///
/// Returns a flat list of [RouteBase] objects that includes both top-level
/// routes (welcome, onboarding, auth, settings, debug) and the tabbed shell.
List<RouteBase> _buildRoutes() {
  return [
    // ── Onboarding & Auth Home ────────────────────────────────────────────
    GoRoute(
      path: RouteNames.welcomePath,
      name: RouteNames.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: RouteNames.onboardingPath,
      name: RouteNames.onboarding,
      builder: (context, state) => const OnboardingPageView(),
    ),

    // ── Auth Forms ────────────────────────────────────────────────────────
    GoRoute(
      path: RouteNames.loginPath,
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RouteNames.registerPath,
      name: RouteNames.register,
      builder: (context, state) => const RegisterScreen(),
    ),

    // ── Settings (pushed over shell) ──────────────────────────────────────
    GoRoute(
      path: RouteNames.settingsPath,
      name: RouteNames.settings,
      builder: (context, state) => const SettingsScreen(),
    ),

    // ── Developer Tools ───────────────────────────────────────────────────
    GoRoute(
      path: RouteNames.debugCatalogPath,
      name: RouteNames.debugCatalog,
      builder: (context, state) => const CatalogScreen(),
    ),

    // ── Main App Shell (StatefulShellRoute with 3 tab branches) ──────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0 — Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.dashboardPath,
              name: RouteNames.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),

        // Tab 1 — AI Coach Chat
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.chatPath,
              name: RouteNames.chat,
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),

        // Tab 2 — Integrations Hub
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.integrationsPath,
              name: RouteNames.integrations,
              builder: (context, state) => const IntegrationsHubScreen(),
            ),
          ],
        ),
      ],
    ),
  ];
}
