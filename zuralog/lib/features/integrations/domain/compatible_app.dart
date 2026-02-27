/// Zuralog — Compatible App Data Model.
///
/// Represents a third-party health/fitness app that syncs indirectly
/// with Zuralog through Apple HealthKit and/or Google Health Connect.
///
/// Unlike [IntegrationModel] (which represents direct, first-party
/// integrations with OAuth/API connections), [CompatibleApp] entries are
/// informational — they show the user which external apps feed data into
/// the health stores that Zuralog already reads.
library;

/// Immutable data class for a compatible third-party health/fitness app.
///
/// Used to populate the "Compatible Apps" collapsible section in the
/// Integrations Hub screen.
class CompatibleApp {
  /// Unique identifier (snake_case, e.g. `'myfitnesspal'`).
  final String id;

  /// Human-readable display name.
  final String name;

  /// Whether this app writes data to Apple HealthKit.
  final bool supportsHealthKit;

  /// Whether this app writes data to Google Health Connect.
  final bool supportsHealthConnect;

  /// The ARGB hex integer for this app's brand color (e.g. `0xFF0070D1`).
  final int brandColor;

  /// Short description shown in the tile (max ~60 chars).
  final String description;

  /// Explains how data flows from this app → health store → Zuralog.
  /// Shown in the info bottom sheet.
  final String dataFlowExplanation;

  /// Optional slug for the `simple_icons` package (e.g. `'nike'`).
  /// When `null`, falls back to initials with [brandColor].
  final String? simpleIconSlug;

  /// Optional deep link URL scheme to open this app directly.
  final String? deepLinkUrl;

  /// Optional App Store / Play Store URL for this app.
  final String? storeUrl;

  /// Creates an immutable [CompatibleApp].
  const CompatibleApp({
    required this.id,
    required this.name,
    required this.supportsHealthKit,
    required this.supportsHealthConnect,
    required this.brandColor,
    required this.description,
    required this.dataFlowExplanation,
    this.simpleIconSlug,
    this.deepLinkUrl,
    this.storeUrl,
  });

  /// Returns `true` when this app syncs with both HealthKit and Health Connect.
  bool get supportsBothPlatforms =>
      supportsHealthKit && supportsHealthConnect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompatibleApp &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          supportsHealthKit == other.supportsHealthKit &&
          supportsHealthConnect == other.supportsHealthConnect &&
          brandColor == other.brandColor &&
          description == other.description &&
          dataFlowExplanation == other.dataFlowExplanation &&
          simpleIconSlug == other.simpleIconSlug &&
          deepLinkUrl == other.deepLinkUrl &&
          storeUrl == other.storeUrl;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        supportsHealthKit,
        supportsHealthConnect,
        brandColor,
        description,
        dataFlowExplanation,
        simpleIconSlug,
        deepLinkUrl,
        storeUrl,
      );

  @override
  String toString() => 'CompatibleApp(id: $id, name: $name)';
}
