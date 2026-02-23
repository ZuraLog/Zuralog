/// Zuralog Edge Agent — Riverpod Dependency Injection Providers.
///
/// Central location for all Riverpod providers. Each provider creates
/// and manages a single instance of a core service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/health/health_bridge.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/network/fcm_service.dart';
import 'package:zuralog/core/network/ws_client.dart';
import 'package:zuralog/core/storage/secure_storage.dart';
import 'package:zuralog/core/storage/local_db.dart';
import 'package:zuralog/core/storage/sync_status_store.dart';
import 'package:zuralog/features/auth/data/social_auth_service.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/health/data/health_repository.dart';
import 'package:zuralog/features/analytics/data/analytics_repository.dart';
import 'package:zuralog/features/integrations/data/oauth_repository.dart';

/// Provides a singleton [ApiClient] for REST API communication.
///
/// Wires [ApiClient.onUnauthenticated] to [AuthStateNotifier.forceLogout]
/// so that an expired-token 401 (after a failed refresh) automatically
/// transitions the app to the unauthenticated state and redirects the
/// user to the login screen — rather than leaving them stranded with a
/// SnackBar error on an authenticated-only screen.
///
/// The callback uses [ref.read] lazily (not [ref.watch]) to avoid a
/// circular provider dependency between [apiClientProvider] and
/// [authStateProvider].
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    onUnauthenticated: () => ref.read(authStateProvider.notifier).forceLogout(),
  );
});

/// Provides a singleton [WsClient] for WebSocket communication.
final wsClientProvider = Provider<WsClient>((ref) {
  return WsClient();
});

/// Provides a singleton [SecureStorage] for encrypted key-value storage.
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// Provides a singleton [LocalDb] for offline SQLite caching.
final localDbProvider = Provider<LocalDb>((ref) {
  return LocalDb();
});

/// Provides the native health platform channel bridge (HealthKit on iOS, Health Connect on Android).
final healthBridgeProvider = Provider<HealthBridge>((ref) => HealthBridge());

/// Provides the health data repository.
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(bridge: ref.watch(healthBridgeProvider));
});

/// Provides the OAuth repository for third-party integration flows (Phase 1.6).
final oauthRepositoryProvider = Provider<OAuthRepository>((ref) {
  return OAuthRepository(apiClient: ref.read(apiClientProvider));
});

/// Provides the analytics repository for dashboard data (Phase 1.11).
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(apiClient: ref.read(apiClientProvider));
});

/// Provides the [SyncStatusStore] singleton for tracking background sync status.
final syncStatusStoreProvider = Provider<SyncStatusStore>((ref) {
  return SyncStatusStore();
});

/// Provides the [FCMService] singleton for Firebase Cloud Messaging.
///
/// FCM initialization must be triggered explicitly (e.g., after login or via
/// the harness "Init FCM" button) — it is not called automatically to avoid
/// permission prompts before the user has consented.
final fcmServiceProvider = Provider<FCMService>((ref) => FCMService());

/// Provides the [SocialAuthService] singleton for native OAuth sign-in.
///
/// Reads the Google Web Client ID from the `--dart-define` build configuration
/// variable `GOOGLE_WEB_CLIENT_ID`. This is the OAuth 2.0 **Web Application**
/// client ID from Google Cloud Console — NOT the Firebase iOS/Android client ID.
/// See the setup guide in docs/plans/2026-02-23-social-oauth-design.md.
///
/// If the variable is absent (e.g., during CI), an empty string is passed and
/// the service's assert will fire in debug mode to surface the misconfiguration.
final socialAuthServiceProvider = Provider<SocialAuthService>((ref) {
  const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  return SocialAuthService(googleWebClientId: googleWebClientId);
});
