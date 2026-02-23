/// Zuralog Edge Agent — GoRouter Configuration.
///
/// Declares [routerProvider], a Riverpod [Provider<GoRouter>] that creates the
/// [GoRouter] instance ONCE and uses [refreshListenable] to re-trigger the
/// [redirect] callback whenever auth state changes — without recreating the
/// entire router.
///
/// **Route tree:**
/// ```
/// /welcome              → WelcomeScreen
/// /onboarding           → OnboardingPageView
/// /auth/login           → LoginScreen
/// /auth/register        → RegisterScreen
/// / (StatefulShellRoute) → AppShell
///   /dashboard          → DashboardScreen (tab 0)
///   /chat               → ChatScreen (placeholder, tab 1)
///   /integrations       → IntegrationsHubScreen (placeholder, tab 2)
/// /settings             → SettingsScreen (placeholder, pushed over shell)
/// /debug/catalog        → CatalogScreen (dev-only)
/// ```
///
/// Placeholder screens are used for routes pending Phase 2.2.4+.
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
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:zuralog/shared/layout/app_shell.dart';

// ── Auth State → ChangeNotifier Bridge ───────────────────────────────────────

/// Bridges Riverpod's [authStateProvider] to a [ChangeNotifier] that [GoRouter]
/// can use as a [refreshListenable].
///
/// When [authStateProvider] emits a new [AuthState], [notifyListeners] is called
/// so the router re-evaluates its [redirect] callback without recreating the
/// [GoRouter] instance itself.
class _AuthStateListenable extends ChangeNotifier {
  /// Creates an [_AuthStateListenable] that listens to [authStateProvider]
  /// via [ref].
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authStateProvider, (previous, next) => notifyListeners());
  }
}

// ── Router Provider ───────────────────────────────────────────────────────────

/// Riverpod provider that exposes the configured [GoRouter] instance.
///
/// The [GoRouter] is created **once** and kept alive for the lifetime of the
/// provider. Auth-state changes are propagated via [refreshListenable]
/// (an [_AuthStateListenable]) so only the [redirect] callback is
/// re-evaluated — the navigator stack is preserved across auth transitions.
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthStateListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: RouteNames.welcomePath,
    // refreshListenable notifies GoRouter when auth state changes, triggering
    // redirect re-evaluation without recreating the GoRouter instance.
    refreshListenable: listenable,
    debugLogDiagnostics: kDebugMode,
    redirect: (BuildContext context, GoRouterState state) {
      // ref.read is correct here — called at redirect time, not during build.
      return authGuardRedirect(
        authState: ref.read(authStateProvider),
        location: state.matchedLocation,
      );
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
    // ── Onboarding ────────────────────────────────────────────────────────
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

    // ── Auth ─────────────────────────────────────────────────────────────
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
      builder: (context, state) => const _PlaceholderScreen(
        title: 'Settings',
        icon: Icons.settings_rounded,
      ),
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
              builder: (context, state) => const _PlaceholderScreen(
                title: 'Coach',
                icon: Icons.chat_bubble_rounded,
              ),
            ),
          ],
        ),

        // Tab 2 — Integrations Hub
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.integrationsPath,
              name: RouteNames.integrations,
              builder: (context, state) => const _PlaceholderScreen(
                title: 'Apps',
                icon: Icons.extension_rounded,
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}

// ── Placeholder Screen ────────────────────────────────────────────────────────

/// Icon size used by [_PlaceholderScreen].
const double _placeholderIconSize = 64;

/// Temporary screen used for routes whose real implementation is pending.
///
/// Displays the route [title] and an [icon] so developers can verify routing
/// without needing the final UI. Replaced in Phases 2.2.1–2.2.5.
class _PlaceholderScreen extends StatelessWidget {
  /// Creates a [_PlaceholderScreen] with the given [title] and [icon].
  const _PlaceholderScreen({required this.title, required this.icon});

  /// Human-readable name of the route shown in the center of the screen.
  final String title;

  /// Material icon displayed above the title.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _placeholderIconSize, color: colorScheme.primary),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Placeholder — coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
