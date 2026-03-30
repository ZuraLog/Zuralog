/// Zuralog Edge Agent — GoRouter Auth Guard.
///
/// Provides [authGuardRedirect], a stateless function that encapsulates
/// all authentication-based redirect logic for the [GoRouter] configuration.
///
/// **Redirect rules (evaluated in order):**
/// 1. If [AuthState.loading] → return `null` (stay put while auth resolves).
/// 2. If [AuthState.unauthenticated] and the destination is a protected route
///    → redirect to [RouteNames.welcomePath].
/// 3. If [AuthState.authenticated] and the destination is a public auth route,
///    **except** [RouteNames.profileQuestionnairePath],
///    [RouteNames.checkInboxPath], or [RouteNames.resetPasswordPath]
///    → redirect to [RouteNames.todayPath]
///    (prevent back-navigation to login).
///    The questionnaire is excluded because authenticated new users must be
///    allowed to stay on it until [UserProfile.onboardingComplete] is `true`.
///    The check-inbox screen is excluded because Supabase creates a session
///    immediately on sign-up; without the exception the guard bounces the user
///    away before they see the email-verification prompt.
///    The reset-password screen is excluded so a user who is already logged in
///    on another device can still complete the password-reset deep link flow.
/// 4. Otherwise → return `null` (allow navigation).
library;

import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/core/router/route_names.dart';

/// Determines whether GoRouter should redirect the user to a different
/// location based on the current [authState].
///
/// This function is designed to be called from [GoRouter.redirect].
///
/// - [authState] — the current resolved [AuthState] from Riverpod.
/// - [location] — the matched location string from [GoRouterState.matchedLocation].
///
/// Returns a path string to redirect to, or `null` to allow the navigation.
String? authGuardRedirect({
  required AuthState authState,
  required String location,
}) {
  // ── Rule 1: Loading — wait for auth to resolve ───────────────────────────
  if (authState == AuthState.loading) {
    return null;
  }

  final isPublicPath = RouteNames.publicPaths.contains(location);

  // ── Rule 2: Unauthenticated — redirect to welcome ────────────────────────
  if (authState == AuthState.unauthenticated && !isPublicPath) {
    return RouteNames.welcomePath;
  }

  // ── Rule 3: Authenticated — prevent back-navigation to auth screens ──────
  // Exception: profileQuestionnairePath is in publicPaths but must remain
  // reachable for authenticated users who haven't completed onboarding yet.
  // The onboarding guard in app_router.dart (Step 3) handles the redirect
  // to dashboard once onboardingComplete flips to true.
  //
  // Exception: checkInboxPath must also remain reachable for authenticated
  // users. After registration Supabase creates a session immediately, making
  // the user "authenticated" — but they still need to see the email-verification
  // prompt before the app proceeds.
  if (authState == AuthState.authenticated &&
      isPublicPath &&
      location != RouteNames.profileQuestionnairePath &&
      location != RouteNames.checkInboxPath &&
      location != RouteNames.resetPasswordPath &&
      location != RouteNames.settingsTermsPath &&
      location != RouteNames.settingsPrivacyPolicyPath) {
    return RouteNames.todayPath;
  }

  // ── Rule 4: Allow navigation ─────────────────────────────────────────────
  return null;
}
