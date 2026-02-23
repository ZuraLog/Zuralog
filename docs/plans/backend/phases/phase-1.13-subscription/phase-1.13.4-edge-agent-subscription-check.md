# Phase 1.13.4: Edge Agent Subscription Check

**Parent Goal:** Phase 1.13 Subscription & Monetization
**Checklist:**
- [x] 1.13.1 Subscription Models
- [x] 1.13.2 Tier Middleware
- [x] 1.13.3 RevenueCat Webhook Handler
- [x] 1.13.4 Edge Agent Subscription Check
- [ ] 1.13.5 Paywall UI in Harness

---

## What
Client-side logic to fetch the user's current subscription status from the backend (or RevenueCat SDK) and unlock UI features.

## Why
The UI needs to know whether to show the "Upgrade to Pro" banner or the "Premium Dashboard".

## How
Use `purchases_flutter` (RevenueCat SDK) for the actual purchase flow, but rely on Backend's user profile for the "Single Source of Truth" regarding access rights (to sync across devices).

## Features
- **State Management:** Riverpod provider `subscriptionProvider` exposes current tier.

## Files
- Create: `zuralog/lib/features/subscription/data/subscription_repository.dart`

## Steps

1. **Create repository (`zuralog/lib/features/subscription/data/subscription_repository.dart`)**

```dart
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionRepository {
  
  Future<void> init() async {
    await Purchases.configure(PurchasesConfiguration("public_api_key"));
  }
  
  Future<CustomerInfo> getCustomerInfo() async {
     return await Purchases.getCustomerInfo();
  }
  
  Future<void> purchasePro() async {
     // Mock purchase flow
     try {
       // await Purchases.purchasePackage(package);
     } catch (e) {
       // ...
     }
  }
}
```

## Exit Criteria
- SDK configured (with mock key).
