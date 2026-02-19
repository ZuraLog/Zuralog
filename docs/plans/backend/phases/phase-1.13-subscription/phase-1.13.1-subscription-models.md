# Phase 1.13.1: Subscription Models

**Parent Goal:** Phase 1.13 Subscription & Monetization
**Checklist:**
- [x] 1.13.1 Subscription Models
- [ ] 1.13.2 Tier Middleware
- [ ] 1.13.3 RevenueCat Webhook Handler
- [ ] 1.13.4 Edge Agent Subscription Check
- [ ] 1.13.5 Paywall UI in Harness

---

## What
Extend the `User` database model to include subscription-related fields.

## Why
We need to know who paid us.

## How
Add columns to `users` table.

## Features
- **Expiration Tracking:** `subscription_expires_at` handles cancellations.
- **Source of Truth:** `revenuecat_customer_id` links to the payment processor.

## Files
- Modify: `cloud-brain/app/models/user.py`

## Steps

1. **Add subscription fields (`cloud-brain/app/models/user.py`)**

```python
from sqlalchemy import Column, String, Boolean, DateTime

# In User class
class User(Base):
    # ... existing ...
    is_premium = Column(Boolean, default=False)
    subscription_tier = Column(String, default="free")  # 'free', 'pro', 'unlimited'
    subscription_expires_at = Column(DateTime(timezone=True), nullable=True)
    revenuecat_customer_id = Column(String, nullable=True, index=True)
```

## Exit Criteria
- Models updated.
- Migration script generated.
