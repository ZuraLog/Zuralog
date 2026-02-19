# Phase 1.10.6: Sync Status Tracking

**Parent Goal:** Phase 1.10 Background Services & Sync Engine
**Checklist:**
- [x] 1.10.1 Cloud-to-Device Write Flow
- [x] 1.10.2 Background Sync Scheduler
- [x] 1.10.3 Edge Agent Background Handler
- [x] 1.10.4 Data Normalization
- [x] 1.10.5 Source-of-Truth Hierarchy
- [x] 1.10.6 Sync Status Tracking
- [ ] 1.10.7 Harness: Background Sync Test

---

## What
Add database fields and API endpoints to track *when* data was last synced and strict status (Success, Failed, In Progress).

## Why
Debugging. "Why isn't my run showing up?" -> "Oh, Strava token expired 4 days ago."

## How
Update `Integration` model.

## Features
- **Error Logging:** Store the last error message ("401 Unauthorized").
- **Status Enum:** `IDLE`, `SYNCING`, `ERROR`.

## Files
- Modify: `cloud-brain/app/models/integration.py`
- Modify: `cloud-brain/app/services/sync_scheduler.py` (to update status)

## Steps

1. **Add sync tracking fields (`cloud-brain/app/models/integration.py`)**

```python
from sqlalchemy import Column, DateTime, String
from cloudbrain.app.db.base import Base

# Inside Integration class
class Integration(Base):
    # ... existing fields ...
    last_synced_at = Column(DateTime(timezone=True))
    sync_status = Column(String, default="idle") # idle, syncing, error
    sync_error = Column(String, nullable=True)
```

2. **Update Status during Sync**
   - Start: `status="syncing", error=None`
   - End: `status="idle", last_synced_at=now()`
   - Except: `status="error", error=str(e)`

## Exit Criteria
- Models updated.
- Scheduler updates these fields.
