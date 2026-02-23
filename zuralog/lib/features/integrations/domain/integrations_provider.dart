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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/health/data/health_repository.dart';
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
  IntegrationsNotifier({
    required OAuthRepository oauthRepository,
    required HealthRepository healthRepository,
  })  : _oauthRepository = oauthRepository,
        _healthRepository = healthRepository,
        super(const IntegrationsState());

  final OAuthRepository _oauthRepository;
  final HealthRepository _healthRepository;

  // ── Mock seed data ─────────────────────────────────────────────────────────

  /// Default integration list used by [loadIntegrations].
  ///
  /// Last two entries (Garmin, WHOOP) are marked [IntegrationStatus.comingSoon].
  static const List<IntegrationModel> _defaultIntegrations = [
    IntegrationModel(
      id: 'strava',
      name: 'Strava',
      logoAsset: 'assets/integrations/strava.png',
      status: IntegrationStatus.available,
      description: 'Sync runs, rides, and workouts automatically.',
    ),
    IntegrationModel(
      id: 'apple_health',
      name: 'Apple Health',
      logoAsset: 'assets/integrations/apple_health.png',
      status: IntegrationStatus.available,
      description: 'Read steps, sleep, and vitals from HealthKit.',
    ),
    IntegrationModel(
      id: 'fitbit',
      name: 'Fitbit',
      logoAsset: 'assets/integrations/fitbit.png',
      status: IntegrationStatus.available,
      description: 'Import daily activity, heart rate, and sleep.',
    ),
    IntegrationModel(
      id: 'google_fit',
      name: 'Google Fit',
      logoAsset: 'assets/integrations/google_fit.png',
      status: IntegrationStatus.available,
      description: 'Sync workouts and health data from Android.',
    ),
    IntegrationModel(
      id: 'garmin',
      name: 'Garmin',
      logoAsset: 'assets/integrations/garmin.png',
      status: IntegrationStatus.comingSoon,
      description: 'Connect your Garmin device for detailed metrics.',
    ),
    IntegrationModel(
      id: 'whoop',
      name: 'WHOOP',
      logoAsset: 'assets/integrations/whoop.png',
      status: IntegrationStatus.comingSoon,
      description: 'Strain, recovery, and sleep from your WHOOP strap.',
    ),
  ];

  // ── Public Actions ─────────────────────────────────────────────────────────

  /// Populates the integration list with default mock data.
  ///
  /// Preserves the [IntegrationStatus] of already-connected integrations
  /// so toggling the switch and then pulling to refresh does not reset state.
  void loadIntegrations() {
    final existing = {
      for (final i in state.integrations) i.id: i,
    };

    final merged = _defaultIntegrations.map((defaults) {
      final current = existing[defaults.id];
      if (current != null) {
        // Preserve live status; only refresh description / metadata.
        return defaults.copyWith(status: current.status);
      }
      return defaults;
    }).toList();

    state = state.copyWith(integrations: merged, clearError: true);
  }

  /// Connects the integration identified by [integrationId].
  ///
  /// For Strava, delegates to [OAuthRepository.getStravaAuthUrl].
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
          } else {
            _setStatus(integrationId, IntegrationStatus.available);
            _showSnackBar(context, 'Could not start Strava connection.');
          }
        case 'apple_health':
          final granted = await _healthRepository.requestAuthorization();
          _setStatus(
            integrationId,
            granted
                ? IntegrationStatus.connected
                : IntegrationStatus.available,
          );
        default:
          // Not yet implemented — show coming soon feedback.
          _setStatus(integrationId, IntegrationStatus.available);
          if (context.mounted) {
            _showSnackBar(context, 'Coming soon!');
          }
      }
    } catch (_) {
      _setStatus(integrationId, IntegrationStatus.error);
    }
  }

  /// Disconnects the integration identified by [integrationId].
  ///
  /// Sets the integration's status back to [IntegrationStatus.available]
  /// and clears [IntegrationModel.lastSynced].
  ///
  /// Parameters:
  ///   integrationId: The [IntegrationModel.id] of the service to disconnect.
  void disconnect(String integrationId) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Auto-disposing [StateNotifierProvider] for [IntegrationsNotifier].
///
/// Auto-disposes to free resources when the Integrations Hub screen
/// is removed from the widget tree.
final integrationsProvider =
    StateNotifierProvider.autoDispose<IntegrationsNotifier, IntegrationsState>(
  (ref) => IntegrationsNotifier(
    oauthRepository: ref.watch(oauthRepositoryProvider),
    healthRepository: ref.watch(healthRepositoryProvider),
  ),
);
