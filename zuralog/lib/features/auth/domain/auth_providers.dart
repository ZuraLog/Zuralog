/// Zuralog Edge Agent — Auth Riverpod Providers.
///
/// Defines Riverpod providers for the authentication layer:
/// [authRepositoryProvider] for the repository singleton and
/// [authStateProvider] for reactive auth state management.
///
/// Also provides [hasSeenOnboardingProvider] for controlling first-launch
/// onboarding display via [SharedPreferences].
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/auth/data/auth_repository.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/domain/social_auth_credentials.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';

// ── Onboarding Flag ───────────────────────────────────────────────────────────

/// SharedPreferences key for tracking whether the user has seen the onboarding.
const String _kHasSeenOnboarding = 'has_seen_onboarding';

/// Async provider that resolves to `true` if the user has already completed
/// the onboarding flow, or `false` if this is their first launch.
///
/// The flag is persisted in [SharedPreferences] and set by calling
/// [markOnboardingComplete]. The router reads this value to determine whether
/// to redirect new users to `/onboarding` before `/welcome`.
final hasSeenOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kHasSeenOnboarding) ?? false;
});

/// Marks the onboarding as completed by writing the flag to [SharedPreferences].
///
/// Call this when the user taps "Skip" or "Get Started" on the last
/// [OnboardingPageView] page.
Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kHasSeenOnboarding, true);
}

/// Provides a singleton [AuthRepository] instance.
///
/// Depends on [apiClientProvider] and [secureStorageProvider]
/// from the core DI layer.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

/// Provides the current [AuthState] and methods to update it.
///
/// Starts as [AuthState.unauthenticated] and transitions based on
/// login/logout operations.
final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

