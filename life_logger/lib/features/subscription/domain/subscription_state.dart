/// Life Logger Edge Agent — Subscription State.
///
/// Defines the subscription tier and state model used across
/// the application to gate features and display upgrade prompts.
library;

/// Represents the user's current subscription tier.
enum SubscriptionTier {
  /// Free tier with basic features and limited API calls.
  free,

  /// Pro tier with unlimited chat, voice, and cross-app reasoning.
  pro;

  /// Whether this tier grants premium access.
  bool get isPremium => this != SubscriptionTier.free;
}

/// Immutable snapshot of the user's subscription status.
class SubscriptionState {
  /// Creates a new [SubscriptionState].
  ///
  /// [tier] is the current subscription level.
  /// [expiresAt] is when the current billing period ends (null for free).
  /// [isLoading] indicates whether the state is being fetched.
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.expiresAt,
    this.isLoading = false,
  });

  /// The user's current subscription tier.
  final SubscriptionTier tier;

  /// When the current subscription period expires.
  /// Null for free-tier users.
  final DateTime? expiresAt;

  /// Whether the subscription state is currently being loaded.
  final bool isLoading;

  /// Whether the user has premium (Pro) access.
  bool get isPremium => tier.isPremium;

  /// Creates a copy of this state with the given fields replaced.
  ///
  /// Any parameter that is null retains the original value.
  ///
  /// Returns a new [SubscriptionState] with the replaced fields.
  SubscriptionState copyWith({
    SubscriptionTier? tier,
    DateTime? expiresAt,
    bool? isLoading,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      expiresAt: expiresAt ?? this.expiresAt,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
