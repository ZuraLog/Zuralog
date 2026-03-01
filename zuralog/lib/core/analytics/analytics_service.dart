/// Zuralog Analytics Service — PostHog Integration.
///
/// Riverpod-based analytics service wrapping the [posthog_flutter] SDK.
/// Provides event tracking, user identification, feature flag evaluation,
/// and screen tracking for the mobile app.
///
/// All PostHog calls are fire-and-forget — errors are caught and logged.
/// Analytics must never break app functionality.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Singleton provider for the analytics service.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

class AnalyticsService {
  /// The PostHog SDK instance.
  Posthog get _posthog => Posthog();

  /// Whether analytics is enabled.
  /// Disabled in debug mode by default; can be overridden via --dart-define.
  bool get enabled =>
      !kDebugMode ||
      const bool.fromEnvironment('ENABLE_ANALYTICS', defaultValue: false);

  // ---------------------------------------------------------------------------
  // Event Capture
  // ---------------------------------------------------------------------------

  /// Capture a custom analytics event.
  ///
  /// [event] — Event name (e.g., 'health_sync_completed').
  /// [properties] — Optional properties map.
  Future<void> capture({
    required String event,
    Map<String, dynamic>? properties,
  }) async {
    if (!enabled) return;
    try {
      await _posthog.capture(
        eventName: event,
        properties: properties?.cast<String, Object>() ?? {},
      );
    } catch (e) {
      debugPrint('PostHog capture failed: $event — $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Screen Tracking
  // ---------------------------------------------------------------------------

  /// Track a screen view.
  ///
  /// Called automatically by [PostHogNavigatorObserver] for GoRouter
  /// navigations, but can also be called manually.
  Future<void> screen({
    required String screenName,
    Map<String, dynamic>? properties,
  }) async {
    if (!enabled) return;
    try {
      await _posthog.screen(
        screenName: screenName,
        properties: properties?.cast<String, Object>() ?? {},
      );
    } catch (e) {
      debugPrint('PostHog screen failed: $screenName — $e');
    }
  }

  // ---------------------------------------------------------------------------
  // User Identification
  // ---------------------------------------------------------------------------

  /// Identify the current user with properties.
  ///
  /// Call after login/signup. Sets persistent user properties in PostHog
  /// for segmentation and cohort analysis.
  ///
  /// [userId] — The user's Supabase UID.
  /// [properties] — User properties (subscription_tier, platform, etc.).
  Future<void> identify({
    required String userId,
    Map<String, dynamic>? properties,
  }) async {
    if (!enabled) return;
    try {
      await _posthog.identify(
        userId: userId,
        userProperties: properties?.cast<String, Object>() ?? {},
      );
    } catch (e) {
      debugPrint('PostHog identify failed: $userId — $e');
    }
  }

  /// Reset the user identity (call on logout).
  ///
  /// Generates a new anonymous distinct_id so post-logout events
  /// are not attributed to the previous user.
  Future<void> reset() async {
    if (!enabled) return;
    try {
      await _posthog.reset();
    } catch (e) {
      debugPrint('PostHog reset failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Super Properties
  // ---------------------------------------------------------------------------

  /// Register super properties that are sent with every event.
  ///
  /// Use for properties that rarely change: platform, app_version,
  /// build_number. Call once at app startup after initialization.
  Future<void> registerSuperProperties(Map<String, dynamic> properties) async {
    if (!enabled) return;
    try {
      for (final entry in properties.entries) {
        if (entry.value != null) {
          await _posthog.register(entry.key, entry.value as Object);
        }
      }
    } catch (e) {
      debugPrint('PostHog register failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Feature Flags
  // ---------------------------------------------------------------------------

  /// Check if a feature flag is enabled for the current user.
  ///
  /// Returns [defaultValue] if evaluation fails or analytics is disabled.
  Future<bool> isFeatureEnabled(
    String flagKey, {
    bool defaultValue = false,
  }) async {
    if (!enabled) return defaultValue;
    try {
      final result = await _posthog.isFeatureEnabled(flagKey);
      return result ?? defaultValue;
    } catch (e) {
      debugPrint('PostHog feature flag failed: $flagKey — $e');
      return defaultValue;
    }
  }

  /// Get the payload of a feature flag (for multivariate flags).
  ///
  /// Returns null if the flag doesn't exist or evaluation fails.
  Future<dynamic> getFeatureFlagPayload(String flagKey) async {
    if (!enabled) return null;
    try {
      return await _posthog.getFeatureFlagPayload(flagKey);
    } catch (e) {
      debugPrint('PostHog flag payload failed: $flagKey — $e');
      return null;
    }
  }

  /// Force reload all feature flags from PostHog.
  ///
  /// Call after user login/identify to get user-specific flag values.
  Future<void> reloadFeatureFlags() async {
    if (!enabled) return;
    try {
      await _posthog.reloadFeatureFlags();
    } catch (e) {
      debugPrint('PostHog reloadFeatureFlags failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Group Analytics
  // ---------------------------------------------------------------------------

  /// Associate the current user with a group.
  ///
  /// Used for subscription tier grouping (e.g., 'free', 'pro', 'premium').
  Future<void> group({
    required String groupType,
    required String groupKey,
    Map<String, dynamic>? groupProperties,
  }) async {
    if (!enabled) return;
    try {
      await _posthog.group(
        groupType: groupType,
        groupKey: groupKey,
        groupProperties: groupProperties?.cast<String, Object>() ?? {},
      );
    } catch (e) {
      debugPrint('PostHog group failed: $groupType/$groupKey — $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle Helpers
  // ---------------------------------------------------------------------------

  /// Request a flush of any pending events.
  ///
  /// Call on app backgrounding to ensure all events are sent.
  Future<void> flush() async {
    if (!enabled) return;
    try {
      // posthog_flutter auto-flushes on app lifecycle changes via native SDK.
      // This method exists as a hook for explicit flush requests.
      debugPrint('PostHog flush requested');
    } catch (e) {
      debugPrint('PostHog flush failed: $e');
    }
  }
}
