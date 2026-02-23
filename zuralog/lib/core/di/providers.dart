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
import 'package:zuralog/features/health/data/health_repository.dart';
import 'package:zuralog/features/analytics/data/analytics_repository.dart';
import 'package:zuralog/features/integrations/data/oauth_repository.dart';

/// Provides a singleton [ApiClient] for REST API communication.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
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
