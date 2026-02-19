# Phase 1.13: Subscription & Monetization

**Goal:** Implement subscription tier enforcement and RevenueCat integration to support Free, Pro, and Unlimited tiers.

## Checklist
- [ ] **1.13.1** Subscription Models
- [ ] **1.13.2** Tier Middleware
- [ ] **1.13.3** RevenueCat Webhook Handler
- [ ] **1.13.4** Edge Agent Subscription Check
- [ ] **1.13.5** Paywall UI in Harness

## Dependencies
- Phase 1.2 (Auth)

## Exit Criteria
- User model tracks subscription status and expiry.
- Tier middleware enforces API rate limits and feature access.
- RevenueCat webhook handler updates user status in real-time.
- Edge Agent subscription repository implemented.
- Harness can simulate purchase (sandboxed) and verify status change.
