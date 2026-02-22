/// Life Logger Edge Agent — Subscription Repository.
///
/// Manages the RevenueCat SDK for in-app purchases and subscription
/// status. The backend's user profile is the Single Source of Truth
/// for access rights; this repository handles the purchase flow
/// and local entitlement checks.
library;

import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:life_logger/core/network/api_client.dart';
import 'package:life_logger/features/subscription/domain/subscription_state.dart';

/// Repository for managing subscription purchases and status.
///
/// Wraps the RevenueCat `purchases_flutter` SDK to handle
/// initialization, entitlement checks, and purchase flows.
/// The backend `/users/me/preferences` endpoint remains the
/// authoritative source for tier enforcement.
class SubscriptionRepository {
  /// Creates a [SubscriptionRepository].
  ///
  /// [apiClient] is used to sync subscription status with the backend.
  /// [revenueCatApiKey] is the RevenueCat public API key.
  SubscriptionRepository({
    required ApiClient apiClient,
    required String revenueCatApiKey,
  })  : _apiClient = apiClient,
        _revenueCatApiKey = revenueCatApiKey;

  final ApiClient _apiClient;
  final String _revenueCatApiKey;
  bool _initialized = false;

  /// Initialize the RevenueCat SDK.
  ///
  /// Must be called once before any purchase or entitlement operations.
  /// Typically called during app startup after authentication.
  ///
  /// [appUserId] should be the Supabase Auth UID so RevenueCat
  /// can link purchases to our backend user.
  ///
  /// Throws [Exception] if configuration fails.
  Future<void> init({required String appUserId}) async {
    if (_initialized) return;

    await Purchases.configure(
      PurchasesConfiguration(_revenueCatApiKey)..appUserID = appUserId,
    );
    _initialized = true;
  }

  /// Fetch the current subscription state from the backend.
  ///
  /// Calls `/users/me/preferences` to get the authoritative tier.
  /// Falls back to free tier on error.
  ///
  /// Returns a [SubscriptionState] reflecting the backend's view.
  Future<SubscriptionState> fetchStatus() async {
    try {
      final response = await _apiClient.get('/users/me/preferences');
      final data = response.data as Map<String, dynamic>;
      final tierStr = data['subscription_tier'] as String? ?? 'free';
      final tier =
          tierStr == 'pro' ? SubscriptionTier.pro : SubscriptionTier.free;
      return SubscriptionState(tier: tier);
    } catch (_) {
      return const SubscriptionState(tier: SubscriptionTier.free);
    }
  }

  /// Fetch available subscription offerings from RevenueCat.
  ///
  /// Returns the [Offerings] object containing all configured
  /// products and packages. Returns null if unavailable.
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Attempt to purchase a subscription package.
  ///
  /// [package] is the RevenueCat Package to purchase.
  ///
  /// Returns the [CustomerInfo] after a successful purchase.
  ///
  /// Throws [PlatformException] on purchase failure.
  Future<CustomerInfo> purchasePackage(Package package) async {
    return await Purchases.purchasePackage(package);
  }

  /// Check local RevenueCat entitlement status.
  ///
  /// Returns the [CustomerInfo] with active entitlements.
  /// This is a cached/local check, not necessarily a network call.
  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  /// Restore previous purchases (for device transfer / reinstall).
  ///
  /// Returns the restored [CustomerInfo].
  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }
}
