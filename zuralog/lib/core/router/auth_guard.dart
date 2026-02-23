/// Zuralog Edge Agent — GoRouter Auth Guard.
///
/// Provides [authGuardRedirect], a stateless function that encapsulates
/// all authentication-based redirect logic for the [GoRouter] configuration.
///
/// **Redirect rules (evaluated in order):**
/// 1. If [AuthState.loading] → return `null` (stay put while auth resolves).
/// 2. If [AuthState.unauthenticated] and the destination is a protected route
///    → redirect to [RouteNames.welcomePath].
/// 3. If [AuthState.authenticated] and the destination is a public auth route
///    → redirect to [RouteNames.dashboardPath] (prevent back-navigation to login).
/// 4. Otherwise → return `null` (allow navigation).
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/core/router/route_names.dart';

/// Determines whether GoRouter should redirect the user to a different
/// location based on the current [authState].
///
/// This function is designed to be passed directly to [GoRouter.redirect].
///
/// - [context] — the current [BuildContext] from the router.
/// - [state] — the [GoRouterState] describing the intended destination.
/// - [authState] — the current resolved [AuthState] from Riverpod.
///
/// Returns a path string to redirect to, or `null` to allow the navigation.
String? authGuardRedirect(
  BuildContext context,
  GoRouterState state,
  AuthState authState,
) {
  final location = state.matchedLocation;

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
  if (authState == AuthState.authenticated && isPublicPath) {
    return RouteNames.dashboardPath;
  }

  // ── Rule 4: Allow navigation ─────────────────────────────────────────────
  return null;
}
