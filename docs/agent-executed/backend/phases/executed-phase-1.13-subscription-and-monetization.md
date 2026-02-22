# Executed Phase 1.13: Subscription & Monetization

> **Branch:** `feat/phase-1.13`
> **Date:** 2026-02-22
> **Status:** Complete (pending merge to main)

---

## Summary

Implemented a 2-tier (Free / Pro) subscription system using RevenueCat, spanning both Cloud Brain (Python/FastAPI) and Edge Agent (Flutter/Dart). The system includes database model extensions, shared authentication dependencies, tier-based access control middleware, a RevenueCat webhook handler for real-time subscription sync, a Flutter subscription repository with Riverpod state management, and a developer harness test section.

## What Was Built

### Cloud Brain (Backend)

- **User Model Extensions** (`app/models/user.py`) — Replaced `is_premium: Mapped[bool]` column with:
  - `SubscriptionTier` enum (FREE/PRO with `.rank` property for comparison)
  - `subscription_tier: Mapped[str]` column (default "free")
  - `subscription_expires_at: Mapped[DateTime]` column (nullable, timezone-aware)
  - `revenuecat_customer_id: Mapped[str]` column (nullable, indexed for webhook lookups)
  - `is_premium` retained as a `@property` for backward compatibility

- **Shared Auth Dependency** (`app/api/deps.py`) — New `get_current_user()` FastAPI dependency that validates Bearer tokens via Supabase Auth and returns the User ORM instance. Eliminates code duplication across all route files that previously had their own auth patterns.

- **Tier Middleware** (`app/api/deps.py`) — `require_tier(min_tier)` dependency factory that chains on `get_current_user()` to gate endpoints by subscription tier. Uses `SubscriptionTier.rank` for hierarchical comparison.

- **Subscription Service** (`app/services/subscription_service.py`) — Processes RevenueCat webhook events: INITIAL_PURCHASE, RENEWAL, UNCANCELLATION, PRODUCT_CHANGE upgrade to Pro; EXPIRATION, BILLING_ISSUE downgrade to Free; CANCELLATION logs intent but maintains access.

- **Webhook Handler** (`app/api/v1/webhooks.py`) — `POST /webhooks/revenuecat` endpoint with shared-secret Authorization header validation, event payload parsing, and delegation to SubscriptionService.

- **Config Updates** (`app/config.py`) — Added `revenuecat_webhook_secret` and `revenuecat_api_key` settings from environment variables.

- **30 new backend tests** across 5 test files (subscription fields: 12, get_current_user: 3, tier middleware: 5, subscription service: 7, webhook handler: 3).

### Edge Agent (Flutter)

- **Subscription State Model** (`features/subscription/domain/subscription_state.dart`) — `SubscriptionTier` enum and immutable `SubscriptionState` class with `copyWith`, `isPremium`.

- **Subscription Repository** (`features/subscription/data/subscription_repository.dart`) — Wraps RevenueCat `purchases_flutter` SDK for initialization, purchase flows, entitlement checks, and restore. Fetches authoritative tier from backend `/users/me/preferences`.

- **Riverpod Providers** (`features/subscription/domain/subscription_providers.dart`) — `subscriptionRepositoryProvider`, `SubscriptionNotifier` with `initialize()` and `refresh()`, `subscriptionProvider`, `isPremiumProvider`.

- **Harness Test Section** — 4 buttons: Check Status (backend), Entitlements (RevenueCat), View Offerings, Restore Purchases.

- **6 new Flutter unit tests** for subscription state model.

---

## Deviations from Original Phase 1.13 Plan

