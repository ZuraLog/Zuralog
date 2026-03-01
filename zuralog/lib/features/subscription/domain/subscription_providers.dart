/// Zuralog Edge Agent — Subscription Riverpod Providers.
///
/// Exposes subscription state and repository as Riverpod providers
/// for consumption by UI widgets and other features.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/subscription/data/subscription_repository.dart';
import 'package:zuralog/features/subscription/domain/subscription_state.dart';

/// Provides the [SubscriptionRepository] singleton.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(apiClient: ref.watch(apiClientProvider));
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
  /// Links the authenticated Supabase user to RevenueCat (RC is configured
  /// anonymously at app startup), then fetches the authoritative tier.
  ///
  /// [appUserId] is the authenticated user's Supabase UID.
  Future<void> initialize(String appUserId) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.init(appUserId: appUserId);
      final status = await repo.fetchStatus();
      state = status;
      // Analytics: identify user with subscription tier (fire-and-forget).
      ref.read(analyticsServiceProvider).identify(
        userId: appUserId,
        properties: {'subscription_tier': status.tier.name},
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('[SubscriptionNotifier] initialize error: $e');
      state = const SubscriptionState(tier: SubscriptionTier.free);
    }
  }

  /// Log out the RevenueCat user on app sign-out.
  ///
  /// Reverts to anonymous RevenueCat session and resets local state to free.
  /// Call alongside Supabase sign-out.
  Future<void> logOut() async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.logOut();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('[SubscriptionNotifier] logOut error: $e');
    }
    state = const SubscriptionState(tier: SubscriptionTier.free);
  }

  /// Refresh subscription status from backend.
  ///
  /// Fetches the latest tier and updates local state. Useful after a purchase
  /// or returning from the paywall / Customer Center.
  ///
  /// Skips the backend call if the user is not authenticated (avoids 401).
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final authState = ref.read(authStateProvider);
      if (authState != AuthState.authenticated) {
        // Not logged in — skip backend, fall back to RC / free tier.
        try {
          final info = await repo.getCustomerInfo();
          state = repo.stateFromCustomerInfo(info);
        } catch (_) {
          state = const SubscriptionState(tier: SubscriptionTier.free);
        }
        return;
      }
      final status = await repo.fetchStatus();
      state = status;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      debugPrint('[SubscriptionNotifier] refresh error: $e');
      state = const SubscriptionState(tier: SubscriptionTier.free);
    }
  }

  /// Present the full RevenueCat Paywall and refresh state on purchase/restore.
  ///
  /// Returns [PaywallResult] so callers can react to the outcome.
  Future<PaywallResult> presentPaywall() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final result = await repo.presentPaywall();
    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      await refresh();
      // Analytics: capture tier from state after refresh. If refresh failed and
      // fell back to free, we still record it — the RevenueCat webhook on the
      // server side will be the authoritative source for plan tracking.
      final purchasedTier = state.tier;
      ref.read(analyticsServiceProvider).capture(
        event: 'subscription_started',
        properties: {'plan': purchasedTier.name},
      );
    }
    return result;
  }

  /// Present the paywall only if the user lacks the ZuraLog Pro entitlement.
  ///
  /// Returns [PaywallResult.notPresented] if already entitled.
  Future<PaywallResult> presentPaywallIfNeeded() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final result = await repo.presentPaywallIfNeeded();
    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      await refresh();
      // Analytics: see note in presentPaywall() about tier after refresh.
      final purchasedTier = state.tier;
      ref.read(analyticsServiceProvider).capture(
        event: 'subscription_started',
        properties: {'plan': purchasedTier.name},
      );
    }
    return result;
  }

  /// Present the RevenueCat Customer Center for subscription self-service.
  ///
  /// Refreshes state after the user returns in case they cancelled or changed
  /// their subscription from within the Customer Center.
  Future<void> presentCustomerCenter() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.presentCustomerCenter();
    await refresh();
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
