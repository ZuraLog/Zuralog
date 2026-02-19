# Phase 1.8.9: Rate Limiter Service

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
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Implement a flexible rate limiting service backed by Redis.

## Why
LLM calls are expensive. We must protect the backend from abuse and enforce subscription tiers (Free vs Pro).

## How
Use `redis-py` (async) to store sliding window counters or token buckets per user ID.

## Features
- **Tiered Limits:** Free: 50 req/day. Pro: 500 req/day.
- **Fail-Open:** (Optional) If Redis is down, decide whether to allow or block. Usually block for safety.

## Files
- Create: `cloud-brain/app/services/rate_limiter.py`

## Steps

1. **Create rate limiter service (`cloud-brain/app/services/rate_limiter.py`)**

```python
import redis.asyncio as redis
from cloudbrain.app.config import settings
import time

class RateLimiter:
    def __init__(self):
        self.redis = redis.from_url(settings.redis_url)
    
    async def is_allowed(self, user_id: str, tier: str = "free") -> bool:
        """
        Simple fixed window counter. 
        """
        key = f"rate_limit:{user_id}:{int(time.time() // 86400)}" # Daily key
        limit = 50 if tier == "free" else 500
        
        current = await self.redis.incr(key)
        if current == 1:
            await self.redis.expire(key, 86400)
            
        return current <= limit
```

## Exit Criteria
- Service checks against Redis.
- Correctly resets daily.
