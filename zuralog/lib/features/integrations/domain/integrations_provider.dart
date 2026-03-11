/// Zuralog — Integrations Riverpod Provider.
///
/// Defines [IntegrationsState], [IntegrationsNotifier], and
/// [integrationsProvider] — the full state-management layer for the
/// Integrations Hub screen.
///
/// The notifier interacts with [OAuthRepository] for Strava OAuth and
/// [HealthRepository] for on-device health permissions; all other integrations
/// show a "coming soon" SnackBar.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/storage/secure_storage.dart';
import 'package:zuralog/features/health/data/health_repository.dart';
import 'package:zuralog/features/health/data/health_sync_service.dart';
import 'package:zuralog/features/integrations/data/oauth_repository.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Immutable state for the Integrations Hub screen.
///
/// Holds the list of all known integrations plus loading / error flags.
class IntegrationsState {
  /// The ordered list of integrations to display.
  final List<IntegrationModel> integrations;

  /// Whether a background load operation is in progress.
  final bool isLoading;

  /// Human-readable error message, or `null` if no error is present.
  final String? error;

  /// Creates an [IntegrationsState].
  const IntegrationsState({
    this.integrations = const [],
    this.isLoading = false,
    this.error,
  });

  /// Returns a copy with the specified fields replaced.
  IntegrationsState copyWith({
    List<IntegrationModel>? integrations,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return IntegrationsState(
      integrations: integrations ?? this.integrations,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// StateNotifier that manages the [IntegrationsState].
///
/// Provides actions for loading integrations, connecting / disconnecting
/// services, and requesting on-device health permissions.
class IntegrationsNotifier extends StateNotifier<IntegrationsState> {
  /// Creates an [IntegrationsNotifier] with the required repositories.
  ///
  /// Parameters:
  ///   oauthRepository: Handles the Strava OAuth flow.
  ///   healthRepository: Handles HealthKit / Health Connect permissions.
  ///   healthSyncService: Optional — pushes HealthKit data to Cloud Brain after connect.
  ///   secureStorage: Optional — reads the JWT token to configure native background sync.
  ///   apiClient: Optional — provides the Cloud Brain base URL for native sync config.
  IntegrationsNotifier({
    required OAuthRepository oauthRepository,
    required HealthRepository healthRepository,
    HealthSyncService? healthSyncService,
    SecureStorage? secureStorage,
    ApiClient? apiClient,
    AnalyticsService? analyticsService,
  }) : _oauthRepository = oauthRepository,
       _healthRepository = healthRepository,
       _healthSyncService = healthSyncService,
       _secureStorage = secureStorage,
       _apiClient = apiClient,
       _analytics = analyticsService,
       // Start in loading state so the screen never briefly shows
       // "No integrations available." before loadIntegrations() fires.
       super(const IntegrationsState(isLoading: true));

  final OAuthRepository _oauthRepository;
  final HealthRepository _healthRepository;

  /// Optional sync service. When present, initial sync is triggered after
  /// Apple Health authorization is granted.
  final HealthSyncService? _healthSyncService;

  /// Optional secure storage. Used to read the JWT token for native Keychain
  /// persistence so [HealthKitBridge] can sync in the background.
  final SecureStorage? _secureStorage;

  /// Optional API client. Provides the Cloud Brain base URL for native sync.
  final ApiClient? _apiClient;

  /// Optional analytics service for integration event tracking.
  final AnalyticsService? _analytics;

  // ── Mock seed data ─────────────────────────────────────────────────────────

  /// Default integration list used by [loadIntegrations].
  ///
  /// [logoAsset] is omitted from all entries — the [IntegrationLogo] widget
  /// renders coloured initials when no asset path is provided. This avoids
  /// Flutter asset-load errors for brand image files that are not yet bundled.
  ///
  /// Status notes:
  ///   - Strava: [available] — OAuth flow is implemented.
  ///   - Apple Health: [available] on iOS (HealthKit); greys out on Android via
  ///     [PlatformCompatibility.iosOnly].
  ///   - Fitbit: [comingSoon] — OAuth not yet wired.
  ///   - Google Health Connect: [comingSoon] — Android Health Connect API not yet wired.
  ///   - Garmin / WHOOP: [comingSoon] — future integrations.
  static const List<IntegrationModel> _defaultIntegrations = [
    IntegrationModel(
      id: 'strava',
      name: 'Strava',
      status: IntegrationStatus.available,
      description: 'Sync runs, rides, and workouts automatically.',
      compatibility: PlatformCompatibility.all,
    ),
    IntegrationModel(
      id: 'apple_health',
      name: 'Apple Health',
      status: IntegrationStatus.available,
      description: 'Read steps, sleep, and vitals from HealthKit.',
      compatibility: PlatformCompatibility.iosOnly,
    ),
    IntegrationModel(
      id: 'fitbit',
      name: 'Fitbit',
      status: IntegrationStatus.available,
      description: 'Import daily activity, heart rate, and sleep.',
      compatibility: PlatformCompatibility.all,
    ),
    IntegrationModel(
      id: 'oura',
      name: 'Oura Ring',
      status: IntegrationStatus.available,
      description: 'Sleep, readiness, activity, HRV, stress, and recovery data from your Oura Ring.',
      compatibility: PlatformCompatibility.all,
    ),
    IntegrationModel(
      id: 'withings',
      name: 'Withings',
      status: IntegrationStatus.available,
      description:
          'Smart scales, sleep mats, blood pressure monitors, and thermometers. '
          'Body composition, sleep, BP, temperature, and vitals.',
      compatibility: PlatformCompatibility.all,
    ),
    IntegrationModel(
      id: 'polar',
      name: 'Polar',
      status: IntegrationStatus.available,
      description:
          'Heart rate monitors, GPS watches, and fitness trackers. '
          'Exercises, sleep, Nightly Recharge, continuous HR, cardio load, and SleepWise alertness.',
      compatibility: PlatformCompatibility.all,
    ),
    IntegrationModel(
      id: 'google_health_connect',
      name: 'Google Health Connect',
      // Available on Android; shown in the Available section with a platform
      // badge on iOS so users can see it exists even on incompatible devices.
      status: IntegrationStatus.available,
      description: 'Sync workouts and health data from Android.',
      compatibility: PlatformCompatibility.androidOnly,
    ),
    IntegrationModel(
      id: 'garmin',
      name: 'Garmin',
      status: IntegrationStatus.comingSoon,
      description: 'Connect your Garmin device for detailed metrics.',
      compatibility: PlatformCompatibility.all,
    ),
    IntegrationModel(
      id: 'whoop',
      name: 'WHOOP',
      status: IntegrationStatus.comingSoon,
      description: 'Strain, recovery, and sleep from your WHOOP strap.',
      compatibility: PlatformCompatibility.all,
    ),
  ];

  // ── Public Actions ─────────────────────────────────────────────────────────

  /// Populates the integration list, fetching real connection status from
  /// the server for OAuth providers and from SharedPreferences for on-device
  /// health providers (Apple Health, Google Health Connect).
  ///
  /// **Flow:**
  /// 1. Start from the `_defaultIntegrations` catalog (defines the known set).
  /// 2. Preserve any in-memory connected state from the current session.
  /// 3. For device-local providers (apple_health, google_health_connect):
  ///    restore from SharedPreferences — the OS remembers the permission grant
  ///    and SharedPreferences records whether it was granted.
  /// 4. For server-side OAuth providers (strava, fitbit, oura, polar, withings):
  ///    call each provider's `/status` endpoint in parallel. The server is the
  ///    authoritative source for whether an OAuth token is active.
  /// 5. Update SharedPreferences as a fast-start cache so the next cold-start
  ///    shows the right state before the server responds.
  Future<void> loadIntegrations() async {
    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Build the existing in-memory status map (preserves live connected
    //    state for integrations that were connected in the current session).
    final existing = {for (final i in state.integrations) i.id: i};

    // 2. Populate from defaults, preserving any live connected state.
    var merged = _defaultIntegrations.map((defaults) {
      final current = existing[defaults.id];
      if (current != null) {
        return defaults.copyWith(status: current.status);
      }
      return defaults;
    }).toList();

    // 3. Restore device-local providers from SharedPreferences.
    //    Apple Health and Google Health Connect don't have server-side tokens —
    //    their connection state is tracked locally. SharedPreferences is the
    //    authoritative source for these two only.
    const deviceLocalProviders = {'apple_health', 'google_health_connect'};
    final prefs = await SharedPreferences.getInstance();
    merged = merged.map((integration) {
      if (deviceLocalProviders.contains(integration.id) &&
          integration.status != IntegrationStatus.connected) {
        final saved = prefs.getBool('$_connectedPrefix${integration.id}');
        if (saved == true) {
          return integration.copyWith(status: IntegrationStatus.connected);
        }
      }
      return integration;
    }).toList();

    // Show the list immediately with cached/default states so the screen
    // isn't blank while we wait for the server calls below.
    state = state.copyWith(integrations: merged, isLoading: false);

    // 4. Fetch real status from the server for OAuth-based providers.
    //    All calls run in parallel for speed.
    try {
      final statusFutures = <String, Future<Map<String, dynamic>>>{};
      for (final provider in OAuthRepository.serverProviders) {
        statusFutures[provider] = _oauthRepository.getProviderStatus(provider);
      }

      final results = <String, Map<String, dynamic>>{};
      for (final entry in statusFutures.entries) {
        results[entry.key] = await entry.value;
      }

      // 5. Merge server results into the integration list.
      merged = state.integrations.map((integration) {
        final serverStatus = results[integration.id];
        if (serverStatus == null) return integration;

        final connected = serverStatus['connected'] as bool? ?? false;
        final lastSyncedStr = serverStatus['last_synced_at'] as String?;
        final syncStatus = serverStatus['sync_status'] as String?;

        DateTime? lastSynced;
        if (lastSyncedStr != null) {
          lastSynced = DateTime.tryParse(lastSyncedStr);
        }

        IntegrationStatus newStatus;
        if (connected) {
          if (syncStatus == 'syncing') {
            newStatus = IntegrationStatus.syncing;
          } else if (syncStatus == 'error') {
            newStatus = IntegrationStatus.error;
          } else {
            newStatus = IntegrationStatus.connected;
          }
        } else {
          // Only reset to available if the integration isn't a comingSoon one.
          newStatus = integration.status == IntegrationStatus.comingSoon
              ? IntegrationStatus.comingSoon
              : IntegrationStatus.available;
        }

        return integration.copyWith(
          status: newStatus,
          lastSynced: lastSynced,
        );
      }).toList();

      state = state.copyWith(integrations: merged);

      // 6. Update SharedPreferences cache for server-side providers.
      for (final provider in OAuthRepository.serverProviders) {
        final connected =
            results[provider]?['connected'] as bool? ?? false;
        await prefs.setBool('$_connectedPrefix$provider', connected);
      }
    } catch (e, st) {
      // Server fetch failed — keep the default/cached states shown above.
      // Don't surface an error to the user; the cached view is good enough.
      debugPrint(
        '[IntegrationsNotifier] Server status fetch failed: $e\n$st',
      );
      Sentry.captureException(e, stackTrace: st);
    }
  }

  /// Connects the integration identified by [integrationId].
  ///
  /// For Strava, delegates to [OAuthRepository.getStravaAuthUrl].
  /// For Fitbit, delegates to [OAuthRepository.getFitbitAuthUrl].
  /// For Apple Health, delegates to [HealthRepository.requestAuthorization].
  /// For all others, transitions the status to [IntegrationStatus.syncing]
  /// briefly, then sets it back to [IntegrationStatus.available] with a
  /// "coming soon" indication (actual OAuth flows not yet implemented).
  ///
  /// Parameters:
  ///   integrationId: The [IntegrationModel.id] of the service to connect.
  ///   context: Used to show [SnackBar] feedback for unsupported services.
  Future<void> connect(String integrationId, BuildContext context) async {
    _setStatus(integrationId, IntegrationStatus.syncing);

    try {
      switch (integrationId) {
        case 'strava':
          final url = await _oauthRepository.getStravaAuthUrl();
          if (!context.mounted) break;
          if (url != null) {
            // URL obtained — deep-link handler will call handleStravaCallback.
            _setStatus(integrationId, IntegrationStatus.connected);
            _analytics?.capture(
              event: 'integration_connected',
              properties: {'provider': integrationId},
            );
          } else {
            _setStatus(integrationId, IntegrationStatus.available);
            _showSnackBar(context, 'Could not start Strava connection.');
          }
        case 'fitbit':
          final url = await _oauthRepository.getFitbitAuthUrl();
          if (!context.mounted) break;
          if (url != null) {
            // URL obtained — deep-link handler will call handleFitbitCallback.
            _setStatus(integrationId, IntegrationStatus.connected);
            _analytics?.capture(
              event: 'integration_connected',
              properties: {'provider': integrationId},
            );
          } else {
            _setStatus(integrationId, IntegrationStatus.available);
            _showSnackBar(context, 'Could not start Fitbit connection.');
          }
        case 'oura':
          final url = await _oauthRepository.getOuraAuthUrl();
          if (!context.mounted) break;
          if (url != null) {
            // URL obtained — deep-link handler will call handleOuraCallback.
            _setStatus(integrationId, IntegrationStatus.connected);
            _analytics?.capture(
              event: 'integration_connected',
              properties: {'provider': integrationId},
            );
          } else {
            _setStatus(integrationId, IntegrationStatus.available);
            _showSnackBar(context, 'Could not start Oura Ring connection.');
          }
        case 'withings':
          final url = await _oauthRepository.getWithingsAuthUrl();
          if (!context.mounted) break;
          if (url != null) {
            // URL obtained — Withings redirects browser back via server-side
            // callback; deep-link handler handles zuralog://oauth/withings?success=true.
            _setStatus(integrationId, IntegrationStatus.connected);
            _analytics?.capture(
              event: 'integration_connected',
              properties: {'provider': integrationId},
            );
          } else {
            _setStatus(integrationId, IntegrationStatus.available);
            _showSnackBar(context, 'Could not start Withings connection.');
          }
        case 'polar':
          final url = await _oauthRepository.getPolarAuthUrl();
          if (!context.mounted) break;
          if (url != null) {
            // URL obtained — deep-link handler will call handlePolarCallback.
            _setStatus(integrationId, IntegrationStatus.connected);
            _analytics?.capture(
              event: 'integration_connected',
              properties: {'provider': integrationId},
            );
          } else {
            _setStatus(integrationId, IntegrationStatus.available);
            _showSnackBar(context, 'Could not start Polar connection.');
          }
        case 'apple_health':
          final granted = await _healthRepository.requestAuthorization();
          final newStatus = granted
              ? IntegrationStatus.connected
              : IntegrationStatus.available;
          _setStatus(integrationId, newStatus);
          if (granted) {
            await _saveConnectedState(integrationId, connected: true);
            _analytics?.capture(
              event: 'integration_connected',
              properties: {'provider': integrationId},
            );
            // Persist JWT + API URL to iOS Keychain so native Swift code can
            // sync HealthKit data directly to the Cloud Brain in the background
            // without requiring the Flutter engine to be running.
            if (_secureStorage != null && _apiClient != null) {
              final authToken = await _secureStorage.getAuthToken();
              if (authToken != null) {
                await _healthRepository.configureBackgroundSync(
                  authToken: authToken,
                  apiBaseUrl: _apiClient.baseUrl,
                );
                debugPrint(
                  '[IntegrationsNotifier] configureBackgroundSync completed',
                );
              }
            }
            // Start native background observers (HKObserverQuery on iOS).
            await _healthRepository.startBackgroundObservers();
            // Trigger initial 30-day sync to populate Cloud Brain.
            // Fire-and-forget — sync runs in background; UI doesn't wait.
            if (_healthSyncService != null) {
              unawaited(
                _healthSyncService.syncToCloud(days: 30).then((success) {
                  debugPrint(
                    '[IntegrationsNotifier] Initial Apple Health sync '
                    '${success ? 'succeeded' : 'failed'}',
                  );
                }),
              );
            }
          }
        case 'google_health_connect':
          // Android-only: Health Connect is guarded by PlatformCompatibility.androidOnly
          // in IntegrationModel, so this branch is unreachable on iOS.
          final isAvailable = await _healthRepository.isAvailable();
          if (!isAvailable) {
            _setStatus(integrationId, IntegrationStatus.available);
            if (context.mounted) {
              _showSnackBar(
                context,
                'Health Connect is not installed. Install it from the Play Store to connect.',
              );
            }
            break;
          }
          final granted = await _healthRepository.requestAuthorization();
          final newStatus = granted
              ? IntegrationStatus.connected
              : IntegrationStatus.available;
          _setStatus(integrationId, newStatus);
          if (granted) {
            await _saveConnectedState(integrationId, connected: true);
            _analytics?.capture(
              event: 'integration_connected',
              properties: {'provider': integrationId},
            );
            // Persist JWT to EncryptedSharedPreferences so HealthSyncWorker
            // can authenticate with the Cloud Brain in the background.
            if (_secureStorage != null && _apiClient != null) {
              final authToken = await _secureStorage.getAuthToken();
              if (authToken != null) {
                await _healthRepository.configureBackgroundSync(
                  authToken: authToken,
                  apiBaseUrl: _apiClient.baseUrl,
                );
                debugPrint(
                  '[IntegrationsNotifier] HC configureBackgroundSync completed',
                );
              }
            }
            // Schedule the WorkManager periodic sync task.
            await _healthRepository.startBackgroundObservers();
            // Trigger initial 30-day sync to populate Cloud Brain.
            // Fire-and-forget — sync runs in background; UI doesn't wait.
            if (_healthSyncService != null) {
              unawaited(
                _healthSyncService.syncToCloud(days: 30).then((success) {
                  debugPrint(
                    '[IntegrationsNotifier] Initial Health Connect sync '
                    '${success ? 'succeeded' : 'failed'}',
                  );
                }),
              );
            }
          }
        default:
          // Not yet implemented — show coming soon feedback.
          _setStatus(integrationId, IntegrationStatus.available);
          if (context.mounted) {
            _showSnackBar(context, 'Coming soon!');
          }
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      debugPrint(
        '[IntegrationsNotifier] connect($integrationId) failed: $e\n$st',
      );
      _setStatus(integrationId, IntegrationStatus.error);
    }
  }

  /// Disconnects the integration identified by [integrationId].
  ///
  /// For server-side OAuth providers, also tells the backend to revoke tokens
  /// and deactivate the integration record. The backend call is fire-and-forget
  /// so the UI updates instantly.
  ///
  /// Sets the integration's status back to [IntegrationStatus.available]
  /// and clears [IntegrationModel.lastSynced].
  ///
  /// Parameters:
  ///   integrationId: The [IntegrationModel.id] of the service to disconnect.
  void disconnect(String integrationId) {
    // Analytics: track integration disconnection (fire-and-forget).
    _analytics?.capture(
      event: 'integration_disconnected',
      properties: {'provider': integrationId},
    );

    // For server-side OAuth providers, tell the backend to revoke tokens.
    if (OAuthRepository.serverProviders.contains(integrationId)) {
      unawaited(
        _oauthRepository.disconnectProvider(integrationId).catchError((
          Object e,
          StackTrace st,
        ) {
          Sentry.captureException(e, stackTrace: st);
          debugPrint(
            '[IntegrationsNotifier] Backend disconnect failed for '
            '$integrationId: $e\n$st',
          );
        }),
      );
    }

    // Clear persisted state so the integration shows as Available after restart.
    unawaited(
      _saveConnectedState(integrationId, connected: false).catchError((
        Object e,
        StackTrace st,
      ) {
        Sentry.captureException(e, stackTrace: st);
        debugPrint(
          '[IntegrationsNotifier] Failed to clear persisted state for '
          '$integrationId: $e\n$st',
        );
      }),
    );
    state = state.copyWith(
      integrations: state.integrations.map((integration) {
        if (integration.id == integrationId) {
          return integration.copyWith(
            status: IntegrationStatus.available,
            clearLastSynced: true,
          );
        }
        return integration;
      }).toList(),
    );
  }

  /// Requests native health platform permissions (HealthKit / Health Connect).
  ///
  /// Returns:
  ///   `true` if the user granted permissions, `false` otherwise.
  Future<bool> requestHealthPermissions() async {
    return _healthRepository.requestAuthorization();
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Updates the [IntegrationStatus] for the integration with [id].
  void _setStatus(String id, IntegrationStatus status) {
    state = state.copyWith(
      integrations: state.integrations.map((integration) {
        if (integration.id == id) {
          return integration.copyWith(status: status);
        }
        return integration;
      }).toList(),
    );
  }

  /// Shows a brief [SnackBar] with the given [message].
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  static const String _connectedPrefix = 'integration_connected_';

  /// Persists the [connected] state of [integrationId] to SharedPreferences.
  ///
  /// Used to restore connected status across app restarts without re-requesting
  /// permissions — the platform (HealthKit/Health Connect) remembers the grant.
  ///
  /// Parameters:
  ///   integrationId: The [IntegrationModel.id] of the integration.
  ///   connected: Whether the integration is currently connected.
  Future<void> _saveConnectedState(
    String integrationId, {
    required bool connected,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_connectedPrefix$integrationId', connected);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// [StateNotifierProvider] for [IntegrationsNotifier].
///
/// Not auto-disposing — the integration list is kept alive for the lifetime
/// of the app session so that switching between tabs does not reset the list
/// or cause a blank flash while [loadIntegrations] runs again.
///
/// [loadIntegrations] is triggered automatically via [Future.microtask] on
/// first access, so consumers do not need to call it explicitly on first mount.
final integrationsProvider =
    StateNotifierProvider<IntegrationsNotifier, IntegrationsState>((ref) {
      final notifier = IntegrationsNotifier(
        oauthRepository: ref.watch(oauthRepositoryProvider),
        healthRepository: ref.watch(healthRepositoryProvider),
        healthSyncService: ref.watch(healthSyncServiceProvider),
        secureStorage: ref.read(secureStorageProvider),
        apiClient: ref.read(apiClientProvider),
        analyticsService: ref.read(analyticsServiceProvider),
      );
      // Kick off the initial load after the current frame so the provider is
      // fully initialised before any state mutation occurs.
      Future.microtask(() => notifier.loadIntegrations());
      return notifier;
    });
