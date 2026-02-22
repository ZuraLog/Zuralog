/// Life Logger Edge Agent — Subscription Riverpod Providers.
///
/// Exposes subscription state and repository as Riverpod providers
/// for consumption by UI widgets and other features.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_logger/core/di/providers.dart';
import 'package:life_logger/features/subscription/data/subscription_repository.dart';
import 'package:life_logger/features/subscription/domain/subscription_state.dart';

/// The RevenueCat public API key, injected at build time.
///
/// Pass via: `flutter run --dart-define=REVENUECAT_API_KEY=your_key`
/// In production, this should come from a build config or CI secret.
const _kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: '',
);

/// Provides the [SubscriptionRepository] singleton.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(
    apiClient: ref.watch(apiClientProvider),
    revenueCatApiKey: _kRevenueCatApiKey,
  );
});

/// Notifier that manages subscription state.
///
/// Fetches the authoritative subscription status from the backend
/// and exposes it as a reactive [SubscriptionState].
class SubscriptionNotifier extends Notifier<SubscriptionState> {
  /// Builds the initial subscription state.
  ///
  /// Returns a loading state; call [initialize] after auth completes.
  @override
  SubscriptionState build() {
    return const SubscriptionState(isLoading: true);
  }

  /// Initialize RevenueCat and fetch current status.
  ///
  /// [appUserId] is the authenticated user's Supabase UID.
  ///
  /// Updates state to reflect the backend's subscription tier.
  Future<void> initialize(String appUserId) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.init(appUserId: appUserId);
      final status = await repo.fetchStatus();
      state = status;
    } catch (_) {
      state = const SubscriptionState(tier: SubscriptionTier.free);
    }
  }

  /// Refresh subscription status from backend.
  ///
  /// Fetches the latest tier from the server and updates local state.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final status = await repo.fetchStatus();
      state = status;
    } catch (_) {
      state = const SubscriptionState(tier: SubscriptionTier.free);
    }
  }
}

/// Provides reactive subscription state across the app.
final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

/// Convenience provider: whether the current user has Pro access.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isPremium;
});
