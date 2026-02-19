# Phase 1.8.11: Rate Limiter Middleware

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [x] 1.8.2 Agent System Prompt
- [x] 1.8.3 Tool Selection Logic
- [x] 1.8.4 Cross-App Reasoning Engine
- [x] 1.8.5 Voice Input
- [x] 1.8.6 User Profile & Preferences
- [x] 1.8.7 Test Harness: AI Chat
- [x] 1.8.8 Kimi Integration Document
- [x] 1.8.9 Rate Limiter Service
- [x] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Middleware that runs before every API request to the `/agent` or `/chat` endpoints to enforce the rate limits.

## Why
Centralized enforcement is better than checking in every route handler.

## How
FastAPI Dependency or Middleware. Dependency is often cleaner for access to `request.user`.

## Features
- **429 Too Many Requests:** Returns standard HTTP status code.
- **Headers:** Returns `X-RateLimit-Remaining` headers (optional but good practice).

## Files
- Modify: `cloud-brain/app/api/deps.py` (Dependencies)
- Modify: `cloud-brain/app/api/v1/chat.py` (Apply dependency)

## Steps

1. **Create dependency (`cloud-brain/app/api/deps.py`)**

```python
from fastapi import Depends, HTTPException, status
from cloudbrain.app.services.rate_limiter import RateLimiter
# from cloudbrain.app.auth import get_current_user

async def check_rate_limit(
    user = Depends(get_current_user), # Hypothetical auth dependency
    limiter: RateLimiter = Depends(RateLimiter)
):
    tier = user.subscription_tier # "free" or "premium"
    allowed = await limiter.is_allowed(user.id, tier)
    
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily rate limit exceeded. Upgrade to Premium for more."
        )
```

## Exit Criteria
- API returns 429 when limits exceeded.
