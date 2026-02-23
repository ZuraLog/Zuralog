/// Zuralog Edge Agent — Route Name & Path Constants.
///
/// Centralizes all route names and path strings used by [GoRouter].
/// Using constants prevents typos and makes refactoring safe — every
/// navigation call references these symbols rather than raw strings.
///
/// **Naming convention:**
/// - `*Name` — the named route identifier (used with `GoRouter.go`).
/// - `*Path` — the URL path string (registered in the router config).
library;

/// Route name and path constants for the Zuralog application.
///
/// All navigation within the app must reference these constants instead
/// of inline string literals to avoid typo-driven routing failures.
abstract final class RouteNames {
  // ── Onboarding & Auth ────────────────────────────────────────────────────

  /// Name for the welcome/onboarding entry screen.
  static const String welcome = 'welcome';

  /// Path for the welcome screen.
  static const String welcomePath = '/welcome';

  /// Name for the multi-page onboarding value-prop slideshow.
  static const String onboarding = 'onboarding';

  /// Path for the onboarding page view.
  static const String onboardingPath = '/onboarding';

  /// Name for the login screen.
  static const String login = 'login';

  /// Path for the login screen.
  static const String loginPath = '/auth/login';

  /// Name for the registration screen.
  static const String register = 'register';

  /// Path for the registration screen.
  static const String registerPath = '/auth/register';

  // ── Main Shell (Tabbed) ───────────────────────────────────────────────────

  /// Name for the dashboard tab (shell root).
  static const String dashboard = 'dashboard';

  /// Path for the dashboard screen.
  static const String dashboardPath = '/dashboard';

  /// Name for the AI coach chat tab.
  static const String chat = 'chat';

  /// Path for the chat screen.
  static const String chatPath = '/chat';

  /// Name for the integrations hub tab.
  static const String integrations = 'integrations';

  /// Path for the integrations hub screen.
  static const String integrationsPath = '/integrations';

  // ── Pushed Over Shell ────────────────────────────────────────────────────

  /// Name for the settings screen (pushed over the shell, not a tab).
  static const String settings = 'settings';

  /// Path for the settings screen.
  static const String settingsPath = '/settings';

  // ── Developer Tools ───────────────────────────────────────────────────────

  /// Name for the design system visual catalog (dev only).
  static const String debugCatalog = 'debugCatalog';

  /// Path for the design system catalog screen.
  static const String debugCatalogPath = '/debug/catalog';

  // ── Unauthenticated Route Set ─────────────────────────────────────────────

  /// Set of paths that are accessible without authentication.
  ///
  /// Used by the auth guard to determine whether to redirect to [welcomePath].
  ///
  /// Note: [settingsPath] and [debugCatalogPath] are intentionally excluded —
  /// both require the user to be authenticated before they can be accessed.
  static const Set<String> publicPaths = {
    welcomePath,
    onboardingPath,
    loginPath,
    registerPath,
  };
}
