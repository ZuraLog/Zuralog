# Phase 1.13.2: Tier Middleware

**Parent Goal:** Phase 1.13 Subscription & Monetization
**Checklist:**
- [x] 1.13.1 Subscription Models
- [x] 1.13.2 Tier Middleware
- [ ] 1.13.3 RevenueCat Webhook Handler
- [ ] 1.13.4 Edge Agent Subscription Check
- [ ] 1.13.5 Paywall UI in Harness

---

## What
Create a FastAPI dependency/decorator that checks if the current user has the required tier to access a specific endpoint.

## Why
We need to gate advanced features (like "Unlimited Chat" or "Advanced Analytics") behind the paywall.

## How
Implement `check_tier` dependency.

## Features
- **Hierarchy:** 'Unlimited' includes 'Pro' features.
- **Grace Period:** (Optional) Allow access for X days after expiry? (MVP: No).

## Files
- Create: `cloud-brain/app/api/deps.py` (or modify existing)

## Steps

1. **Create tier checker (`cloud-brain/app/api/deps.py`)**

```python
from fastapi import Depends, HTTPException, status
# from cloudbrain.app.auth import get_current_user

# Tier hierarchy
TIERS = {"free": 0, "pro": 1, "unlimited": 2}

def require_tier(min_tier: str):
    """Dependency factory to enforce minimum subscription tier."""
    
    async def dependency(user = Depends(get_current_user)):
        user_level = TIERS.get(user.subscription_tier, 0)
        required_level = TIERS.get(min_tier, 0)
        
        if user_level < required_level:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Subscription tier '{min_tier}' required."
            )
        return user
        
    return dependency
```

## Exit Criteria
- Dependency prevents Free users from accessing Pro endpoints.
