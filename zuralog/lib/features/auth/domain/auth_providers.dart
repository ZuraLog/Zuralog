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

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/monitoring/sentry_breadcrumbs.dart';
import 'package:zuralog/features/analytics/domain/analytics_providers.dart';
import 'package:zuralog/features/auth/data/auth_repository.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/domain/social_auth_credentials.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/trends/providers/trends_providers.dart';

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

/// Signals that the user triggered "Replay Onboarding" from settings.
///
/// When true, the router's onboarding-complete guard is bypassed so the user
/// can revisit [ChatOnboardingScreen] without being redirected to Today.
/// Reset to false by [ChatOnboardingScreen] after it finishes.
final isReplayingOnboardingProvider = StateProvider<bool>((ref) => false);

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
    if (isLoggedIn) {
      // Mark profile as loading BEFORE setting authenticated so the router
      // never sees: authenticated + isLoadingProfile=false + profile=null,
      // which would incorrectly redirect to the questionnaire.
      ref.read(isLoadingProfileProvider.notifier).state = true;
    }
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
    SentryBreadcrumbs.authEvent(event: 'login_attempt', method: 'email');
    final result = await _authRepository.login(email, password);

    switch (result) {
      case AuthSuccess(:final userId):
        SentryBreadcrumbs.authEvent(event: 'login_success', method: 'email');
        ref.read(isLoadingProfileProvider.notifier).state = true;
        state = AuthState.authenticated;
        ref.read(userEmailProvider.notifier).state = email;
        // ignore: discarded_futures
        ref.read(userProfileProvider.notifier).load();
        // Analytics: await identify so the login event is attributed to the
        // identified user, then reload feature flags for user-specific targeting.
        final analytics = ref.read(analyticsServiceProvider);
        await analytics.identify(
          userId: userId,
          properties: {
            'subscription_tier': 'free',
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        analytics.capture(
          event: AnalyticsEvents.loginCompleted,
          properties: {'method': 'email'},
        );
        analytics.reloadFeatureFlags();
      case AuthFailure():
        SentryBreadcrumbs.authEvent(event: 'login_failure', method: 'email');
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
    SentryBreadcrumbs.authEvent(event: 'register_attempt', method: 'email');
    final result = await _authRepository.register(email, password);

    switch (result) {
      case AuthSuccess(:final userId):
        SentryBreadcrumbs.authEvent(event: 'register_success', method: 'email');
        ref.read(isLoadingProfileProvider.notifier).state = true;
        state = AuthState.authenticated;
        ref.read(userEmailProvider.notifier).state = email;
        // ignore: discarded_futures
        ref.read(userProfileProvider.notifier).load();
        // Analytics: await identify so the signup event is attributed to the
        // identified user, then reload feature flags for user-specific targeting.
        final analytics = ref.read(analyticsServiceProvider);
        await analytics.identify(
          userId: userId,
          properties: {
            'signup_date': DateTime.now().toIso8601String(),
            'subscription_tier': 'free',
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        analytics.capture(
          event: AnalyticsEvents.signUpCompleted,
          properties: {'method': 'email'},
        );
        analytics.reloadFeatureFlags();
      case AuthFailure():
        SentryBreadcrumbs.authEvent(event: 'register_failure', method: 'email');
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
    SentryBreadcrumbs.authEvent(
      event: 'social_login_attempt',
      method: credentials.provider.name,
    );
    final result = await _authRepository.socialLogin(
      provider: credentials.provider.name,
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
      nonce: credentials.nonce,
    );

    switch (result) {
      case AuthSuccess(:final userId):
        SentryBreadcrumbs.authEvent(
          event: 'social_login_success',
          method: credentials.provider.name,
        );
        ref.read(isLoadingProfileProvider.notifier).state = true;
        state = AuthState.authenticated;
        // ignore: discarded_futures
        ref.read(userProfileProvider.notifier).load();
        // Analytics: await identify so the login event is attributed to the
        // identified user, then reload feature flags for user-specific targeting.
        final analytics = ref.read(analyticsServiceProvider);
        await analytics.identify(
          userId: userId,
          properties: {
            'subscription_tier': 'free',
            'platform': Platform.isIOS ? 'ios' : 'android',
          },
        );
        analytics.capture(
          event: AnalyticsEvents.loginCompleted,
          properties: {'method': credentials.provider.name},
        );
        analytics.reloadFeatureFlags();
      case AuthFailure():
        SentryBreadcrumbs.authEvent(
          event: 'social_login_failure',
          method: credentials.provider.name,
        );
        state = AuthState.unauthenticated;
    }

    return result;
  }

  /// Permanently deletes the current user's account and all associated data.
  ///
  /// Calls `DELETE /api/v1/users/me` on the backend, which wipes every row
  /// belonging to this user and removes them from Supabase Auth.
  /// On success, performs the same full state cleanup as [logout] so the
  /// router redirects to the welcome/auth screen.
  ///
  /// Throws:
  ///   [DioException] if the network call fails — callers must handle this
  ///   and show an appropriate error message to the user.
  Future<void> deleteAccount() async {
    ref.read(analyticsServiceProvider).reset();
    SentryBreadcrumbs.authEvent(event: 'delete_account');
    state = AuthState.loading;
    await _authRepository.deleteAccount();
    ref.read(userEmailProvider.notifier).state = '';
    ref.read(userProfileProvider.notifier).clear();
    await _clearUserState();
    state = AuthState.unauthenticated;
  }

  /// Logs out the current user.
  ///
  /// Always transitions to [AuthState.unauthenticated] and clears ALL
  /// user-specific state: tokens, profile, email, SharedPreferences keys,
  /// repository in-memory caches, and Riverpod provider data. This prevents
  /// any health data from leaking if a different user logs in on the same
  /// device.
  Future<void> logout() async {
    // Analytics: reset identity before clearing auth state (fire-and-forget).
    ref.read(analyticsServiceProvider).reset();
    SentryBreadcrumbs.authEvent(event: 'logout');
    state = AuthState.loading;
    await _authRepository.logout();
    ref.read(userEmailProvider.notifier).state = '';
    ref.read(userProfileProvider.notifier).clear();
    await _clearUserState();
    state = AuthState.unauthenticated;
  }

  /// Force-transitions to [AuthState.unauthenticated] without calling the
  /// backend logout endpoint.
  ///
  /// Called by [ApiClient.onUnauthenticated] when both the access token and
  /// refresh token are expired and cannot be recovered. Clears the local
  /// profile, email state, and all user-specific caches so the router
  /// redirects to the login screen without leaking stale health data.
  void forceLogout() {
    // Guard: if already unauthenticated, do nothing. Without this, every
    // concurrent 401 calls forceLogout again, re-invalidating providers that
    // are already being rebuilt and creating an infinite request loop.
    if (state == AuthState.unauthenticated) return;

    ref.read(analyticsServiceProvider).reset();
    SentryBreadcrumbs.authEvent(event: 'force_logout');
    ref.read(userEmailProvider.notifier).state = '';
    ref.read(userProfileProvider.notifier).clear();

    // Set unauthenticated BEFORE clearing state. The router reacts to this
    // change and navigates away, which disposes the widgets that are watching
    // the analytics/preferences providers. If we called _clearUserState()
    // first, those providers would be invalidated while widgets were still
    // watching them, causing an immediate re-run → new 401 → infinite loop.
    state = AuthState.unauthenticated;
    _clearUserState();
  }

  /// Clears all user-specific cached data so the next login starts fresh.
  ///
  /// Covers three layers:
  /// 1. SharedPreferences keys that store per-user data (not device prefs).
  /// 2. In-memory TTL caches inside repository singletons.
  /// 3. Riverpod provider state (forces re-fetch on next access).
  Future<void> _clearUserState() async {
    // ── 1. SharedPreferences: clear user-specific keys ────────────────────
    final prefs = await SharedPreferences.getInstance();

    // Integration connection states (e.g. integration_connected_strava).
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('integration_connected_')) {
        await prefs.remove(key);
      }
    }

    // User preferences cache (full JSON blob from the server).
    await prefs.remove('user_preferences_cache');

    // Sync timestamps.
    await prefs.remove('last_sync_timestamp');
    await prefs.remove('sync_in_progress');
    await prefs.remove('health_last_sync_at');

    // Analytics first-action flags (should fire per user, not per device).
    await prefs.remove('analytics_first_quick_log');
    await prefs.remove('analytics_first_insight_viewed');
    await prefs.remove('analytics_first_goal_created');

    // Dismissed trend suggestions.
    await prefs.remove('dismissed_correlation_suggestions');

    // Workout: bookmarked exercises and active session draft.
    await prefs.remove('workout_bookmarked_exercises');
    await prefs.remove('workout_active_draft');

    // ── 2. Repository in-memory caches ────────────────────────────────────
    ref.read(todayRepositoryProvider).invalidateFeedCache();
    ref.read(dataRepositoryProvider).invalidateAll();
    ref.read(progressRepositoryProvider).invalidateAll();
    ref.read(trendsRepositoryProvider).invalidateAll();
    ref.read(analyticsRepositoryProvider).invalidateAll();

    // ── 3. Riverpod providers: invalidate so next access re-fetches ───────

    // Today tab.
    ref.invalidate(healthScoreProvider);
    ref.invalidate(todayFeedProvider);
    ref.invalidate(notificationsProvider);

    // Data tab.
    ref.invalidate(dashboardProvider);

    // Coach tab.
    ref.invalidate(coachConversationsProvider);
    ref.invalidate(coachPromptSuggestionsProvider);
    ref.invalidate(coachQuickActionsProvider);

    // Trends tab.
    ref.invalidate(trendsHomeProvider);

    // Progress tab.
    ref.invalidate(progressHomeProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(achievementsProvider);
    ref.invalidate(weeklyReportProvider);
    ref.invalidate(journalProvider);

    // Analytics.
    ref.invalidate(dailySummaryProvider);
    ref.invalidate(weeklyTrendsProvider);
    ref.invalidate(dashboardInsightProvider);

    // Settings / Preferences.
    ref.invalidate(userPreferencesProvider);

    // Integrations.
    ref.invalidate(integrationsProvider);
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
///
/// See also [profileLoadFailedProvider] for the error state.
final isLoadingProfileProvider = StateProvider<bool>((ref) => false);

/// `true` if the last [UserProfileNotifier.load] call threw an error.
///
/// The router guard reads this to avoid redirecting to the questionnaire when
/// the profile fetch fails (e.g. expired token, network error). In that case
/// the user should stay on or be returned to the auth screens rather than
/// being sent into an incomplete onboarding flow.
final profileLoadFailedProvider = StateProvider<bool>((ref) => false);


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
    ref.read(profileLoadFailedProvider.notifier).state = false;
    try {
      final repo = ref.read(authRepositoryProvider);
      state = await repo.fetchProfile();
      // Sync email back for social-login users whose email was not available
      // at login time. The profile fetch includes the email from the backend.
      final fetchedEmail = state?.email ?? '';
      if (fetchedEmail.isNotEmpty && ref.read(userEmailProvider).isEmpty) {
        ref.read(userEmailProvider.notifier).state = fetchedEmail;
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      debugPrint('[UserProfileNotifier.load] Profile fetch failed: $e\n$st');
      ref.read(profileLoadFailedProvider.notifier).state = true;
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
  ///   [heightCm]: New height in centimetres (optional).
  ///   [weightKg]: New weight in kilograms (optional).
  ///   [onboardingComplete]: Marks onboarding as complete (optional).
  ///
  /// Throws:
  ///   [DioException] if the network call fails — callers should handle this.
  Future<void> update({
    String? displayName,
    String? nickname,
    DateTime? birthday,
    String? gender,
    double? heightCm,
    double? weightKg,
    bool? onboardingComplete,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = await repo.updateProfile(
      displayName: displayName,
      nickname: nickname,
      birthday: birthday,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      onboardingComplete: onboardingComplete,
    );
  }

  /// Sends a request to change the authenticated user's email address.
  ///
  /// The backend sends a confirmation email to [newEmail] — the change only
  /// takes effect after the user clicks the confirmation link.
  ///
  /// Throws:
  ///   [DioException] if the network call fails — callers should handle this.
  Future<void> changeEmail(String newEmail) async {
    await ref.read(authRepositoryProvider).changeEmail(newEmail);
  }

  /// Sends a request to change the authenticated user's password.
  ///
  /// Args:
  ///   [currentPassword]: The user's existing password, verified server-side.
  ///   [newPassword]: The replacement password.
  ///
  /// Throws:
  ///   [DioException] if the network call fails — callers should handle this.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ref.read(authRepositoryProvider).changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Uploads an avatar image and updates the local profile state with the
  /// returned URL.
  ///
  /// Args:
  ///   [filePath]: Absolute path to the image file on the device.
  ///   [contentType]: MIME type of the image (e.g. `image/jpeg`).
  ///
  /// Throws:
  ///   [DioException] if the network call fails — callers should handle this.
  Future<void> uploadAvatar({
    required String filePath,
    required String contentType,
  }) async {
    final avatarUrl = await ref.read(authRepositoryProvider).uploadAvatar(
      filePath: filePath,
      contentType: contentType,
    );
    // Append a cache-busting timestamp so Flutter's NetworkImage treats
    // this as a new URL and doesn't serve the old cached image.
    final bustedUrl = '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    if (state != null) {
      state = state!.copyWith(avatarUrl: bustedUrl);
    } else {
      // Profile not loaded yet — re-fetch so state reflects the upload
      await load();
    }
  }

  /// Permanently deletes the authenticated user's account.
  ///
  /// This action is irreversible. The backend removes all user data and
  /// revokes all sessions.
  ///
  /// Throws:
  ///   [DioException] if the network call fails — callers should handle this.
  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
  }

  /// Clears the cached profile state (called on logout).
  void clear() {
    state = null;
    ref.read(isLoadingProfileProvider.notifier).state = false;
    ref.read(profileLoadFailedProvider.notifier).state = false;
  }
}
