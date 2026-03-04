/// Zuralog Feature Flag Service — PostHog A/B Testing.
///
/// Provides typed access to PostHog feature flags for A/B testing readiness.
/// All flag evaluation is safe-by-default: if PostHog is unreachable or
/// analytics is disabled, the [defaultValue] is returned so the app always
/// has a valid state.
///
/// ## Available flags
///
/// | Flag key                         | Type        | Values                                    |
/// |----------------------------------|-------------|-------------------------------------------|
/// | `onboarding_step_order`          | string      | `'goals_first'` (default) / `'persona_first'` |
/// | `notification_frequency_default` | string      | `'low'` / `'medium'` (default) / `'high'` |
/// | `ai_persona_default`             | string      | `'toughLove'` / `'balanced'` (default) / `'gentle'` |
///
/// ## Usage
///
/// ```dart
/// final order = await ref.read(featureFlagServiceProvider)
///     .onboardingStepOrder();
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';

/// Riverpod provider for the [FeatureFlagService].
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService(ref.read(analyticsServiceProvider));
});

// ---------------------------------------------------------------------------
// Flag key constants
// ---------------------------------------------------------------------------

/// Typed constants for all PostHog feature flag keys used by Zuralog.
abstract final class FeatureFlags {
  /// Controls onboarding step order.
  ///
  /// Payload: `'goals_first'` (default) | `'persona_first'`
  ///
  /// - `'goals_first'`: Goals (step 2) → Persona (step 3) — current default
  /// - `'persona_first'`: Persona (step 2) → Goals (step 3)
  static const String onboardingStepOrder = 'onboarding_step_order';

  /// Controls the default reminder frequency shown to new users in
  /// Settings > Notifications.
  ///
  /// Payload: `'low'` | `'medium'` (default) | `'high'`
  static const String notificationFrequencyDefault =
      'notification_frequency_default';

  /// Controls the default AI persona pre-selected in
  /// Settings > Coach and in the onboarding Persona step.
  ///
  /// Payload: `'toughLove'` | `'balanced'` (default) | `'gentle'`
  static const String aiPersonaDefault = 'ai_persona_default';
}

// ---------------------------------------------------------------------------
// FeatureFlagService
// ---------------------------------------------------------------------------

/// Typed wrapper around [AnalyticsService] for feature flag evaluation.
///
/// All methods are async and return safe defaults on failure so callers
/// never need to handle null or exceptions.
class FeatureFlagService {
  /// Creates a [FeatureFlagService] backed by [_analytics].
  const FeatureFlagService(this._analytics);

  final AnalyticsService _analytics;

  // ── Onboarding Step Order ─────────────────────────────────────────────────

  /// Returns the onboarding step order variant for this user.
  ///
  /// Default: `'goals_first'`.
  Future<String> onboardingStepOrder() async {
    final payload = await _analytics.getFeatureFlagPayload(
      FeatureFlags.onboardingStepOrder,
    );
    if (payload is String &&
        (payload == 'goals_first' || payload == 'persona_first')) {
      return payload;
    }
    return 'goals_first';
  }

  // ── Notification Frequency Default ────────────────────────────────────────

  /// Returns the default reminder frequency (1, 2, or 3 per day) to use
  /// when initialising the Notification Settings screen state.
  ///
  /// Default: `2` (medium).
  Future<int> notificationFrequencyDefault() async {
    final payload = await _analytics.getFeatureFlagPayload(
      FeatureFlags.notificationFrequencyDefault,
    );
    if (payload is String) {
      return switch (payload) {
        'low' => 1,
        'medium' => 2,
        'high' => 3,
        _ => 2,
      };
    }
    return 2;
  }

  // ── AI Persona Default ────────────────────────────────────────────────────

  /// Returns the default AI persona key to pre-select in Coach Settings
  /// and in the onboarding Persona step.
  ///
  /// Default: `'balanced'`.
  Future<String> aiPersonaDefault() async {
    final payload = await _analytics.getFeatureFlagPayload(
      FeatureFlags.aiPersonaDefault,
    );
    if (payload is String &&
        (payload == 'toughLove' ||
            payload == 'balanced' ||
            payload == 'gentle')) {
      return payload;
    }
    return 'balanced';
  }
}