/// Notifier that manages [AuthState] transitions.
///
/// Wraps [AuthRepository] calls and updates the state accordingly.
/// The UI watches this provider to react to auth changes
/// (e.g., redirecting to login screen on logout).
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.unauthenticated;

  /// The auth repository, read from the provider graph.
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  /// Checks if the user has stored tokens and updates state.
  ///
  /// Called once on app startup to determine initial routing.
  /// If the user has valid stored tokens, also fires a profile load
  /// (fire-and-forget) so [userProfileProvider] is populated eagerly.
  Future<void> checkAuthStatus() async {
    state = AuthState.loading;
    final isLoggedIn = await _authRepository.isLoggedIn();
    state = isLoggedIn ? AuthState.authenticated : AuthState.unauthenticated;
    if (isLoggedIn) {
      // ignore: discarded_futures
      ref.read(userProfileProvider.notifier).load();
    }
  }

  /// Attempts to log in with the given credentials.
  ///
  /// Returns the [AuthResult] for the UI to display.
  /// Updates state to [AuthState.authenticated] on success and stores the
  /// [email] in [userEmailProvider] for display in the Settings screen.
  /// On success also fires a profile load (fire-and-forget).
  Future<AuthResult> login(String email, String password) async {
    state = AuthState.loading;
    final result = await _authRepository.login(email, password);

    switch (result) {
      case AuthSuccess(:final userId):
        state = AuthState.authenticated;
        ref.read(userEmailProvider.notifier).state = email;
        // ignore: discarded_futures
        ref.read(userProfileProvider.notifier).load();
        // Analytics: identify first so the login event is attributed to the
        // identified user (not the anonymous ID) in PostHog (fire-and-forget).
        final analytics = ref.read(analyticsServiceProvider);
        analytics.identify(
          userId: userId,
          properties: {
            'subscription_tier': 'free',
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        analytics.capture(
          event: 'user_logged_in',
          properties: {'method': 'email'},
        );
      case AuthFailure():
        state = AuthState.unauthenticated;
    }

    return result;
  }

  /// Attempts to register with the given credentials.
  ///
  /// Returns the [AuthResult] for the UI to display.
  /// Updates state to [AuthState.authenticated] on success and stores the
  /// [email] in [userEmailProvider] for display in the Settings screen.
  /// On success also fires a profile load (fire-and-forget).
  Future<AuthResult> register(String email, String password) async {
    state = AuthState.loading;
    final result = await _authRepository.register(email, password);

    switch (result) {
      case AuthSuccess(:final userId):
        state = AuthState.authenticated;
        ref.read(userEmailProvider.notifier).state = email;
        // ignore: discarded_futures
        ref.read(userProfileProvider.notifier).load();
        // Analytics: identify first so the signup event is attributed to the
        // identified user (not the anonymous ID) in PostHog (fire-and-forget).
        final analytics = ref.read(analyticsServiceProvider);
        analytics.identify(
          userId: userId,
          properties: {
            'signup_date': DateTime.now().toIso8601String(),
            'subscription_tier': 'free',
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        analytics.capture(
          event: 'user_signed_up',
          properties: {'method': 'email'},
        );
      case AuthFailure():
        state = AuthState.unauthenticated;
    }

    return result;
  }

  /// Authenticates via a native OAuth provider (Google or Apple).
  ///
  /// Delegates to [AuthRepository.socialLogin] with the token payload
  /// from [SocialAuthCredentials]. On success, updates auth state to
  /// [AuthState.authenticated] and eagerly loads the user profile.
  ///
  /// The [email] is not available from the SDK layer — the backend
  /// extracts it from the ID token claims after Supabase validation.
  /// Therefore [userEmailProvider] is not updated here; instead the
  /// profile load will populate it once [userProfileProvider] resolves.
  ///
  /// Args:
  ///   [credentials]: Token payload from the native OAuth SDK.
  ///
  /// Returns:
  ///   [AuthResult] — [AuthSuccess] on success, [AuthFailure] on failure.
  Future<AuthResult> socialLogin(SocialAuthCredentials credentials) async {
    state = AuthState.loading;
    final result = await _authRepository.socialLogin(
      provider: credentials.provider.name,
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
      nonce: credentials.nonce,
    );

    switch (result) {
      case AuthSuccess(:final userId):
        state = AuthState.authenticated;
        // ignore: discarded_futures
        ref.read(userProfileProvider.notifier).load();
        // Analytics: identify first so the login event is attributed to the
        // identified user (not the anonymous ID) in PostHog (fire-and-forget).
        final analytics = ref.read(analyticsServiceProvider);
        analytics.identify(
          userId: userId,
          properties: {
            'subscription_tier': 'free',
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        analytics.capture(
          event: 'user_logged_in',
          properties: {'method': credentials.provider.name},
        );
      case AuthFailure():
        state = AuthState.unauthenticated;
    }

    return result;
  }

  /// Logs out the current user.
  ///
  /// Always transitions to [AuthState.unauthenticated] and clears the
  /// stored email from [userEmailProvider]. Also clears the cached
  /// [userProfileProvider] state.
  Future<void> logout() async {
    // Analytics: reset identity before clearing auth state (fire-and-forget).
    ref.read(analyticsServiceProvider).reset();
    state = AuthState.loading;
    await _authRepository.logout();
    ref.read(userEmailProvider.notifier).state = '';
    ref.read(userProfileProvider.notifier).clear();
    state = AuthState.unauthenticated;
  }

  /// Force-transitions to [AuthState.unauthenticated] without calling the
  /// backend logout endpoint.
  ///
  /// Called by [ApiClient.onUnauthenticated] when both the access token and
  /// refresh token are expired and cannot be recovered. Clears the local
  /// profile and email state so the router redirects to the login screen.
  void forceLogout() {
    // Analytics: reset identity on force logout (fire-and-forget).
    ref.read(analyticsServiceProvider).reset();
    ref.read(userEmailProvider.notifier).state = '';
    ref.read(userProfileProvider.notifier).clear();
    state = AuthState.unauthenticated;
  }
}

/// Convenience provider that returns `true` when the user is authenticated.
///
/// Derived from [authStateProvider] for widgets that only care about
/// the boolean logged-in state.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider) == AuthState.authenticated;
});

/// Stores the currently authenticated user's email address.
///
/// Set by [AuthStateNotifier.login] and [AuthStateNotifier.register] on
/// successful auth, and cleared on logout. Defaults to an empty string.
///
/// Consumer example:
/// ```dart
/// final email = ref.watch(userEmailProvider);
/// ```
final userEmailProvider = StateProvider<String>(
  (ref) => '',
  name: 'userEmailProvider',
);

// ── User Profile ──────────────────────────────────────────────────────────────

/// Provides the current user's [UserProfile], or `null` before the profile
/// has been loaded.
///
/// The profile is populated automatically (fire-and-forget) after a
/// successful [AuthStateNotifier.login], [AuthStateNotifier.register], or
/// [AuthStateNotifier.checkAuthStatus] call. Widgets can watch this provider
/// to access profile data (e.g., AI greeting name, onboarding status).
///
/// Consumer example:
/// ```dart
/// final profile = ref.watch(userProfileProvider);
/// final name = profile?.aiName ?? 'there';
/// ```
final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile?>(
  UserProfileNotifier.new,
);

/// Whether the user profile is currently being fetched from the backend.
///
/// The router guard watches this to avoid redirecting to the questionnaire
/// while [UserProfileNotifier.load] is still in-flight. Without this flag,
/// any authenticated user whose profile hasn't loaded yet (e.g., on a fast
/// login) would be incorrectly sent to the questionnaire.
///
/// `true` only while [UserProfileNotifier.load] is executing.
final isLoadingProfileProvider = StateProvider<bool>((ref) => false);

/// Notifier that manages the current user's [UserProfile] state.
///
/// Loaded on login/register/startup and updated after profile edits.
/// State is `null` when unauthenticated or before the first fetch.
class UserProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => null;

  /// Fetches the profile from the backend and updates state.
  ///
  /// Sets [isLoadingProfileProvider] to `true` while fetching and `false`
  /// when done (success or failure). The router guard reads this flag to
  /// avoid redirecting to the questionnaire during the in-flight load.
  ///
  /// Errors are logged via [debugPrint] and the state remains `null`,
  /// allowing the UI to degrade gracefully (e.g., fallback greeting).
  Future<void> load() async {
    ref.read(isLoadingProfileProvider.notifier).state = true;
    try {
      final repo = ref.read(authRepositoryProvider);
      state = await repo.fetchProfile();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      debugPrint('[UserProfileNotifier.load] Profile fetch failed: $e\n$st');
    } finally {
      ref.read(isLoadingProfileProvider.notifier).state = false;
    }
  }

  /// Updates profile fields on the backend and refreshes local state.
  ///
  /// Only non-null arguments are sent in the PATCH request.
  ///
  /// Args:
  ///   [displayName]: New display name (optional).
  ///   [nickname]: New nickname for AI greetings (optional).
  ///   [birthday]: New date of birth (optional).
  ///   [gender]: New gender identifier (optional).
  ///   [onboardingComplete]: Marks onboarding as complete (optional).
  ///
  /// Throws:
  ///   [DioException] if the network call fails — callers should handle this.
  Future<void> update({
    String? displayName,
    String? nickname,
    DateTime? birthday,
    String? gender,
    bool? onboardingComplete,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = await repo.updateProfile(
      displayName: displayName,
      nickname: nickname,
      birthday: birthday,
      gender: gender,
      onboardingComplete: onboardingComplete,
    );
  }

  /// Clears the cached profile state (called on logout).
  void clear() {
    state = null;
    // Also reset the loading flag so the router guard starts fresh.
    ref.read(isLoadingProfileProvider.notifier).state = false;
  }
}
