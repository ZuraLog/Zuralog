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
///     /dashboard/activity          → CategoryDetailScreen(activity)
///       /dashboard/activity/:id    → MetricDetailScreen(activity, id)
///     /dashboard/body              → CategoryDetailScreen(body)
///       /dashboard/body/:id        → MetricDetailScreen(body, id)
///     /dashboard/heart             → CategoryDetailScreen(heart)
///     /dashboard/vitals            → CategoryDetailScreen(vitals)
///     /dashboard/sleep             → CategoryDetailScreen(sleep)
///     /dashboard/nutrition         → CategoryDetailScreen(nutrition)
///     /dashboard/cycle             → CategoryDetailScreen(cycle)
///     /dashboard/wellness          → CategoryDetailScreen(wellness)
///     /dashboard/mobility          → CategoryDetailScreen(mobility)
///     /dashboard/environment       → CategoryDetailScreen(environment)
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
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/auth/presentation/auth/login_screen.dart';
import 'package:zuralog/features/auth/presentation/auth/register_screen.dart';
import 'package:zuralog/features/auth/presentation/onboarding/onboarding_page_view.dart';
import 'package:zuralog/features/auth/presentation/onboarding/profile_questionnaire_screen.dart';
import 'package:zuralog/features/auth/presentation/onboarding/welcome_screen.dart';
import 'package:zuralog/features/catalog/catalog_screen.dart';
import 'package:zuralog/core/router/auth_guard.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/chat/presentation/chat_screen.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';
import 'package:zuralog/features/dashboard/presentation/category_detail_screen.dart';
import 'package:zuralog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:zuralog/features/dashboard/presentation/metric_detail_screen.dart';
import 'package:zuralog/features/integrations/presentation/integrations_hub_screen.dart';
import 'package:zuralog/features/settings/presentation/settings_screen.dart';
import 'package:zuralog/shared/layout/app_shell.dart';

// ── Auth State → ChangeNotifier Bridge ───────────────────────────────────────

/// Bridges Riverpod's [authStateProvider], [hasSeenOnboardingProvider],
/// [userProfileProvider], and [isLoadingProfileProvider] to a single
/// [ChangeNotifier] that [GoRouter] can use as a [refreshListenable].
///
/// When any of these providers emits a new value, [notifyListeners] is called
/// so the router re-evaluates its [redirect] callback without recreating the
/// [GoRouter]. [isLoadingProfileProvider] is included so the guard can hold
/// off the questionnaire redirect while the profile fetch is still in-flight.
class _RouterRefreshListenable extends ChangeNotifier {
  /// Creates a [_RouterRefreshListenable] that listens to auth, onboarding
  /// flag, profile state, and profile-loading flag changes via [ref].
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
    // Listen to profile changes so the onboarding guard fires as soon as
    // [onboardingComplete] is set to true after the questionnaire.
    ref.listen<UserProfile?>(
      userProfileProvider,
      (prev, next) => notifyListeners(),
    );
    // Listen to the profile-loading flag so the guard re-evaluates once
    // [load()] completes — preventing a premature questionnaire redirect
    // while the profile fetch is still in-flight.
    ref.listen<bool>(
      isLoadingProfileProvider,
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

      // ── Step 3: Post-registration profile questionnaire guard. ───────────
      // If the user is authenticated but has not completed the profile
      // questionnaire, redirect them to it — unless they are already there.
      //
      // Important: while [isLoadingProfileProvider] is true, the profile
      // fetch is still in-flight. We must NOT redirect during this window
      // because [profile] is transiently null even for returning users who
      // have already completed onboarding. Redirecting here would force
      // every returning user to re-do the questionnaire on every login.
      //
      // Once [load()] completes:
      //   - profile != null && onboardingComplete == true  → allow through
      //   - profile != null && onboardingComplete == false → questionnaire
      //   - profile == null (load failed)                  → questionnaire
      //     (user can retry; the questionnaire upserts the profile row)
      if (authState == AuthState.authenticated &&
          location != RouteNames.profileQuestionnairePath) {
        final isLoadingProfile = ref.read(isLoadingProfileProvider);
        if (isLoadingProfile) {
          // Profile fetch still in-flight — stay put, guard will re-fire
          // when [isLoadingProfileProvider] flips to false.
          return null;
        }
        final profile = ref.read(userProfileProvider);
        if (profile == null || !profile.onboardingComplete) {
          return RouteNames.profileQuestionnairePath;
        }
      }

      return null;
    },
    routes: _buildRoutes(),
  );
});

/// Constructs the nested [GoRoute] list for all 10 health category detail
/// screens and their per-metric child routes.
///
/// Each category gets a `GoRoute` at `/dashboard/{categoryName}` with a
/// nested `:metricId` child that pushes [MetricDetailScreen].
///
/// These routes are registered as `routes:` inside the dashboard [GoRoute]
/// so they remain within the [StatefulShellBranch] and preserve the bottom
/// navigation bar.
List<GoRoute> _buildCategoryRoutes() {
  return HealthCategory.values.map((category) {
    return GoRoute(
      path: category.name,
      builder: (BuildContext context, GoRouterState state) =>
          CategoryDetailScreen(category: category),
      routes: [
        GoRoute(
          path: ':metricId',
          builder: (BuildContext context, GoRouterState state) {
            final String metricId = state.pathParameters['metricId']!;
            return MetricDetailScreen(
              category: category,
              metricId: metricId,
            );
          },
        ),
      ],
    );
  }).toList();
}

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

    // ── Post-registration Profile Questionnaire ───────────────────────────
    GoRoute(
      path: RouteNames.profileQuestionnairePath,
      name: RouteNames.profileQuestionnaire,
      builder: (context, state) => const ProfileQuestionnaireScreen(),
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
              routes: _buildCategoryRoutes(),
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
