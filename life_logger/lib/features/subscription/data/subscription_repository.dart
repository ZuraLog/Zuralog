/// Life Logger Edge Agent — Subscription Repository.
///
/// Manages the RevenueCat SDK for in-app purchases and subscription
/// status. The backend's user profile is the Single Source of Truth
/// for access rights; this repository handles the purchase flow
/// and local entitlement checks.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'package:life_logger/core/network/api_client.dart';
import 'package:life_logger/features/subscription/domain/subscription_state.dart';

/// The RevenueCat entitlement identifier for ZuraLog Pro.
const kProEntitlementId = 'ZuraLog Pro';

/// Repository for managing subscription purchases and status.
///
/// Wraps the RevenueCat `purchases_flutter` and `purchases_ui_flutter` SDKs
/// to handle initialization, user linking, entitlement checks, purchase flows,
/// paywall presentation, and Customer Center access.
/// The backend `/users/me/preferences` endpoint remains the
/// authoritative source for server-side tier enforcement.
class SubscriptionRepository {
  /// Creates a [SubscriptionRepository].
  ///
  /// [apiClient] is used to sync subscription status with the backend.
  SubscriptionRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Link the authenticated user to RevenueCat after login.
  ///
  /// RC is configured anonymously at app startup in main.dart. This method
  /// calls [Purchases.logIn] to associate all purchases with the Supabase
  /// Auth UID. Safe to call multiple times — RC deduplicates logIn calls.
  ///
  /// [appUserId] should be the Supabase Auth UID.
  Future<void> init({required String appUserId}) async {
    await Purchases.logIn(appUserId);
  }

  /// Switch the RevenueCat identity to a newly authenticated user.
  ///
  /// Calls `Purchases.logIn` so that any purchases are attributed to
  /// [appUserId] rather than an anonymous RevenueCat user. Must be called
  /// after RC is configured in main.dart.
  Future<void> logIn(String appUserId) async {
    await Purchases.logIn(appUserId);
  }

  /// Remove the RevenueCat user identity on sign-out.
  ///
  /// Reverts to an anonymous RevenueCat session. Call alongside
  /// Supabase sign-out to ensure purchases are not shared across accounts.
  Future<void> logOut() async {
    await Purchases.logOut();
  }

  /// Fetch the current subscription state from the backend.
  ///
  /// Calls `/users/me/preferences` to get the authoritative tier.
  /// Falls back to a local RevenueCat entitlement check, then to free
  /// tier if both sources are unavailable.
  ///
  /// Returns a [SubscriptionState] reflecting the most current status.
  Future<SubscriptionState> fetchStatus() async {
    try {
      final response = await _apiClient.get('/api/v1/users/me/preferences');
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        debugPrint(
          '[SubscriptionRepository] fetchStatus: unexpected response type '
          '${raw.runtimeType}, falling back to RC check',
        );
        throw FormatException('Unexpected response type: ${raw.runtimeType}');
      }
      final tierStr = raw['subscription_tier'] as String? ?? 'free';
      final tier = tierStr == 'pro'
          ? SubscriptionTier.pro
          : SubscriptionTier.free;
      return SubscriptionState(tier: tier);
    } catch (e) {
      // 401 = unauthenticated (expired/missing token) — expected, no log needed.
      // Other errors = backend unavailable — log for diagnostics.
      if (e is! DioException || e.response?.statusCode != 401) {
        debugPrint('[SubscriptionRepository] fetchStatus backend error: $e');
      }
      // Backend unavailable — fall back to local RC entitlement check.
      try {
        final info = await Purchases.getCustomerInfo();
        return stateFromCustomerInfo(info);
      } catch (e2) {
        debugPrint('[SubscriptionRepository] RC getCustomerInfo error: $e2');
        return const SubscriptionState(tier: SubscriptionTier.free);
      }
    }
  }

  /// Fetch available subscription offerings from RevenueCat.
  ///
  /// Returns the [Offerings] object containing all configured
  /// products and packages. Returns null if unavailable or RC not configured.
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[SubscriptionRepository] getOfferings error: $e');
      return null;
    }
  }

  /// Attempt to purchase a subscription package.
  ///
  /// [package] is the RevenueCat [Package] to purchase (monthly/yearly/lifetime).
  ///
  /// Returns the updated [CustomerInfo] after a successful purchase.
  /// Throws [PlatformException] on purchase failure or user cancellation.
  Future<CustomerInfo> purchasePackage(Package package) async {
    return Purchases.purchasePackage(package);
  }

  /// Check local RevenueCat entitlement status.
  ///
  /// Returns the [CustomerInfo] with active entitlement map.
  /// This is a cached/local check — use [fetchStatus] for authoritative data.
  Future<CustomerInfo> getCustomerInfo() async {
    return Purchases.getCustomerInfo();
  }

  /// Restore previous purchases (for device transfer or reinstall).
  ///
  /// Returns the restored [CustomerInfo] with any re-activated entitlements.
  Future<CustomerInfo> restorePurchases() async {
    return Purchases.restorePurchases();
  }

  /// Present the full RevenueCat Paywall for the current offering.
  ///
  /// Uses the RevenueCat-configured paywall template. Returns a
  /// [PaywallResult] indicating whether the user purchased, restored,
  /// cancelled, or if an error occurred. RevenueCat handles navigation
  /// internally — no BuildContext needed.
  Future<PaywallResult> presentPaywall() async {
    return RevenueCatUI.presentPaywall();
  }

  /// Present the paywall only if the user lacks the ZuraLog Pro entitlement.
  ///
  /// [kProEntitlementId] is passed as a positional argument per the SDK API.
  /// Returns [PaywallResult.notPresented] if the user is already entitled.
  Future<PaywallResult> presentPaywallIfNeeded() async {
    return RevenueCatUI.presentPaywallIfNeeded(kProEntitlementId);
  }

  /// Present the RevenueCat Customer Center for subscription self-service.
  ///
  /// Allows users to manage, cancel, or get support for their active
  /// subscription without leaving the app.
  Future<void> presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter();
  }

  /// Derive a [SubscriptionState] from RevenueCat [CustomerInfo].
  ///
  /// Uses the [kProEntitlementId] entitlement as the source of truth for
  /// local checks. The expiration date is parsed from RevenueCat's ISO-8601
  /// string. Returns free tier if the entitlement is not active.
  SubscriptionState stateFromCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.active[kProEntitlementId];
    if (entitlement == null) {
      return const SubscriptionState(tier: SubscriptionTier.free);
    }
    final expiresAt = entitlement.expirationDate != null
        ? DateTime.tryParse(entitlement.expirationDate!)
        : null;
    if (entitlement.expirationDate != null && expiresAt == null) {
      debugPrint(
        '[SubscriptionRepository] stateFromCustomerInfo: could not parse '
        'expirationDate "${entitlement.expirationDate}"',
      );
    }
    return SubscriptionState(tier: SubscriptionTier.pro, expiresAt: expiresAt);
  }
}