| # | Original Plan | What We Did | Reason |
|---|---|---|---|
| 1 | 3 tiers: free/pro/unlimited | **2 tiers: free/pro** | PRD specifies Free + Pro only. YAGNI. Tier hierarchy extensible for future. |
| 2 | `is_premium` kept as DB column | **`is_premium` → `@property`** on User model | Eliminates state inconsistency between boolean and tier string. Backward compatible. |
| 3 | No shared `get_current_user` dependency | **Created `get_current_user()`** in deps.py | Reduces duplication across all route files. Required for `require_tier()` chaining. |
| 4 | RevenueCat webhook logic in route handler | **Extracted `SubscriptionService`** class | Separation of concerns: business logic testable independently from HTTP plumbing. |
| 5 | RevenueCat API key hardcoded as `"public_api_key"` | **`String.fromEnvironment('REVENUECAT_API_KEY')`** | AGENTS.md Rule 11: No hardcoded secrets. |
| 6 | `user_profile_service.py` queries `is_premium` | **Updated to query `subscription_tier`** | Discovered during regression fixing; kept AI prompt context accurate. |
| 7 | No Alembic migration generated | **Migration deferred** | Local DB testing works without migration; actual migration should be generated when ready to deploy. |

---

## Verification Results

| Check | Result |
|-------|--------|
| Backend tests (all) | 281/281 passed |
| Backend tests (new) | 30 new tests |
| Ruff lint | All checks passed |
| Flutter analyze | 10 issues (all pre-existing, none from Phase 1.13) |
| Flutter tests (subscription) | 6/6 passed |
| Flutter tests (all) | 15/16 passed (1 pre-existing failure in widget_test.dart) |
| Branch | `feat/phase-1.13` — 6 atomic commits |

---

## Files Created (9)

| File | Purpose |
|------|---------|
| `cloud-brain/app/services/subscription_service.py` | RevenueCat event processing logic |
| `cloud-brain/app/api/v1/webhooks.py` | RevenueCat webhook HTTP handler |
| `cloud-brain/tests/test_user_subscription_fields.py` | User model subscription field tests |
| `cloud-brain/tests/test_get_current_user.py` | Shared auth dependency tests |
| `cloud-brain/tests/test_tier_middleware.py` | Tier enforcement tests |
| `cloud-brain/tests/test_subscription_service.py` | Subscription service unit tests |
| `cloud-brain/tests/test_webhook_handler.py` | Webhook endpoint tests |
| `life_logger/lib/features/subscription/data/subscription_repository.dart` | RevenueCat SDK wrapper |
| `life_logger/lib/features/subscription/domain/subscription_state.dart` | Subscription state model |
| `life_logger/lib/features/subscription/domain/subscription_providers.dart` | Riverpod providers |
| `life_logger/test/features/subscription/subscription_state_test.dart` | Flutter state model tests |

## Files Modified (9)

| File | Change |
|------|--------|
| `cloud-brain/app/models/user.py` | SubscriptionTier enum, subscription fields, is_premium property |
| `cloud-brain/app/models/__init__.py` | Export SubscriptionTier |
| `cloud-brain/app/api/deps.py` | get_current_user, require_tier, updated check_rate_limit |
| `cloud-brain/app/api/v1/users.py` | Return subscription_tier in preferences |
| `cloud-brain/app/config.py` | RevenueCat config fields |
| `cloud-brain/.env.example` | RevenueCat env vars |
| `cloud-brain/app/main.py` | Register webhooks router |
| `cloud-brain/app/services/user_service.py` | Upsert uses subscription_tier |
| `cloud-brain/app/agent/context_manager/user_profile_service.py` | Query subscription_tier |
| `cloud-brain/tests/test_user_profile.py` | Updated mocks for subscription_tier |
| `life_logger/pubspec.yaml` | Added purchases_flutter dependency |
| `life_logger/lib/features/harness/harness_screen.dart` | Subscription test section |

---

## Next Steps

- **Alembic Migration:** Generate and apply the DB migration for the new User columns when ready to deploy against a real database.
- **RevenueCat Dashboard Setup:** Configure products, offerings, and webhook URL in RevenueCat Dashboard.
- **App Store Products:** Create subscription products in App Store Connect and Google Play Console.
- **Pro-Only Endpoints:** Apply `Depends(require_tier("pro"))` to specific endpoints that should be gated (e.g., unlimited chat, advanced analytics).
- **Paywall UI (Phase 2):** Build a proper paywall screen with pricing, feature comparison, and purchase flow — currently only in the developer harness.
- **Subscription Initialization:** Call `subscriptionProvider.notifier.initialize(userId)` after authentication in the production auth flow.
- **Phase 1.14:** E2E Testing to validate the full subscription flow end-to-end.
