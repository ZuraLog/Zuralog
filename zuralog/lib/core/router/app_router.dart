/// Zuralog Edge Agent — GoRouter Configuration.
///
/// Declares [routerProvider], a Riverpod [Provider<GoRouter>] that watches
/// [authStateProvider] and recreates the router whenever auth state changes,
/// triggering reactive redirects (e.g., auto-navigate to dashboard on login).
///
/// **Route tree:**
/// ```
/// /welcome              → WelcomeScreen (placeholder)
/// /onboarding           → OnboardingPageView (placeholder)
/// /auth/login           → LoginScreen (placeholder)
/// /auth/register        → RegisterScreen (placeholder)
/// / (StatefulShellRoute) → AppShell
///   /dashboard          → DashboardScreen (placeholder, tab 0)
///   /chat               → ChatScreen (placeholder, tab 1)
///   /integrations       → IntegrationsHubScreen (placeholder, tab 2)
/// /settings             → SettingsScreen (placeholder, pushed over shell)
/// /debug/catalog        → CatalogScreen (dev-only)
/// ```
///
/// All placeholder screens will be replaced with real implementations in
/// subsequent phases (2.2.1–2.2.5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/catalog/catalog_screen.dart';
import 'package:zuralog/core/router/auth_guard.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/shared/layout/app_shell.dart';

/// Riverpod provider that exposes the configured [GoRouter] instance.
///
/// Watches [authStateProvider] so the router's redirect logic is re-evaluated
/// whenever auth state changes (login, logout, or initial auth check completes).
///
/// The router is recreated on auth state change because [GoRouter] reads the
/// [redirect] callback reactively when the provider is rebuilt. This ensures
/// that navigation happens automatically without any manual imperatives.
final routerProvider = Provider<GoRouter>((ref) {
  // Watch authStateProvider so Riverpod rebuilds this provider — and
  // therefore the GoRouter — whenever the auth state changes.
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RouteNames.welcomePath,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      return authGuardRedirect(context, state, authState);
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
      builder: (context, state) => const _PlaceholderScreen(
        title: 'Welcome',
        icon: Icons.waving_hand_rounded,
      ),
    ),
    GoRoute(
      path: RouteNames.onboardingPath,
      name: RouteNames.onboarding,
      builder: (context, state) => const _PlaceholderScreen(
        title: 'Onboarding',
        icon: Icons.auto_awesome_rounded,
      ),
    ),

    // ── Auth ─────────────────────────────────────────────────────────────
    GoRoute(
      path: RouteNames.loginPath,
      name: RouteNames.login,
      builder: (context, state) => const _PlaceholderScreen(
        title: 'Login',
        icon: Icons.login_rounded,
      ),
    ),
    GoRoute(
      path: RouteNames.registerPath,
      name: RouteNames.register,
      builder: (context, state) => const _PlaceholderScreen(
        title: 'Register',
        icon: Icons.person_add_rounded,
      ),
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
              builder: (context, state) => const _PlaceholderScreen(
                title: 'Dashboard',
                icon: Icons.home_rounded,
              ),
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
            Icon(icon, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
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
