# Phase 1.13.5: Paywall UI in Harness

**Parent Goal:** Phase 1.13 Subscription & Monetization
**Checklist:**
- [x] 1.13.1 Subscription Models
- [x] 1.13.2 Tier Middleware
- [x] 1.13.3 RevenueCat Webhook Handler
- [x] 1.13.4 Edge Agent Subscription Check
- [x] 1.13.5 Paywall UI in Harness

---

## What
Add a test button to the Developer Harness to simulate opening a Paywall and "Buying" the pro plan.

## Why
Verify the purchase flow UI triggers and the backend/state updates after a successful mock purchase.

## How
Add "Buy Pro" button in `HarnessScreen`.

## Features
- **Mock Success:** Since we are in sandbox/test mode, we simulate a successful transaction.

## Files
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

## Steps

1. **Add test controls (`life_logger/lib/features/harness/harness_screen.dart`)**

```dart
ElevatedButton(
  onPressed: () async {
    // Show current entitlement
    try {
        final info = await Purchases.getCustomerInfo();
        _outputController.text = "Active Entitlements: ${info.entitlements.active}";
    } catch(e) {
        _outputController.text = "Error: $e";
    }
  },
  child: const Text('Check Entitlements'),
),
```

## Exit Criteria
- Button calls RevenueCat SDK.
