/// Life Logger Edge Agent — Riverpod Dependency Injection Providers.
///
/// Central location for all Riverpod providers. Each provider creates
/// and manages a single instance of a core service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_logger/core/health/health_bridge.dart';
import 'package:life_logger/core/network/api_client.dart';
import 'package:life_logger/core/network/ws_client.dart';
import 'package:life_logger/core/storage/secure_storage.dart';
import 'package:life_logger/core/storage/local_db.dart';
import 'package:life_logger/features/health/data/health_repository.dart';
import 'package:life_logger/features/integrations/data/oauth_repository.dart';

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
