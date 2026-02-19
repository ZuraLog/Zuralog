# Phase 1.8.10: Usage Tracker Service

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
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Service to track exactly how many tokens each user consumes.

## Why
We need to know our margins. Even for "Unlimited" plans, we need to spot anomalies.

## How
Parse the `usage` field from the OpenRouter/LLM response and store it in the database (or TimescaleDB/InfluxDB, but Postgres/Supabase is fine for MVP).

## Features
- **Granularity:** Per request tracking (Input Tokens, Output Tokens, Model).

## Files
- Create: `cloud-brain/app/services/usage_tracker.py`

## Steps

1. **Create usage tracker service (`cloud-brain/app/services/usage_tracker.py`)**

```python
from cloudbrain.app.database import SessionLocal # SQLAlchemy session
# from cloudbrain.app.models import UsageLog

class UsageTracker:
    async def track(self, user_id: str, model: str, input_tokens: int, output_tokens: int):
        """
        Insert record into usage_logs table.
        """
        # async with SessionLocal() as db:
        #    ... insert logic ...
        pass
```

## Exit Criteria
- Functions to log usage exist.
