/// Zuralog — Integrations Domain Model.
///
/// Defines the [IntegrationStatus] enum, [PlatformCompatibility] enum,
/// and the immutable [IntegrationModel] data class used throughout the
/// Integrations Hub feature.
///
/// Imports [dart:io] for [Platform] checks and [flutter/foundation.dart] for
/// the [kIsWeb] guard — both are safe for mobile-first builds.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Describes which mobile platform an integration is compatible with.
///
/// Used to visually dim incompatible tiles and show an incompatibility badge
/// instead of the Connect button on unsupported platforms.
///
/// - [all]: The integration is supported on both iOS and Android.
/// - [iosOnly]: The integration requires iOS / HealthKit (e.g. Apple Health).
/// - [androidOnly]: The integration requires Android / Health Connect.
enum PlatformCompatibility {
  /// Available on all platforms.
  all,

  /// Available on iOS only (e.g. Apple Health via HealthKit).
  iosOnly,

  /// Available on Android only (e.g. Google Health Connect).
  androidOnly,
}

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

  /// Which platform(s) this integration supports.
  ///
  /// Defaults to [PlatformCompatibility.all] when not specified.
  final PlatformCompatibility compatibility;

  /// Creates an immutable [IntegrationModel].
  const IntegrationModel({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.status,
    required this.description,
    this.lastSynced,
    this.compatibility = PlatformCompatibility.all,
  });

  // ── Computed Properties ───────────────────────────────────────────────────

  /// Returns `true` if this integration is usable on the current platform.
  ///
  /// Always returns `true` on web (where [Platform] is unavailable) so the UI
  /// degrades gracefully in a web debug environment.
  ///
  /// Returns:
  ///   `true` when [compatibility] is [PlatformCompatibility.all], or when the
  ///   platform matches the required OS. `false` otherwise.
  bool get isCompatibleWithCurrentPlatform {
    if (kIsWeb) return true;
    if (compatibility == PlatformCompatibility.all) return true;
    if (compatibility == PlatformCompatibility.iosOnly) return Platform.isIOS;
    if (compatibility == PlatformCompatibility.androidOnly) {
      return Platform.isAndroid;
    }
    return true;
  }

  /// Returns a human-readable incompatibility note, or `null` if compatible.
  ///
  /// Examples: `'iOS only'`, `'Android only'`.
  ///
  /// Returns:
  ///   A short platform label string when [isCompatibleWithCurrentPlatform] is
  ///   `false`; `null` when the integration is compatible.
  String? get incompatibilityNote {
    if (isCompatibleWithCurrentPlatform) return null;
    if (compatibility == PlatformCompatibility.iosOnly) return 'iOS only';
    if (compatibility == PlatformCompatibility.androidOnly) {
      return 'Android only';
    }
    return null;
  }

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
    PlatformCompatibility? compatibility,
  }) {
    return IntegrationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoAsset: logoAsset ?? this.logoAsset,
      status: status ?? this.status,
      lastSynced: clearLastSynced ? null : (lastSynced ?? this.lastSynced),
      description: description ?? this.description,
      compatibility: compatibility ?? this.compatibility,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegrationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          lastSynced == other.lastSynced &&
          compatibility == other.compatibility;

  @override
  int get hashCode => Object.hash(id, status, lastSynced, compatibility);

  @override
  String toString() =>
      'IntegrationModel(id: $id, name: $name, status: $status)';
}
