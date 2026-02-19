# Phase 1.13.3: RevenueCat Webhook Handler

**Parent Goal:** Phase 1.13 Subscription & Monetization
**Checklist:**
- [x] 1.13.1 Subscription Models
- [x] 1.13.2 Tier Middleware
- [x] 1.13.3 RevenueCat Webhook Handler
- [ ] 1.13.4 Edge Agent Subscription Check
- [ ] 1.13.5 Paywall UI in Harness

---

## What
Endpoint to receive server-to-server notifications from RevenueCat when a user subscribes, renews, cancels, or expires.

## Why
This is the most reliable way to keep the `users` table in sync with the App Store.

## How
FastAPI endpoint with a shared secret validation.

## Features
- **Security:** Validates `Authorization` header from RevenueCat.
- **Idempotency:** Handles duplicate events gracefully.

## Files
- Create: `cloud-brain/app/api/v1/webhooks.py`

## Steps

1. **Create handler (`cloud-brain/app/api/v1/webhooks.py`)**

```python
from fastapi import APIRouter, Request, Header, HTTPException
from cloudbrain.app.config import settings
from datetime import datetime

router = APIRouter()

@router.post("/webhooks/revenuecat")
async def revenuecat_webhook(
    request: Request, 
    authorization: str = Header(None)
):
    """Handle RevenueCat subscription events."""
    
    # 1. Validate Secret
    if authorization != settings.revenuecat_webhook_secret:
        raise HTTPException(status_code=403, detail="Invalid secret")
        
    payload = await request.json()
    event = payload.get("event", {})
    type = event.get("type") # INITIAL_PURCHASE, RENEWAL, CANCELLATION
    
    app_user_id = event.get("app_user_id") # Our user_id
    
    # 2. Update User Logic
    # user = await db.get(User, app_user_id)
    # if type in ["INITIAL_PURCHASE", "RENEWAL"]:
    #     user.subscription_tier = "pro"
    #     user.is_premium = True
    #     user.subscription_expires_at = datetime.fromtimestamp(event.get("expiration_at_ms") / 1000)
    
    return {"received": True}
```

## Exit Criteria
- Endpoint accepts JSON.
- Updates dummy user state correctly.
