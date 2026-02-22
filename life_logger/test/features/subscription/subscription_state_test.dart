/// Life Logger Edge Agent — Subscription State Tests.
///
/// Validates the SubscriptionState model and SubscriptionTier enum.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:life_logger/features/subscription/domain/subscription_state.dart';

void main() {
  group('SubscriptionTier', () {
    test('free is not premium', () {
      expect(SubscriptionTier.free.isPremium, isFalse);
    });

    test('pro is premium', () {
      expect(SubscriptionTier.pro.isPremium, isTrue);
    });
  });

  group('SubscriptionState', () {
    test('default state is free and not loading', () {
      const state = SubscriptionState();
      expect(state.tier, SubscriptionTier.free);
      expect(state.isLoading, isFalse);
      expect(state.isPremium, isFalse);
      expect(state.expiresAt, isNull);
    });

    test('pro state is premium', () {
      const state = SubscriptionState(tier: SubscriptionTier.pro);
      expect(state.isPremium, isTrue);
    });

    test('loading state preserves tier', () {
      const state = SubscriptionState(tier: SubscriptionTier.pro);
      final loading = state.copyWith(isLoading: true);
      expect(loading.tier, SubscriptionTier.pro);
      expect(loading.isLoading, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final expires = DateTime(2026, 3, 1);
      final original = SubscriptionState(
        tier: SubscriptionTier.pro,
        expiresAt: expires,
        isLoading: false,
      );
      final copied = original.copyWith(isLoading: true);
      expect(copied.tier, SubscriptionTier.pro);
      expect(copied.expiresAt, expires);
      expect(copied.isLoading, isTrue);
    });

    test('copyWith clearExpiresAt resets expiration to null', () {
      final expires = DateTime(2026, 3, 1);
      final original = SubscriptionState(
        tier: SubscriptionTier.pro,
        expiresAt: expires,
      );
      final downgraded = original.copyWith(
        tier: SubscriptionTier.free,
        clearExpiresAt: true,
      );
      expect(downgraded.tier, SubscriptionTier.free);
      expect(downgraded.expiresAt, isNull);
      expect(downgraded.isPremium, isFalse);
    });
  });
}
