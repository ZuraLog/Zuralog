/// Zuralog — Integrations Domain Model.
///
/// Defines the [IntegrationStatus] enum and the immutable [IntegrationModel]
/// data class used throughout the Integrations Hub feature.
///
/// This layer has zero UI or platform dependencies — it is safe to import
/// from any layer (domain, presentation, data).
library;

/// Represents the connection state of a third-party integration.
///
/// - [connected]: The user has successfully authorised this integration.
/// - [available]: The integration is supported and ready to be connected.
/// - [comingSoon]: The integration is not yet implemented; shown as a teaser.
/// - [syncing]: An active sync / OAuth flow is in progress.
/// - [error]: The last sync or auth attempt resulted in an error.
enum IntegrationStatus {
  /// Integration is authorised and actively syncing.
  connected,

  /// Integration is supported but not yet connected by the user.
  available,

  /// Integration is listed as a future feature (non-interactive).
  comingSoon,

  /// An OAuth flow or background sync is currently in progress.
  syncing,

  /// The integration encountered an error on the last attempt.
  error,
}

/// Immutable data class representing a single third-party health integration.
///
/// Contains all metadata needed to render an [IntegrationTile] and drive
/// connect / disconnect logic in [IntegrationsNotifier].
///
/// Example:
/// ```dart
/// const strava = IntegrationModel(
///   id: 'strava',
///   name: 'Strava',
///   logoAsset: 'assets/integrations/strava.png',
///   status: IntegrationStatus.available,
///   description: 'Sync runs, rides, and workouts.',
/// );
/// ```
class IntegrationModel {
  /// Unique, stable identifier used to key connect / disconnect calls.
  final String id;

  /// Human-readable service name displayed in the tile.
  final String name;

  /// Asset path for the integration logo (SVG or PNG).
  ///
  /// Rendered with [Image.asset]; an initials fallback is shown if the
  /// asset cannot be loaded.
  final String logoAsset;

  /// Current connection / sync state of this integration.
  final IntegrationStatus status;

  /// Timestamp of the most recent successful data sync, or `null` if
  /// the integration has never synced.
  final DateTime? lastSynced;

  /// Short description shown below the integration name in the tile.
  final String description;

  /// Creates an immutable [IntegrationModel].
  const IntegrationModel({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.status,
    required this.description,
    this.lastSynced,
  });

  /// Returns a copy of this model with the specified fields replaced.
  ///
  /// All parameters are optional; unspecified fields retain their current value.
  IntegrationModel copyWith({
    String? id,
    String? name,
    String? logoAsset,
    IntegrationStatus? status,
    DateTime? lastSynced,
    bool clearLastSynced = false,
    String? description,
  }) {
    return IntegrationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoAsset: logoAsset ?? this.logoAsset,
      status: status ?? this.status,
      lastSynced: clearLastSynced ? null : (lastSynced ?? this.lastSynced),
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegrationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          lastSynced == other.lastSynced;

  @override
  int get hashCode => Object.hash(id, status, lastSynced);

  @override
  String toString() =>
      'IntegrationModel(id: $id, name: $name, status: $status)';
}
